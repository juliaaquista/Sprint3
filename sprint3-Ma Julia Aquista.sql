#------S3.N1.E1

CREATE SCHEMA IF NOT EXISTS `sprint-3-ma-julia-aquista`.silver
                              OPTIONS (location = "EU", description = "Capa Silver: tablas limpias y tipadas, construidas desde capa Bronze");


#------S3.N1.E2
CREATE OR REPLACE EXTERNAL TABLE `sprint-3-ma-julia-aquista.bronze.transactions_raw` 
OPTIONS ( format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/ERP/transactions.csv'],
  field_delimiter = ';');

CREATE OR REPLACE EXTERNAL TABLE `sprint-3-ma-julia-aquista.bronze.companies_raw`
   OPTIONS ( format = 'CSV',
    uris = ['gs://bootcamp-data-analytics-public/ERP/companies.csv'],
      skip_leading_rows = 1 );

CREATE OR REPLACE EXTERNAL TABLE `sprint-3-ma-julia-aquista.bronze.american_users_raw` 
OPTIONS ( format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/american_users.csv']  );

CREATE OR REPLACE EXTERNAL TABLE `sprint-3-ma-julia-aquista.bronze.european_users_raw` 
OPTIONS ( format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/european_users.csv']  );


CREATE OR REPLACE EXTERNAL TABLE `sprint-3-ma-julia-aquista.bronze.credit_cards_raw` 
OPTIONS ( format = 'CSV',
  uris = ['gs://bootcamp-data-analytics-public/CRM/credit_cards.csv']  );


#------S3.N1.E4.a

CREATE OR REPLACE TABLE
  `sprint-3-ma-julia-aquista`.bronze.transactions_raw_native AS
SELECT
  *
FROM
  `sprint-3-ma-julia-aquista`.bronze.transactions_raw;


#------S3.N1.E4.b
SELECT id FROM bronze.transactions_raw;

SELECT id FROM bronze.transactions_raw_native;

#------S3.N1.E4.c

SELECT * FROM `bronze.transactions_raw_native`;

SELECT * FROM `bronze.transactions_raw_native` LIMIT 10;

SELECT id FROM `bronze.transactions_raw_native`;


#------S3.N1.E5

SELECT DATE(timestamp) AS fecha, ROUND(SUM(amount),2) AS ttl_vendido
FROM `sprint-3-ma-julia-aquista`.bronze.transactions_raw_native
WHERE EXTRACT(YEAR FROM timestamp) = 2021 
AND declined = 0
GROUP BY fecha
ORDER BY ttl_vendido DESC
LIMIT 5;

#------S3.N1.E6

SELECT company_name, country, DATE(timestamp) AS fecha 
FROM `sprint-3-ma-julia-aquista`.bronze.transactions_raw_native  AS transactions_raw_native
JOIN `sprint-3-ma-julia-aquista`.bronze.companies_raw  AS companies_raw
ON transactions_raw_native.business_id = companies_raw.company_id
WHERE DATE(timestamp) IN (DATE '2015-04-29', DATE '2018-07-20', DATE '2024-03-13')
AND declined = 0
AND  amount > 100 AND amount < 200
GROUP BY  country, company_name, fecha
ORDER BY company_name DESC;


#------S3.N2.E1

CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.products_clean AS 
SELECT *
FROM `sprint-3-ma-julia-aquista`.`bronze.products_raw_nativa`;
#--------

ALTER TABLE `sprint-3-ma-julia-aquista`.silver.products_clean
RENAME COLUMN id TO product_id;


ALTER TABLE `sprint-3-ma-julia-aquista`.silver.products_clean
RENAME COLUMN product_name TO name;
#-------

CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.products_clean  AS
SELECT * REPLACE (SAFE_CAST(price AS FLOAT64) AS price,
                  SAFE_CAST(REPLACE(warehouse_id, 'WH-', '') AS INT64) AS warehouse_id)
FROM `sprint-3-ma-julia-aquista`.`bronze.products_raw_nativa`;

#------S3.N2.E2

CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.transactions_clean AS 
SELECT id AS transaction_id,* EXCEPT (id)
REPLACE(IFNULL(SAFE_CAST(amount AS FLOAT64),0) AS amount,
              (SAFE_CAST(timestamp AS TIMESTAMP)) AS timestamp,
              SAFE_CAST(lat AS FLOAT64) AS lat,
              SAFE_CAST(longitude AS FLOAT64) AS longitude,
              ARRAY(
                     SELECT SAFE_CAST(TRIM(valor) AS INT64)
                     FROM UNNEST(SPLIT(product_ids, ',')) AS valor
                                                                    ) AS product_ids)
FROM `sprint-3-ma-julia-aquista`.bronze.transactions_raw;

#------S3.N2.E3

CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.users_combined AS
SELECT *, 'american' AS origin 
FROM `sprint-3-ma-julia-aquista`.bronze.american_users_raw
UNION ALL
SELECT *, 'eurpean' AS origin 
FROM `sprint-3-ma-julia-aquista`.bronze.european_users_raw;

#------S3.N2.E4.T1

CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.companies_clean AS
SELECT *
FROM `sprint-3-ma-julia-aquista`.bronze.companies_raw;

#------S3.N2.E4.T2


CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.silver.credit_cards_clean AS
SELECT *
FROM `sprint-3-ma-julia-aquista`.bronze.credit_cards_raw;

#------S3.N3.E1
ALTER TABLE `sprint-3-ma-julia-aquista`.silver.companies_clean
  RENAME COLUMN string_field_0 TO company_id,
  RENAME COLUMN string_field_1 TO company_name,
  RENAME COLUMN string_field_2 TO phone,
  RENAME COLUMN string_field_3 TO email,
  RENAME COLUMN string_field_4 TO country,
  RENAME COLUMN string_field_5 TO website;


CREATE OR REPLACE VIEW `sprint-3-ma-julia-aquista`.gold.v_marketing_kpis AS
SELECT company_name, phone, country,
ROUND(AVG(trans_clean.amount), 2) AS avg_amount,
CASE WHEN AVG(trans_clean.amount) > 260 
     THEN "Premium"
     ELSE "Standard" END AS client_tier
  FROM `sprint-3-ma-julia-aquista`.silver.companies_clean AS compa_clean
  JOIN `sprint-3-ma-julia-aquista`.silver.transactions_clean AS trans_clean
ON compa_clean.company_id = trans_clean.business_id
WHERE declined = 0
GROUP BY company_name, phone, country;


SELECT *
FROM `sprint-3-ma-julia-aquista`.gold.v_marketing_kpis
ORDER BY client_tier ASC, avg_amount DESC;


#------S3.N3.E2


CREATE OR REPLACE TABLE `sprint-3-ma-julia-aquista`.gold.product_sales_marketing AS 
SELECT id, product_name, price, colour, COUNT(transaction_id) AS total_sold
FROM `sprint-3-ma-julia-aquista`.silver.products_clean
LEFT JOIN (SELECT transaction_id, id_product             
           FROM `sprint-3-ma-julia-aquista`.silver.transactions_clean
           CROSS JOIN UNNEST(product_ids) AS id_product) AS prod_id
ON products_clean.id = prod_id.id_product
GROUP BY id, product_name, price, colour
ORDER BY total_sold DESC;


#------S3.N3.E3

SELECT *
FROM `sprint-3-ma-julia-aquista`.gold.product_sales_marketing
ORDER BY total_sold DESC;










