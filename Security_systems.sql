
DROP DATABASE IF EXISTS sec_sys;
CREATE DATABASE sec_sys;

-- База данных для учета работ по установке систем видеонаблюдения на разных объектах и учета заработных плат.
USE sec_sys;


CREATE TABLE jobs ( -- Таблица с работами, адресами и датами проведения работ на объектах
	id SERIAL PRIMARY KEY,
    `date` DATE,
    address VARCHAR(100),
    `comment` VARCHAR(255), 
    types  BIGINT UNSIGNED NOT NULL, -- ENUM('mount', 'demount', 'camera', 'registrator', 'other_mount','other_demount'),
    is_paid bit default 0,
    created_at DATETIME DEFAULT NOW(), -- справочная информация.
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	UNIQUE INDEX address_date_type_idx(`date`, address, types) -- в одну дату один объект одного типа
);

CREATE TABLE expendables ( -- Таблица учета расходных материалов на объектах.
	id SERIAL PRIMARY KEY,
    job_id BIGINT UNSIGNED UNIQUE NOT NULL,
	UTP SMALLINT DEFAULT 0,
    AV SMALLINT DEFAULT 0,
    power_cable SMALLINT DEFAULT 0,
    corrugated SMALLINT DEFAULT 0,
    cable_channel SMALLINT DEFAULT 0,
    lenght_sum SMALLINT AS (UTP + AV + power_cable + corrugated + cable_channel) STORED,
    camera TINYINT DEFAULT 0,
    FOREIGN KEY (job_id) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE 
);


CREATE TABLE types ( -- Таблица-справочник видов проводимых работ и их стоимости
	id SERIAL PRIMARY KEY,
    name ENUM('mount', 'demount', 'camera', 'registrator', 'other_mount','other_demount') UNIQUE  NOT NULL,
    `comment` VARCHAR (255),
    cost DECIMAL(11,2),
    created_at DATETIME DEFAULT NOW(),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP 
);

ALTER TABLE jobs ADD CONSTRAINT fk_types_id -- Добавляем ключ в таблицу с работами с отсылкой к справочнику видов работ
FOREIGN KEY (types) REFERENCES types(id) ON UPDATE CASCADE;

CREATE TABLE workers ( -- Таблица-справочник исполнителей работ.
	id SERIAL PRIMARY KEY,
    name VARCHAR(100)  NOT NULL,
    surname VARCHAR(100) NOT NULL,
    phone BIGINT UNIQUE,
    created_at DATETIME DEFAULT NOW(), -- справочная информация.
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);


