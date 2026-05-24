# Análisis de Riesgo de Cartera y Crédito

**Pipeline end-to-end de análisis financiero** — desde la ingesta y limpieza de datos hasta un motor predictivo de scoring crediticio con XGBoost y dashboard ejecutivo interactivo en Power BI.

---

## Problema de negocio

> ¿Cómo puede una institución financiera identificar qué segmentos de su cartera concentran mayor riesgo de default, y qué perfil de cliente tiene mayor probabilidad de incumplimiento?

Este proyecto responde esa pregunta construyendo un pipeline completo de análisis de riesgo crediticio: limpieza y exploración en Python, análisis relacional avanzado en MySQL, modelado predictivo con XGBoost y visualización ejecutiva en Power BI.

---

## Stack tecnológico

| Herramienta | Uso en el proyecto |
|---|---|
| **Python** | Ingesta, limpieza de outliers, imputación, EDA, modelado ML |
| **MySQL** | 12 scripts de análisis: estadístico, relacional, CTEs y window functions |
| **Power BI** | Dashboard ejecutivo interactivo con scoring predictivo |
| **scikit-learn** | Regresión Logística, Random Forest, StandardScaler |
| **XGBoost** | Modelo campeón de scoring crediticio |
| **Pandas / Seaborn / Matplotlib** | Manipulación y visualización de datos |

---

## Estructura del repositorio

```
riesgo-crediticio/
│
├── 01_analisis_exploratorio.ipynb         # EDA: limpieza + 6 visualizaciones
├── 02_setup_and_ddl.sql                   # DDL: configuración y estructura MySQL
├── 03_consultas_analiticas.sql            # 12 scripts SQL analíticos
├── 04_modelado_predictivo_LIMPIO.ipynb    # Pipeline ML: Logit → RF → XGBoost
│
├── escalador_standard.pkl                 # StandardScaler serializado
├── modelo_logistica_riesgo.pkl            # Modelo logístico serializado
│
├── datos/
│   ├── 01_datos_limpios_para_sql.csv      # Dataset limpio → MySQL (sep: ;)
│   ├── 02_datos_para_powerbi.csv          # Dataset limpio → Power BI (sep: ,)
│   ├── 03_resultados_predicciones_test.csv # Predicciones modelo logístico
│   ├── 04_resultados_scoring_xgboost.csv  # Scoring final XGBoost + segmentos
│   └── modelo_xgboost_riesgo.pkl         # Modelo XGBoost serializado
│
├── dashboard/
│   └── riesgo_crediticio.pbix            # Dashboard Power BI completo
│
└── README.md
```

---

## Pipeline completo

```
[Kaggle Dataset — ~48.000 registros]
        │
        ▼
[01 — Python: Limpieza y EDA]
  · Filtro de outliers físicos
  · Imputación con mediana
  · 6 visualizaciones exploratorias
        │
        ├─────────────────────────────────────┐
        ▼                                     ▼
[02/03 — MySQL: Análisis Relacional]   [Power BI — Dashboard EDA]
  · 12 scripts estructurados             · KPIs, treemap, ranking
  · CTEs multicapa                       · Filtros interactivos
  · Window functions                     · Score compuesto visual
  · 2 vistas reutilizables
  · Score de riesgo compuesto
        │
        ▼
[04 — Python: Modelado Predictivo]
  · One-Hot Encoding (drop_first)
  · Split 75/25 estratificado
  · StandardScaler sin data leakage
        │
        ├── Regresión Logística (baseline IRB Basilea III)
        ├── Random Forest (bagging · class_weight=balanced)
        └── XGBoost (boosting · scale_pos_weight) ← CAMPEÓN
                │
                └── Segmentación: Bajo / Medio / Alto
                        │
                        ▼
              [Power BI — Dashboard Predictivo]
                · Scoring operativo por cliente
                · Matriz de confusión en dólares
                · Capital en riesgo por segmento
                · Alertas de acción (PD > 99%)
```

---

## Módulo 1 — EDA Python

