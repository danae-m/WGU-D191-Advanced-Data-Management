--USER DEFINED DATA TRANSFORMATION FUNCTION

CREATE OR REPLACE FUNCTION days_over_avg (rental_date TIMESTAMP, return_date TIMESTAMP, avg_days INTERVAL) 
	RETURNS INT
	LANGUAGE plpgsql 
AS $$ 
DECLARE extra_days NUMERIC(3,1);
DECLARE rent_interval INTERVAL;
BEGIN

SELECT return_date-rental.date INTO rent_interval;

SELECT CASE
	WHEN (rent_interval>avg_days) THEN ((EXTRACT(epoch FROM rent_interval)/3600.0)-(EXTRACT(epoch FROM avg_days)/3600.0))
	ELSE NULL
	END
	INTO extra_days;

RETURN extra_days; 
END ; $$ ;


--AVG TABLE

DROP TABLE IF EXISTS avg ;

CREATE TABLE avg (avg_days INTERVAL) ;

INSERT INTO avg(avg_days)
	SELECT AVG(return_date - rental_date)
	FROM rental ;

SELECT * FROM avg ;


--DETAILED TABLE

DROP TABLE IF EXISTS detailed ; 

CREATE TABLE detailed (  
	rental_id INT PRIMARY KEY, film_id INT, film_title VARCHAR(255), extra_days NUMERIC(3,1) );  

INSERT INTO detailed(rental_id, film_id, film_title, extra_days)  
	SELECT rental.rental_id, inventory.film_id, film.title AS film_title, days_over_avg(rental.rental_date, rental.return_date, avg.avg_days) AS extra_days
	FROM rental 
	JOIN inventory ON inventory.inventory_id = rental.inventory_id 
	JOIN film ON inventory.film_id = film.film_id  
	ORDER BY rental.rental_id
	LIMIT 1000 ; 
	
SELECT * FROM detailed ;


--SUMMARY TABLE
	
DROP TABLE IF EXISTS summary ;

CREATE TABLE summary (  
	extra_days NUMERIC(3,1), quantity INT, late_fee NUMERIC(5,2), film_id INT ); 

INSERT INTO summary (extra_days, quantity, film_id) 
	SELECT
		detailed.extra_days,
		(SELECT COUNT (*) FROM detailed	GROUP BY film_id),
		((SELECT COUNT (*) FROM detailed GROUP BY film_id) * extra_days),
		detailed.film_id	  
	FROM detailed
	GROUP BY film_id
	ORDER BY late_fee DESC; 

SELECT * FROM summary ; 


CREATE OR REPLACE FUNCTION update_function()
	RETURNS TRIGGER
	LANGUAGE plpgsql
AS $$
BEGIN

END ; $$ ;

CREATE TRIGGER update_trigger
	AFTER INSERT
	ON public.summary
	FOR EACH STATEMENT
	EXECUTE update_function() ;