CREATE TABLE costs ( -- Таблица учета общей стоимости работ на каждом отдельном объекте.
id SERIAL PRIMARY KEY,
job_id BIGINT UNSIGNED UNIQUE NOT NULL,
-- job_date DATE,
cost DECIMAL(11,2),
FOREIGN KEY (job_id) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE executants ( -- Таблица с перечислением работников и объектов, на которых они работали
	id SERIAL PRIMARY KEY,
	worker BIGINT UNSIGNED NOT NULL,
	job BIGINT UNSIGNED NOT NULL,
	FOREIGN KEY (worker) REFERENCES workers(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (job) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE,
	UNIQUE INDEX worker_job_idx (worker, job) -- чтоб один работник не мог быть учтенным два раза на одном объекте.
	
);

CREATE TABLE wages ( -- Таблица для подсчета зарплаты работникам по объектам
	id SERIAL PRIMARY KEY,
	worker_id BIGINT UNSIGNED NOT NULL,
	job_id BIGINT UNSIGNED NOT NULL,
	wage DECIMAL (11,2),
	created_at DATETIME DEFAULT NOW(), -- справочная информация.
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (worker_id) REFERENCES workers(id) ON UPDATE CASCADE ON DELETE CASCADE,
	FOREIGN KEY (job_id) REFERENCES jobs(id) ON UPDATE CASCADE ON DELETE CASCADE,
	UNIQUE INDEX worker_job (worker_id, job_id) -- чтоб один работник мог получать за один объект только один раз.
);


CREATE TABLE monthly_wage ( -- Таблица с подсчетом зарплаты за месяц по каждому работнику. Написать процедуру
	id SERIAL PRIMARY KEY,
	`year`SMALLINT UNSIGNED,
	`month` VARCHAR(15),
	worker_id BIGINT UNSIGNED,
	wage_month DECIMAL(11,2),
	wage_for_bill DECIMAL (11,2) AS (CEILING(wage_month * 100 / 94)) STORED,
	created_at DATETIME DEFAULT NOW(), -- справочная информация.
	updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
	FOREIGN KEY (worker_id) REFERENCES workers(id) ON UPDATE CASCADE ON DELETE CASCADE,
	UNIQUE INDEX year_month_worker (`year`, `month`, worker_id) -- один работник, один месяц, один год, один раз. 
);

-- DROP TABLE IF EXISTS logs; -- Создаем log.

CREATE TABLE logs ( -- можно получше продумать структуру лога. Для демонстрации этой структуры хватает. Создаю, чтоб ошибки из процедур писать в лог.
	date_and_time DATETIME default NOW(),	-- Можно вставить поле JSON, куда можно запихать подробную информацию о транзакции: id, данные и пр. 
    error_code VARCHAR (255),				-- Хотя по сути получится, что мы просто дублируем базу данных, т.е. в лог записываем тоже, что и в базу.
    error_text VARCHAR(255),				-- Для суперпараноидальной безопасности в принципе нормально. Можно будет восстановить все данные (или большую часть) из лога.
	table_name VARCHAR(255),
    table_id BIGINT UNSIGNED 
    ) ENGINE = ARCHIVE;

-- Сразу до заполнения создадим два триггера для заполнения таблицы costs и таблицы wages, так как все данные для их заполнения мы уже можем взять из jobs, expendables и executants. 
-- ИСПОЛНИТЬ ЭТУ ЧАСТЬ СКРИПТА ДО СКРИПТА С ЗАПОЛНЕНИЕМ ТАБЛИЦ!!

DELIMITER $$ -- Заполнит costs по заполнению expendables. Написать такой ON UPDATE 
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
				ELSE -- нестандартные виды работ.
				INSERT INTO costs (job_id, cost) VALUES
					(NEW.job_id, NULL); -- написать процедуру, где эти (прочие) виды работ заполняются. Специально NULL, чтоб их сразу было видно. Если поставить 0, можно не заметить.
			END CASE;
		END;
	
$$
DELIMITER ;



DELIMITER $$ -- Заполнит зарплаты по заполнению costs.  написать такой ON UPDATE
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
		END;
	
$$
DELIMITER ;


-- Наполнение таблиц.

INSERT INTO sec_sys.workers 
(name, surname, phone)
VALUES
('Айдар', 'Закиров', 9274567891),
('Фархад', 'Сибгатуллин', 9172911168);


INSERT INTO sec_sys.types
(name, comment, cost)
VALUES
	('mount', 'монтаж магазина', 9000), 
	('demount', 'демонтаж магазина', 2000),
	('camera', 'ремонт, монтаж, замена одной камеры', 500),
	('registrator', 'ремонт, установка, замена регистратора', 500),
	('other_mount', 'иной монтаж', 0),
	('other_demount', 'иной демонтаж', 0);

INSERT INTO sec_sys.jobs
	(`date`, address, comment, types, is_paid)
-- (`date`, address, comment, types, executant1, executant2, is_paid)
VALUES
	('2021-01-03', 'Гагарина, 7', '', 3, b'1'),
	('2021-01-04', 'Ш.Усманова, 13', '', 3, b'1'),
	('2021-01-05', 'Фрунзе, 15', '', 3, b'1'),
	('2021-01-06', 'Чистополь, Ленина 2А', 'нет акта выполненных работ', 4, b'1'),
	('2021-01-18', 'Зорге, 121', '', 2, b'1'),
	('2021-01-23', 'Декабристов, 133', '', 2, b'1'),
	('2021-01-26', 'Аббасова, 8', '', 1, b'1'),
	('2021-01-29', 'С.Садыковой', 'Энергобанк', 3, b'1'),
	('2021-02-01', 'Тэцевская, 4', '', 1, b'1'),
	('2021-02-10', 'Чистопольская, 9', '', 1, b'1'),
	('2021-02-11', 'Сахарова, 27', '', 2, b'1'),
	('2021-02-14', 'Белинского, 18', '', 1, b'1'),
	('2021-02-19', 'Ильхама Шакирова, 9', '', 1, b'1'),
	('2021-04-21', 'Чуйкова, 5', '', 1, b'1'),
	('2021-09-20', 'М12 Зеленый Бор', '',5, b'1');

INSERT INTO sec_sys.executants
	(worker, job)
VALUES
	(2, 1),
	(2, 2),
	(2, 3),
	(2, 4),
	(1, 5),
	(2, 5),
	(1, 6),
	(2, 6),
	(1, 7),
	(2, 7),
	(2, 8),
	(1, 9),
	(2, 9),
	(1, 10),
	(2, 10),
	(1, 11),
	(2, 11),
	(1, 12),
	(2, 12),
	(1, 13),
	(2, 13),
	(1, 14),
	(2, 14),
	(1, 15),
	(2, 15);


INSERT INTO sec_sys.expendables
(job_id, UTP, AV, power_cable, corrugated, cable_channel, camera)
VALUES
	(1, 0, 0, 0, 0, 0, 1),
	(2, 0, 0, 0, 0, 0, 2),
	(3, 0, 0, 0, 0, 0, 2),
	(4, 0, 0, 0, 0, 0, 1),
	(5, 0, 0, 0, 0, 0, 0),
	(6, 0, 0, 0, 0, 0, 0),
	(7, 0, 0, 0, 0, 0, 0),
	(8, 0, 0, 0, 0, 0, 6),
	(9, 0, 0, 0, 0, 0, 0),
	(10, 0, 0, 0, 0, 0, 0),
	(11, 0, 0, 0, 0, 0, 0),
	(12, 0, 0, 0, 0, 0, 5),
	(13, 56, 66, 2, 0, 0, 6),
	(14, 73, 146, 0, 0, 0, 11),
	(15, 1546, 0, 3, 0, 256, 0);



/* --уже не надо. Заполнит триггер.
INSERT INTO sec_sys.wages
	(worker_id, job_id, wage)
VALUES
	(1, 1, 4500),
	(2, 1, 4500),
	(1, 2, 4500),
	(2, 2, 4500),
	(1, 3, 1000),
	(2, 3, 1000),
	(1, 4, 4500),
	(2, 4, 4500),
	(1, 5, 4500),
	(2, 5, 4500),
	(1, 6, 6000),
	(2, 6, 6000)
;
 
 
INSERT INTO sec_sys.monthly_wage  Не надо, вставим хранимой процедурой исходя из имеющихся в базе данных.
	(`month`, `year`, worker_id, wage_month)
VALUES
	('january', 2021, 1, 6500),
	('january', 2021, 2, 12500),
	('february', 2021, 1, 19000),
	('february', 2021, 2, 19000);

*/