### Limpieza de datos
- Eliminación de outliers físicos: edad > 90 años, antigüedad laboral > 60 años
- Imputación de nulos en `loan_int_rate` y `person_emp_length` con mediana
- Normalización de nombres de columnas para compatibilidad SQL

### Visualizaciones (6)

| # | Gráfico | Pregunta que responde |
|---|---|---|
| 1 | Histograma de ingresos | ¿Cómo se distribuyen los ingresos de los solicitantes? |
| 2 | Boxplot ingresos vs default | ¿Los clientes en mora tienen menores ingresos? |
| 3 | Matriz de correlación | ¿Qué variables se mueven juntas respecto al riesgo? |
| 4 | Mora por destino del crédito | ¿Qué tipo de préstamo tiene mayor tasa de default? |
| 5 | Mora por tipo de vivienda | ¿La situación habitacional impacta en el riesgo? |
| 6 | Mora por grado crediticio | ¿El scoring crediticio predice correctamente el default? |

---

## Módulo 2 — SQL Analítico (12 scripts)

| Script | Técnica | Pregunta de negocio |
|---|---|---|
| 01 | DDL | Estructura y creación de base de datos |
| 02 | Básico | Verificación de carga y chequeo de nulos |
| 03 | GROUP BY | Estadísticas descriptivas generales |
| 04 | Window Function | ¿Dónde está concentrado el capital de la cartera? |
| 05 | GROUP BY + ORDER | ¿Qué destino de crédito tiene mayor mora? |
| 06 | CTE | ¿Cómo difiere el perfil de quien paga vs quien defaultea? |
| 07 | CTE + Window | ¿Los clientes en mora ganan menos que su segmento? |
| 08 | Vista | Vista reutilizable de riesgo por ingreso |
| 09 | Window suavizada | ¿Cómo evoluciona el riesgo según antigüedad crediticia? |
| 10 | CTE multicapa | Score de riesgo compuesto con ponderación propia |
| 11 | Vista consolidada | Vista maestra de cartera para reutilización analítica |
| 12 | Window Function | ¿Cómo se distribuye el riesgo por tipo de vivienda? |

```sql
-- Window function suavizada (Script 09)
ROUND(AVG(AVG(loan_status)) OVER(
    ORDER BY cb_person_cred_hist_length
    ROWS BETWEEN 2 PRECEDING AND 2 FOLLOWING
) * 100, 2) AS tasa_mora_suavizada

-- Score de riesgo compuesto con CTE multicapa (Script 10)
ROUND((ratio_deuda_ingreso * 40) + (score_grado * 20) + (loan_int_rate * 2), 2)
    AS score_riesgo_compuesto
```

---

## Módulo 3 — Modelado Predictivo (Basilea III / IRB)

### Decisiones técnicas

**Split estratificado:** `stratify=y` garantiza la misma tasa de mora (21.5%) en train y test, evitando que el azar genere sets desbalanceados.

**StandardScaler solo en train:** el scaler aprende μ y σ exclusivamente del conjunto de entrenamiento. Aplicarlo también al test filtraría información futura al modelo (data leakage).

**drop_first=True en encoding:** con k categorías, k-1 dummies son suficientes. La k-ésima es combinación lineal de las demás, lo que genera multicolinealidad perfecta y viola supuestos del modelo logístico.

**scale_pos_weight en XGBoost:** con 21.5% de mora, el dataset está desbalanceado. `scale_pos_weight = n_negativos / n_positivos ≈ 3.64` penaliza matemáticamente los falsos negativos durante el entrenamiento, alineado con la lógica conservadora de Basilea III.

**Umbral de decisión 0.25 (vs estándar 0.50):** maximiza recall a expensas de precisión. En riesgo crediticio, un falso negativo (default no detectado) tiene mayor costo financiero que un falso positivo.

### Resultados comparativos

| Modelo | AUC-ROC | Gini | Precisión | Recall |
|---|---|---|---|---|
| Regresión Logística | 0.9089 | 0.8178 | — | — |
| Random Forest | 0.9301 | 0.8602 | — | — |
| **XGBoost (campeón)** | **0.9363** | **0.8726** | **81.0%** | **78.3%** |

