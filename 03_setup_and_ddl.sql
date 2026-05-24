-- Crear base de datos
CREATE DATABASE IF NOT EXISTS portfolio_finanzas;
USE portfolio_finanzas;

-- Crear tabla
CREATE TABLE IF NOT EXISTS prestamos (
    person_age INT,
    person_income INT,
    person_home_ownership VARCHAR(50),
    person_emp_length FLOAT,
    loan_intent VARCHAR(100),
    loan_grade VARCHAR(5),
    loan_amnt INT,
    loan_int_rate FLOAT,
    loan_status INT,
    loan_percent_income FLOAT,
    cb_person_default_on_file VARCHAR(5),
    cb_person_cred_hist_length INT
);

-- Verificación
DESCRIBE prestamos;
USE portfolio_finanzas;

USE portfolio_finanzas;

-- 1. ¿Están todas las filas adentro?
SELECT COUNT(*) AS total_registros FROM prestamos;

-- 2. ¿Los datos cayeron en la columna que corresponde o se corrieron de lugar?
SELECT * FROM prestamos LIMIT 10;
