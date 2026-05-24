-- ==============================================================================
-- PROYECTO: Análisis de Riesgo de Cartera y Crédito
-- Autor: Federico Agustín Chillón
-- Stack: MySQL | Python | Power BI
-- Dataset: Credit Risk Dataset (Kaggle — laotse)
-- ==============================================================================

-- ==============================================================================
-- 01 — CONFIGURACIÓN Y DDL
-- ==============================================================================
CREATE DATABASE IF NOT EXISTS portfolio_finanzas;
USE portfolio_finanzas;

CREATE TABLE IF NOT EXISTS prestamos (
    person_age              INT,
    person_income           INT,
    person_home_ownership   VARCHAR(50),
    person_emp_length       FLOAT,
    loan_intent             VARCHAR(100),
    loan_grade              VARCHAR(5),
    loan_amnt               INT,
    loan_int_rate           FLOAT,
    loan_status             INT,
    loan_percent_income     FLOAT,
    cb_person_default_on_file VARCHAR(5),
    cb_person_cred_hist_length INT
);

DESCRIBE prestamos;

-- ==============================================================================
-- 02 — CARGA Y VERIFICACIÓN DE CONSISTENCIA
-- ==============================================================================
SELECT * FROM prestamos LIMIT 10;

SELECT
    COUNT(*) AS total_registros,
    SUM(CASE WHEN person_age IS NULL THEN 1 ELSE 0 END) AS nulos_age,
    SUM(CASE WHEN person_income IS NULL THEN 1 ELSE 0 END) AS nulos_income,
    SUM(CASE WHEN loan_int_rate IS NULL THEN 1 ELSE 0 END) AS nulos_int_rate,
    SUM(CASE WHEN person_emp_length IS NULL THEN 1 ELSE 0 END) AS nulos_emp_length
FROM prestamos;

-- ==============================================================================
-- 03 — ESTADÍSTICAS DESCRIPTIVAS BASE
-- ==============================================================================
SELECT
    ROUND(AVG(person_age), 1)          AS edad_promedio,
    ROUND(AVG(person_income), 0)       AS ingreso_promedio,
    ROUND(AVG(loan_amnt), 0)           AS monto_prestamo_promedio,
    ROUND(AVG(loan_int_rate), 2)       AS tasa_interes_promedio,
    ROUND(AVG(loan_status) * 100, 2)   AS tasa_mora_general_pct,
    COUNT(*)                           AS total_registros
FROM prestamos;

SELECT
    loan_grade,
    COUNT(*) AS cantidad,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM prestamos), 2) AS pct_total
FROM prestamos
GROUP BY loan_grade
ORDER BY loan_grade;

-- ==============================================================================
-- 04 — CONCENTRACIÓN DE CARTERA (Window Function)
-- ==============================================================================
SELECT
    loan_grade,
    COUNT(*)                                                          AS cantidad_prestamos,
    SUM(loan_amnt)                                                    AS exposicion_total,
    ROUND(SUM(loan_amnt) * 100.0 / SUM(SUM(loan_amnt)) OVER(), 2)   AS pct_cartera,
    ROUND(AVG(loan_int_rate), 2)                                      AS tasa_promedio,
    ROUND(AVG(loan_status) * 100, 2)                                  AS tasa_mora_pct
FROM prestamos
GROUP BY loan_grade
ORDER BY exposicion_total DESC;

-- ==============================================================================
-- 05 — RANKING DE MORA POR DESTINO DEL CRÉDITO
-- ==============================================================================
SELECT
    loan_intent,
    COUNT(*)                              AS total_prestamos,
    SUM(loan_status)                      AS cantidad_defaults,
    ROUND(AVG(loan_status) * 100, 2)      AS tasa_mora_pct,
    ROUND(AVG(loan_amnt), 2)              AS monto_promedio,
    ROUND(AVG(loan_int_rate), 2)          AS tasa_interes_promedio
FROM prestamos
GROUP BY loan_intent
ORDER BY tasa_mora_pct DESC;

-- ==============================================================================
-- 06 — PERFIL DEL CLIENTE EN DEFAULT (CTE Comparativa)
-- ==============================================================================
WITH perfil_clientes AS (
    SELECT
        loan_status,
        ROUND(AVG(person_age), 1)              AS edad_promedio,
        ROUND(AVG(person_income), 0)           AS ingreso_promedio,
        ROUND(AVG(person_emp_length), 1)       AS antiguedad_laboral,
        ROUND(AVG(loan_amnt), 0)               AS monto_promedio,
        ROUND(AVG(loan_int_rate), 2)           AS tasa_promedio,
        ROUND(AVG(loan_percent_income), 3)     AS carga_financiera_promedio
    FROM prestamos
    GROUP BY loan_status
)
SELECT
    CASE WHEN loan_status = 0 THEN 'Al día' ELSE 'Default' END AS estado,
    edad_promedio,
    ingreso_promedio,
    antiguedad_laboral,
    monto_promedio,
    tasa_promedio,
    carga_financiera_promedio
FROM perfil_clientes;

