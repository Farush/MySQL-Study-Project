USE sec_sys;

SELECT -- Считаем кол-во работ у работников по месяцам.
	MONTHNAME(j.`date`) AS month_name,
	COUNT(j.id),
	w.name 
FROM jobs j
JOIN executants e ON j.id = e.job
JOIN workers w ON w.id = e.worker  -- WHERE w.id = 2 по конкретному работнику
GROUP BY month_name, w.name;
-- ORDER BY month_name;

SELECT -- поиск работников, у которых не проставлены зарплаты за объекты
	j.`date` , 
	j.address,
	CONCAT(w2.name, ' ', w2.surname) AS _worker_,
	w.wage 
FROM jobs j 
JOIN wages w ON j.id = w.job_id  
JOIN workers w2 ON w2.id = w.worker_id -- AND w2.id = 2  по конкретному работнику
WHERE w.wage IS NULL;


SELECT -- Поиск объекта, у которого не проставлена стоимость работ
	j.`date`,
	j.address,
	c.cost
FROM jobs j 
JOIN costs c ON j.id = c.job_id WHERE c.cost IS NULL;


SELECT -- считаем зарплату за месяц по работнику. 
SUM(w.wage),
w.worker_id 
FROM wages w 
JOIN jobs j ON j.id = w.job_id 
WHERE w.worker_id = 1 AND j.`date` BETWEEN '2021-01-01' and '2021-01-31'; -- лучше MONTH_NAME(j.`date`) и год надо добавить. 
	
/*
SELECT -- считаем зарплату за месяц по работнику. Сделаем из этого хранимую процедуру. СДЕЛАНО
SUM(w.wage) 
FROM wages w 
JOIN jobs j ON j.id = w.job_id 
WHERE w.worker_id = 1 AND MONTHNAME(j.`date`) = 'january';

*/


UPDATE sec_sys.costs -- Тоже сделать процедуру, которая будет принимать адрес и стоимость. 
SET cost=53500
WHERE job_id=(SELECT j.id FROM jobs j WHERE j.address = 'М12 Зеленый Бор');

UPDATE sec_sys.wages
SET wage=31000
WHERE worker_id=(SELECT w.id FROM workers w WHERE CONCAT(w.name, ' ', w.surname) = 'Фархад Сибгатуллин') AND job_id=(SELECT j.id FROM jobs j WHERE j.address = 'М12 Зеленый Бор');


UPDATE sec_sys.wages -- тоже сделать процедуру, где аргумент JSON словарь. Ключ Имя Фамилия работника, значение зарплата. Сделать проверку, чтоб сумма по работникам не превышала стоимость объекта.
SET wage=22500
WHERE worker_id=(SELECT w.id FROM workers w WHERE CONCAT(w.name, ' ', w.surname) = 'Айдар Закиров') AND job_id=(SELECT j.id FROM jobs j WHERE j.address = 'М12 Зеленый Бор');



