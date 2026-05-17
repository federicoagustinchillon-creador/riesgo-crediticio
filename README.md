# 📊 Análisis de Riesgo de Cartera y Crédito

**Pipeline end-to-end de análisis financiero** — desde la ingesta y limpieza de datos hasta un dashboard ejecutivo interactivo, pasando por análisis relacional avanzado en SQL.

---

## 🎯 Problema de negocio

> ¿Cómo puede una institución financiera identificar qué segmentos de su cartera concentran mayor riesgo de default, y qué perfil de cliente tiene mayor probabilidad de incumplimiento?

Este proyecto responde esa pregunta construyendo un pipeline completo de análisis de riesgo crediticio: limpieza y exploración en Python, análisis relacional avanzado en MySQL y visualización ejecutiva en Power BI.

---

## 🗂️ Estructura del repositorio

```
📁 riesgo-crediticio/
│
├── 📓 01_analisis_exploratorio.ipynb      # Pipeline Python: limpieza + EDA completo
├── 🗄️  02_setup_and_ddl.sql              # DDL: configuración y estructura de base de datos
├── 🗄️  03_consultas_analiticas.sql       # 12 scripts SQL: descriptivo + avanzado
├── 📄 04_README.md                        # Documentación del proyecto
│
├── 📁 datos/
│   ├── 01_datos_limpios_para_sql.csv     # Dataset limpio → input MySQL (sep: ;)
│   ├── 02_datos_para_powerbi.csv         # Dataset limpio → input Power BI (sep: ,)
│   └── datos_para_dashboard.csv          # Archivo legacy de compatibilidad
│
└── 📁 dashboard/
    └── riesgo_crediticio.pbix            # Dashboard Power BI interactivo

---

## 🛠️ Stack tecnológico

| Herramienta | Uso en el proyecto |
|---|---|
| **Python** | Ingesta, limpieza de outliers, imputación, EDA con 6 visualizaciones |
| **MySQL** | 12 scripts de análisis: estadístico, relacional, CTEs y window functions |
| **Power BI** | Dashboard ejecutivo interactivo con Power Query (M) para transformación |
| **Pandas** | Manipulación y normalización del dataset |
| **Seaborn / Matplotlib** | Visualizaciones del análisis exploratorio |

---

## 🔄 Pipeline del proyecto

```
[Kaggle Dataset]
      │
      ▼
[Python — Limpieza y EDA]
  • Filtro de outliers físicos (edad > 90, empleo > 60 años)
  • Imputación de nulos con mediana
  • Normalización de columnas (SQL-Friendly)
  • 6 visualizaciones exploratorias
      │
      ├──────────────────────────────────────┐
      ▼                                      ▼
[MySQL — Análisis Relacional]      [Power BI — Dashboard]
  • 12 scripts estructurados          • Power Query (M):
  • CTEs multicapa                      renombre de columnas,
  • Window Functions                    traducción de valores,
  • 2 vistas reutilizables              tipado con cultura en-US
  • Score de riesgo compuesto         • KPIs, gráfico de línea,
                                        ranking de mora, treemap