### Matriz de confusión — XGBoost (n=7.920)

|  | Pred: Al día | Pred: Default |
|---|---|---|
| **Real: Al día** | 5,901 (TN) | 313 (FP) |
| **Real: Default** | 371 (FN) | 1,335 (TP) |

### Segmentación de riesgo

| Segmento | Umbral PD | Clientes | % Cartera |
|---|---|---|---|
| Riesgo Bajo | < 20% | 3,958 | 49.97% |
| Riesgo Medio | 20–50% | 2,314 | 29.22% |
| Riesgo Alto | > 50% | 1,648 | 20.81% |

---

## Módulo 4 — Dashboard Power BI

### Hoja 1: Análisis Exploratorio
- KPIs: exposición total ($306M), tasa de mora (21.5%), ingreso promedio
- Gráfico de línea: mora según antigüedad crediticia (0–30 años)
- Ranking horizontal: mora por destino del crédito
- Treemap: distribución por tipo de vivienda
- Filtros: tipo de vivienda y grado crediticio (A–G)

### Hoja 2: Monitoreo Predictivo y Scoring
- Capital en riesgo IA por segmento
- Matriz de confusión en dólares
- Scoring operativo: clientes con PD > 99% y acción sugerida
- Distribución de mora real vs predicha por grado (A–G)
- Filtros: tipo de vivienda y grado crediticio

```dax
Tasa Mora % = 
DIVIDE(
    SUM('02_datos_para_powerbi'[estado_prestamo]),
    COUNT('02_datos_para_powerbi'[estado_prestamo])
)
```

---

## Hallazgos principales

- La tasa de mora general de la cartera es del **21.5%**
- **Consolidación de deuda** registra la mayor tasa de default (27.8%), seguida por mejora del hogar (26.7%)
- El riesgo de default **escala bruscamente** a partir del grado D: A=9.5%, B=15.2%, C=20.2%, D=60.4%, G=93.3%
- Los clientes en **alquiler** tienen 4x más probabilidad de default que los propietarios (30.9% vs 7.8%)
- El modelo captura **$15.3M en defaults reales** de un total de $18.7M expuestos en el segmento de riesgo alto

---

## Dataset

**Fuente:** [Credit Risk Dataset — Kaggle (laotse)](https://www.kaggle.com/datasets/laotse/credit-risk-dataset)

Dataset sintético que simula un buró crediticio con ~48.000 registros y 12 variables. Después de limpieza: eliminación de outliers físicos irrazonables.

---

## Reproducibilidad

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/riesgo-crediticio

# Instalar dependencias
pip install pandas numpy seaborn matplotlib scikit-learn xgboost kagglehub

# Ejecutar en orden
# 1. 01_analisis_exploratorio.ipynb
# 2. 04_modelado_predictivo_LIMPIO.ipynb
# El notebook genera automáticamente los CSV y PKL en datos/
```

Para el módulo SQL: importar `01_datos_limpios_para_sql.csv` en MySQL y ejecutar `02_setup_and_ddl.sql` seguido de `03_consultas_analiticas.sql`.

---

## Posibles extensiones

- Validación cruzada estratificada (k-fold) en lugar de un único split
- Optimización de hiperparámetros con Optuna o GridSearchCV
- Análisis SHAP para explicabilidad individual por cliente
- Integración con series del BCRA e IPC del INDEC para contexto macroeconómico argentino
- Conexión directa MySQL → Power BI vía ODBC
- API de scoring con FastAPI para consumo en tiempo real

---

## Autor

**Federico Agustín Chillón**
Estudiante avanzado — Licenciatura en Economía, UNCUYO (Promedio: 7,89/10)
Orientación: Análisis Cuantitativo · Mercados Financieros · Econometría Aplicada

[![LinkedIn](https://img.shields.io/badge/LinkedIn-federico--agustín--chillón-0077B5?style=flat&logo=linkedin)](https://linkedin.com/in/federico-agustín-chillón)
