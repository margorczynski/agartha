CREATE SCHEMA IF NOT EXISTS agartha.company_info;

USE agartha.company_info;

CREATE TABLE IF NOT EXISTS agartha_users (
    id,
    name,
    country_cd,
    like_clicks,
    date_joined
)
WITH (
    partitioning = ARRAY['country_cd']
)
AS VALUES
    (1, 'Josh', 'us', 325, date '2012-08-08'),
    (2, 'Mike', 'us', 255, date '2012-01-08'),
    (3, 'Jan', 'pl', 300, date '2012-02-08'),
    (4, 'Arek', 'pl', 170, date '2012-03-08'),
    (5, 'Hans', 'de', 325, date '2012-04-08'),
    (6, 'Toby', 'uk', 525, date '2012-05-08');

INSERT INTO agartha_users VALUES (7, 'Bill', 'us', 400, current_date);

SELECT sum(like_clicks) FROM agartha_users GROUP BY country_cd;