-- ==============================================================================
-- 07 — DESVIACIÓN DE INGRESOS POR GRADO (CTE + Window)
-- ==============================================================================
WITH metricas_por_grado AS (
    SELECT
        loan_grade,
        AVG(person_income) OVER(PARTITION BY loan_grade)   AS avg_income_grade,
        AVG(loan_int_rate) OVER(PARTITION BY loan_grade)   AS avg_int_rate_grade,
        person_income,
        loan_int_rate,
        loan_status
    FROM prestamos
)
SELECT
    loan_grade,
    person_income,
    ROUND(avg_income_grade, 2)                        AS promedio_ingreso_grado,
    ROUND(person_income - avg_income_grade, 2)        AS desviacion_ingreso,
    loan_status
FROM metricas_por_grado
WHERE loan_status = 1
ORDER BY desviacion_ingreso ASC
LIMIT 20;

-- ==============================================================================
-- 08 — VISTA ANALÍTICA DE RIESGO POR INGRESO
-- ==============================================================================
CREATE OR REPLACE VIEW vista_riesgo_por_ingreso AS
WITH metricas_por_grado AS (
    SELECT
        loan_grade,
        AVG(person_income) OVER(PARTITION BY loan_grade) AS avg_income_grade,
        person_income,
        loan_status
    FROM prestamos
)
SELECT * FROM metricas_por_grado;

SELECT
    *,
    ROUND((person_income / avg_income_grade) * 100, 2) AS ratio_ingreso_vs_promedio
FROM vista_riesgo_por_ingreso
WHERE loan_status = 1
LIMIT 10;

-- ==============================================================================
-- 09 — MORA EVOLUTIVA POR ANTIGÜEDAD CREDITICIA (Window Suavizada)
-- ==============================================================================
SELECT
    cb_person_cred_hist_length                                          AS anos_historial,
    COUNT(*)                                                            AS total_clientes,
    SUM(loan_status)                                                    AS cantidad_defaults,
    ROUND(AVG(loan_status) * 100, 2)                                    AS tasa_mora_pct,
    ROUND(AVG(AVG(loan_status)) OVER(
        ORDER BY cb_person_cred_hist_length
        ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
    ) * 100, 2)                                                         AS tasa_mora_suavizada
FROM prestamos
GROUP BY cb_person_cred_hist_length
ORDER BY anos_historial;

-- ==============================================================================
-- 10 — SCORE DE RIESGO COMPUESTO (CTE Multicapa)
-- ==============================================================================
WITH variables_base AS (
    SELECT *,
        loan_amnt / NULLIF(person_income, 0) AS ratio_deuda_ingreso,
        CASE
            WHEN loan_grade IN ('A', 'B') THEN 1
            WHEN loan_grade IN ('C', 'D') THEN 2
            ELSE 3
        END AS score_grado
    FROM prestamos
),
score_final AS (
    SELECT *,
        ROUND((ratio_deuda_ingreso * 40) + (score_grado * 20) + (loan_int_rate * 2), 2) AS score_riesgo_compuesto
    FROM variables_base
)
SELECT
    loan_grade,
    loan_intent,
    ROUND(AVG(score_riesgo_compuesto), 2)   AS score_promedio,
    ROUND(AVG(loan_status) * 100, 2)        AS tasa_mora_real,
    COUNT(*)                                AS total
FROM score_final
GROUP BY loan_grade, loan_intent
ORDER BY score_promedio DESC
LIMIT 20;

-- ==============================================================================
-- 11 — VISTA MAESTRA CONSOLIDADA DE CARTERA
-- ==============================================================================
CREATE OR REPLACE VIEW vista_resumen_cartera AS
SELECT
    loan_grade,
    loan_intent,
    person_home_ownership,
    COUNT(*)                                    AS total_prestamos,
    SUM(loan_amnt)                              AS exposicion_total,
    ROUND(AVG(loan_status) * 100, 2)            AS tasa_mora_pct,
    ROUND(AVG(person_income), 0)                AS ingreso_promedio,
    ROUND(AVG(loan_int_rate), 2)                AS tasa_interes_promedio,
    ROUND(AVG(loan_percent_income), 3)          AS carga_financiera_promedio,
    ROUND(AVG(cb_person_cred_hist_length), 1)   AS historial_promedio
FROM prestamos
GROUP BY loan_grade, loan_intent, person_home_ownership;

SELECT * FROM vista_resumen_cartera ORDER BY tasa_mora_pct DESC;

-- ==============================================================================
-- 12 — ANÁLISIS POR TIPO DE VIVIENDA (Window Function)
-- ==============================================================================
SELECT
    person_home_ownership                                               AS tipo_vivienda,
    COUNT(*)                                                            AS total_prestamos,
    SUM(loan_amnt)                                                      AS exposicion_total,
    ROUND(SUM(loan_amnt) * 100.0 / SUM(SUM(loan_amnt)) OVER(), 2)     AS pct_cartera,
    ROUND(AVG(loan_status) * 100, 2)                                    AS tasa_mora_pct,
    ROUND(AVG(person_income), 0)                                        AS ingreso_promedio,
    ROUND(AVG(loan_int_rate), 2)                                        AS tasa_interes_promedio
FROM prestamos
GROUP BY person_home_ownership
ORDER BY exposicion_total DESC;