```

> **Nota de arquitectura:** Python genera dos CSVs paralelos — uno con separador `;` optimizado para importación en MySQL, y otro con `,` para Power BI. La conexión directa MySQL → Power BI vía ODBC está planificada para la V2 del proyecto.

---

## 🐍 Python — Limpieza y EDA

### Limpieza de datos
- Eliminación de registros con edad > 90 años y antigüedad laboral > 60 años
- Imputación de valores nulos en `loan_int_rate` y `person_emp_length` con la mediana
- Normalización de nombres de columnas para compatibilidad con SQL

### Análisis Exploratorio (6 visualizaciones)

| # | Gráfico | Pregunta que responde |
|---|---|---|
| 1 | Histograma de ingresos | ¿Cómo se distribuyen los ingresos de los solicitantes? |
| 2 | Boxplot ingresos vs default | ¿Los clientes en mora tienen menores ingresos? |
| 3 | Matriz de correlación | ¿Qué variables se mueven juntas respecto al riesgo? |
| 4 | Mora por destino del crédito | ¿Qué tipo de préstamo tiene mayor tasa de default? |
| 5 | Mora por tipo de vivienda | ¿La situación habitacional impacta en el riesgo? |
| 6 | Mora por grado de crédito | ¿El scoring crediticio predice correctamente el default? |

---

## 🗄️ SQL — Análisis Relacional (12 scripts)

| Script | Técnica | Pregunta de negocio |
|---|---|---|
| 01 | DDL | Estructura y creación de la base de datos |
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

### Highlights técnicos SQL
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

## 📊 Power BI — Dashboard Ejecutivo

### Transformaciones en Power Query (M)
- Renombre completo de columnas: inglés → español
- Traducción de valores categóricos: `RENT` → `Alquiler`, `MORTGAGE` → `Hipoteca`, etc.
- Tipado de columnas con cultura `"en-US"` para preservar decimales
- Manejo del separador decimal en contexto regional argentino

### Medidas DAX

```dax
Tasa Mora % = 
DIVIDE(
    SUM('02_datos_para_powerbi'[estado_prestamo]),
    COUNT('02_datos_para_powerbi'[estado_prestamo])
)
```

> Calcula la tasa de mora como proporción de defaults sobre el total de préstamos. Al usar `DIVIDE` en lugar del operador `/`, la medida maneja automáticamente la división por cero — práctica estándar en modelos de datos productivos.

### KPIs del dashboard

| Métrica | Valor |
|---|---|
| Exposición total de cartera | $306.011.450 |
| Tasa de mora general | 21,5% |
| Ingreso promedio del solicitante | $66.491 |

### Visualizaciones
- **Gráfico de línea:** comportamiento del riesgo según antigüedad crediticia (0–30 años)
- **Ranking horizontal:** mora por destino del crédito (6 categorías)
- **Treemap:** distribución de préstamos por tipo de vivienda
- **Filtros interactivos:** tipo de vivienda y grado del crédito (A–G)
- **Hoja 2 — Monitoreo Predictivo y Scoring:** en desarrollo — regresión logística y score de riesgo compuesto visual (V3)

---

## 📁 Dataset

**Fuente:** [Credit Risk Dataset — Kaggle (laotse)](https://www.kaggle.com/datasets/laotse/credit-risk-dataset)

Dataset sintético que simula información de un buró crediticio con ~48.000 registros procesados en la versión final y 12 variables.

| Variable | Descripción |
|---|---|
| `person_age` | Edad del solicitante |
| `person_income` | Ingreso anual |
| `person_home_ownership` | Tipo de vivienda (RENT / MORTGAGE / OWN) |
| `person_emp_length` | Antigüedad laboral (años) |
| `loan_intent` | Destino del préstamo |
| `loan_grade` | Grado crediticio asignado (A–G) |
| `loan_amnt` | Monto del préstamo |
| `loan_int_rate` | Tasa de interés |
| `loan_status` | Estado (0 = Al día / 1 = Default) |
| `loan_percent_income` | Cuota como % del ingreso |
| `cb_person_default_on_file` | Historial de mora previo |
| `cb_person_cred_hist_length` | Años de historial crediticio |

**Después de limpieza:** se eliminaron outliers físicos irrazonables (edad > 90 años, antigüedad laboral > 60 años).

---

## 🔍 Hallazgos principales

- La **tasa de mora general** de la cartera es del **21,5%**
- **Consolidación de deuda** registra la mayor tasa de default (28,4%), seguida por préstamos médicos (26,5%)
- El riesgo **no es lineal** con la antigüedad crediticia — clientes con 25 años de historial muestran un mínimo atípico del 6,3%, seguido de un pico del 42,9%
- Los clientes en **default** tienen en promedio menores ingresos y mayor carga financiera relativa que quienes pagan normalmente
- La cartera está concentrada en **Alquiler** ($143,40 mill.) e **Hipoteca** ($139,35 mill.)

---

## 🚀 Próximas versiones

```
V2 — Enriquecimiento con datos macroeconómicos argentinos
  • Integración con series del BCRA (tasas, mora del sistema)
  • Integración con IPC del INDEC (deflactar ingresos)
  • Conexión directa MySQL → Power BI vía ODBC

V3 — Completar Hoja 2 "Monitoreo Predictivo y Scoring" en Power BI
  • Regresión logística (estándar regulatorio Basilea III)
  • Random Forest con comparación de métricas
  • AUC-ROC, matriz de confusión, feature importance
  • Nueva página en Power BI con resultados del modelo
```

---

## 👤 Autor

**Federico Agustín Chillón**
Estudiante avanzado — Licenciatura en Economía, UNCUYO (Promedio: 7,89/10)
Orientación: Análisis Cuantitativo · Mercados Financieros · Econometría Aplicada

[![LinkedIn](https://img.shields.io/badge/LinkedIn-federico--agustín--chillón-0077B5?style=flat&logo=linkedin)](https://linkedin.com/in/federico-agustín-chillón)

---

## ⚙️ Reproducibilidad

```bash
# Clonar el repositorio
git clone https://github.com/tu-usuario/riesgo-crediticio

# Instalar dependencias
pip install pandas numpy seaborn matplotlib kagglehub

# Ejecutar el pipeline
python analisis_riesgo_crediticio.py
```

> El script descarga el dataset automáticamente desde Kaggle vía `kagglehub`. Requiere cuenta en Kaggle y token de API configurado.
