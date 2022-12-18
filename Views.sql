USE sec_sys;
 

CREATE OR REPLACE VIEW general_view AS

SELECT
    j.`date`,
    j.address,
    j.comment,
    t.name,
    e.lenght_sum AS `Общая длина проводов`,
    e.camera AS `Кол-во камер`,
    c.cost AS `Стоимость работ`,
    e2.cnt AS `Кол-во работников`,
    j.is_paid
FROM
    jobs j
JOIN types t ON
    j.types = t.id
JOIN expendables e ON
    j.id = e.job_id
JOIN costs c ON
    j.id = c.job_id
JOIN 
	(SELECT -- Считаем количество работников по каждому объекту представляем как е2, наверно можно переписать без вложенного запроса.
        job,
        count(worker) AS `cnt`
    FROM
        executants 
    GROUP BY job) e2

    ON j.id = e2.job
;
   
SELECT * FROM general_view;

/*SELECT
	count(e2.job) AS cnt,
    e2.worker
FROM
	executants e2
GROUP BY worker;
*/

/*CREATE OR REPLACE VIEW wages_names AS
SELECT
    CONCAT(mw.`year`, ' ', mw.`month`) AS `year and month`,
    CONCAT(w.name, ' ', w.surname) AS worker
    -- вставить зарплату и кол-во объектов
FROM
    monthly_wage mw
JOIN workers w 
ON mw.worker_id = w.id;*/



CREATE OR REPLACE VIEW monthly_wages_names AS
SELECT
    CONCAT(mw.`month`, ' ', mw.`year`) AS `месяц год`,
    CONCAT(w.name, ' ', w.surname) AS `работник`,
    mw.wage_month AS `на руки`,
    mw.wage_for_bill AS `с налогами`,
	mn.cnt AS `кол-во объектов`
FROM monthly_wage mw
JOIN workers w 
ON mw.worker_id = w.id
JOIN (SELECT -- Считаем кол-во работ у исполнителей.
	CONCAT(MONTHNAME(j.`date`), ' ',  YEAR(j.`date`)) AS month_year,
	-- j.id,
	count(j.id) AS cnt,
	w.name 
FROM jobs j
JOIN executants e ON j.id = e.job
JOIN workers w ON w.id = e.worker
GROUP BY month_year, w.name) mn
ON mn.month_year = CONCAT(mw.`month`, ' ', mw.`year`) AND mn.name = w.name;
    
-- Тоже самое, но без вложенного запроса
-- Мне не нравится, как это представление сортирует строки 

/* 
CREATE OR REPLACE VIEW monthly_wages_names AS
SELECT
    CONCAT(mw.`month`, ' ', mw.`year`) AS year_and_month,
    CONCAT(w.name, ' ', w.surname) AS _worker_,
    mw.wage_month AS no_taxes,
    mw.wage_for_bill AS with_taxes,
	COUNT(j.id) AS `кол-во объектов`
FROM monthly_wage mw
JOIN workers w 
ON mw.worker_id = w.id
JOIN executants e ON e.worker = mw.worker_id 
JOIN jobs j ON j.id = e.job WHERE CONCAT (mw.`month`, ' ', mw.`year`) = CONCAT(MONTHNAME(j.`date`), ' ',  YEAR(j.`date`))
GROUP BY year_and_month, _worker_, no_taxes;
*/

SELECT * FROM  monthly_wages_names;  




-- SELECT CONCAT(MONTHNAME(jobs.`date`), ' ',  YEAR(jobs.`date`)) FROM jobs; -- проверяю как склеивание работает.




 