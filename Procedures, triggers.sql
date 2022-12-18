USE sec_sys;
/*
DELIMITER $$
$$
CREATE TRIGGER costs_count
	AFTER INSERT
	ON sec_sys.jobs FOR EACH ROW
		BEGIN 
			-- DECLARE type_of_job VARCHAR(255);
			CASE NEW.types
				WHEN 1 THEN 
				INSERT INTO costs (job_id, job_date, cost) VALUES
					(NEW.id, NEW.`date`, (SELECT cost from types where id = 1));
				WHEN 2 THEN
				INSERT INTO costs (job_id, job_date, cost) VALUES
					(NEW.id, NEW.`date`, (SELECT cost from types where id = 2));
				-- ELSE type_of_job = 'other type';
			END CASE;
		END;
	
$$
DELIMITER ;

SELECT cost from types where id = 1;
*/
DROP TRIGGER IF EXISTS costs_count;

DELIMITER $$
$$
CREATE TRIGGER costs_count
	AFTER INSERT
	ON sec_sys.expendables FOR EACH ROW
		BEGIN 
			DECLARE type_of_job BIGINT;
			DECLARE job BIGINT;
			SET job = NEW.job_id;
			SELECT types INTO type_of_job FROM jobs WHERE jobs.id = job;
			CASE type_of_job
				WHEN 1 THEN -- монтаж магазина
					IF (SELECT camera FROM expendables WHERE job_id = job) <= 8 THEN -- если камер не больше восьми
						INSERT INTO costs (job_id, cost) VALUES
							(NEW.job_id, (SELECT cost from types where id = 1));
					ELSE -- если камер больше восьми, считаем 9000 за магазин + 1000 за каждую лишнюю камеру
						INSERT INTO costs (job_id, cost) VALUES
							(NEW.job_id, (SELECT cost from types where id = 1) + ((SELECT camera FROM expendables WHERE job_id = job)-8)*1000);
					END IF;
				WHEN 2 THEN -- демонтаж магазина
				INSERT INTO costs (job_id, cost) VALUES
					(NEW.job_id, (SELECT cost from types where id = 2));
				WHEN 3 THEN -- монтаж камер 500 за каждую.
				INSERT INTO costs (job_id, cost) VALUES
					(NEW.job_id, (SELECT cost from types where id = 3) * (SELECT camera FROM expendables WHERE job_id = job));
				WHEN 4 THEN -- монтаж камер 500 за каждую.
				INSERT INTO costs (job_id, cost) VALUES
					(NEW.job_id, (SELECT cost from types where id = 4));
				ELSE
				INSERT INTO costs (job_id, cost) VALUES
					(NEW.job_id, NULL);
			END CASE;
		END$$
DELIMITER ;


DROP TRIGGER IF EXISTS wages_count;

DELIMITER $$
$$
CREATE TRIGGER wages_count
	AFTER INSERT
	ON sec_sys.costs  FOR EACH ROW
		BEGIN 
			DECLARE id_for_job BIGINT;
			SET id_for_job = NEW.job_id; 
			INSERT INTO wages (worker_id, job_id)
				SELECT worker, job FROM executants WHERE executants.job = id_for_job;
			UPDATE sec_sys.wages
				SET wage = (SELECT cost FROM costs WHERE costs.job_id = id_for_job)/ (SELECT COUNT(*) FROM executants WHERE job = id_for_job)
				WHERE job_id = id_for_job;
		END$$
DELIMITER ;

DROP PROCEDURE IF EXISTS sec_sys.new_job;

DELIMITER $$
$$
CREATE PROCEDURE sec_sys.new_job(
	
	new_date DATE, 
	new_address VARCHAR(100), 
	new_comment VARCHAR(255),
	new_type VARCHAR(15),
	new_UTP SMALLINT, 
	new_AV SMALLINT, 
	new_power_cable SMALLINT, 
	new_corrugated SMALLINT, 
	new_cable_channel SMALLINT,
	new_camera TINYINT,
	new_executants JSON,
	OUT tran_result VARCHAR(255)
	)
BEGIN
	DECLARE rb BIT DEFAULT b'0';
	DECLARE code VARCHAR(255);
	DECLARE error_string VARCHAR(255);
	DECLARE j_id BIGINT UNSIGNED;
	DECLARE i INT DEFAULT 0;
	DECLARE w_id BIGINT UNSIGNED;
	

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
		BEGIN 
			SET rb = b'1';
			GET stacked DIAGNOSTICS CONDITION 1
			code = RETURNED_SQLSTATE,
			error_string = MESSAGE_TEXT;
			SET tran_result = concat('Код ошибки: ', code, ' Текст ошибки: ', error_string);
		END;
	
	START TRANSACTION;
		
		INSERT INTO sec_sys.jobs (`date`, address, comment, types, is_paid)
		VALUES(new_date, new_address, new_comment, (SELECT t.id FROM types t WHERE t.name = new_type), b'0');
		
		SET j_id = last_insert_id();
		
		INSERT INTO sec_sys.expendables (job_id, UTP, AV, power_cable, corrugated, cable_channel, camera)
		VALUES(j_id, new_UTP, new_AV, new_power_cable, new_corrugated, new_cable_channel, new_camera);
		
		
		WHILE i < JSON_LENGTH(new_executants) DO
			SET w_id = (SELECT id FROM workers w WHERE CONCAT(w.name, ' ', w.surname) = JSON_EXTRACT(new_executants, CONCAT('$[', i, ']')));
			INSERT INTO sec_sys.executants (worker, job)
			VALUES(w_id, j_id);
			SET i = i + 1;
		END WHILE;
	
		INSERT INTO wages (worker_id, job_id)
				SELECT worker, job FROM executants WHERE executants.job = j_id;
			UPDATE sec_sys.wages
				SET wage = (SELECT cost FROM costs WHERE costs.job_id = j_id)/ (SELECT COUNT(*) FROM executants WHERE job = j_id)
				WHERE job_id = j_id;
	
	IF rb THEN 
		ROLLBACK;
		INSERT INTO sec_sys.logs (date_and_time, error_code, error_text, table_name)
		VALUES(CURRENT_TIMESTAMP, code, error_string, 'jobs, executants, expendables, wages');

	ELSE 
		SET tran_result = 'INSERT OK'; -- это лучше писать в ЛОГ
		INSERT INTO sec_sys.logs (date_and_time, error_code, error_text, table_name, table_id)
		VALUES(CURRENT_TIMESTAMP, 'NO ERROR', 'insert OK', 'jobs, executants, expendables, wages', j_id);
		COMMIT;
	END IF;
END$$
DELIMITER ;


CALL new_job ('2021-03-10','Гагарина, 109','', 'demount', 0, 0, 0, 0, 0, 0, '["Айдар Закиров", "Фархад Сибгатуллин"]', @result_);

SELECT @result_;


-- SELECT JSON_LENGTH('["Айдар Закиров", "Фархад Сибгатуллин"]');

-- SELECT id FROM workers w WHERE CONCAT(w.name, ' ', w.surname) = JSON_EXTRACT('["Айдар Закиров", "Фархад Сибгатуллин"]', CONCAT('$[', 0, ']'));

-- SELECT COUNT(*) FROM executants WHERE job = 1; определяем кол-во работников, которое выполняет конкретную работу по job_id
 

-- SELECT camera from expendables WHERE job_id = job;
-- SELECT worker FROM executants WHERE executants.job = 1;
/*
INSERT INTO wages 
	(worker_id, job_id)
SELECT worker, job FROM executants WHERE executants.job = 1;

UPDATE sec_sys.wages
SET wage = (SELECT cost FROM costs WHERE costs.job_id = 1)/ (SELECT COUNT(*) FROM executants WHERE job = 1)
WHERE job_id = 1;

*/
-- SELECT JSON_LENGTH('[1, 2]');
-- SELECT JSON_TYPE('["Айдар Закиров", "Фархад Сибгатуллин"]');

 -- SELECT  JSON_EXTRACT('["Фархад", "Айдар"]', CONCAT('$[', 1, ']'));
 -- JSON_EXTRACT('["ФАРХАД", 14, "name", "Aztalan"]', CONCAT('$[', i, ']'))
/*
SELECT 
SUM(w.wage),
w.worker_id 
FROM wages w 
JOIN jobs j ON j.id = w.job_id 
WHERE w.worker_id = 1 AND j.`date` BETWEEN '2021-01-01' and '2021-01-31';
*/ 



DROP PROCEDURE IF EXISTS sec_sys.monthly_wage_count;

DELIMITER $$
$$
CREATE PROCEDURE sec_sys.monthly_wage_count(
w_year SMALLINT UNSIGNED,
w_month VARCHAR (15),
workers JSON,
OUT tran_result VARCHAR(255))

BEGIN
	DECLARE i INT DEFAULT 0;
	DECLARE w_id BIGINT UNSIGNED;
	DECLARE `sum` DECIMAL(11, 2);
	DECLARE rb BIT DEFAULT b'0';
	DECLARE code VARCHAR(255);
	DECLARE error_string VARCHAR(255);

	DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
		BEGIN 
			SET rb = b'1';
			GET stacked DIAGNOSTICS CONDITION 1
			code = RETURNED_SQLSTATE,
			error_string = MESSAGE_TEXT;
			SET tran_result = concat('Код ошибки: ', code, ' Текст ошибки: ', error_string);
		END;
	
		WHILE i < JSON_LENGTH(workers) DO
			SET w_id = (SELECT id FROM workers w WHERE CONCAT(w.name, ' ', w.surname) = JSON_EXTRACT(workers, CONCAT('$[', i, ']')));
			SET `sum` = (SELECT -- считаем зарплату за месяц по работнику. Сделаем из этого хранимую процедуру.
				SUM(w.wage) 
				FROM wages w 
				JOIN jobs j ON j.id = w.job_id 
				WHERE w.worker_id = w_id AND MONTHNAME(j.`date`) = w_month AND YEAR(j.`date`) = w_year);
			INSERT INTO sec_sys.monthly_wage (`year`, `month`, worker_id, wage_month)
			VALUES(w_year, w_month, w_id, `sum`);
			SET i = i + 1;
		END WHILE;
	
	IF rb THEN 
		ROLLBACK;
		INSERT INTO sec_sys.logs (date_and_time, error_code, error_text, table_name)
		VALUES(CURRENT_TIMESTAMP, code, error_string, 'monthly_wage');

	ELSE 
		SET tran_result = 'INSERT OK'; -- это лучше писать в ЛОГ
		INSERT INTO sec_sys.logs (date_and_time, error_code, error_text, table_name, table_id)
		VALUES(CURRENT_TIMESTAMP, 'NO ERROR', 'insert OK', 'monthly_wage', last_insert_id()); -- поставтиь в цикл, чтоб каждую итерацию писал в лог
		COMMIT;
	END IF;
END$$
DELIMITER ;


CALL monthly_wage_count('2021', 'january', '["Айдар Закиров", "Фархад Сибгатуллин"]',@result_);

SELECT @result_;
