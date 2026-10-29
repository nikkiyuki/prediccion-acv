-- =====================================================================
-- Bodega de datos: Predicción de riesgo de ACV
-- Esquema estrella: 1 tabla de hechos + 4 dimensiones
-- Motor: SQLite 3 (compatible con KNIME mediante el nodo "SQLite Connector",
--        cuyo driver JDBC viene incluido en KNIME Analytics Platform)
-- Minería de Datos en Python · Universidad Pontificia Bolivariana
-- =====================================================================

PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS fact_evaluacion_acv;
DROP TABLE IF EXISTS dim_paciente;
DROP TABLE IF EXISTS dim_perfil_clinico;
DROP TABLE IF EXISTS dim_tiempo;
DROP TABLE IF EXISTS dim_prediccion;

-- ---------------------------------------------------------------------
-- DIMENSIÓN 1: Paciente (demografía + trabajo + tabaquismo)
-- La llena la ETL de KNIME: una fila por paciente.
-- ---------------------------------------------------------------------
CREATE TABLE dim_paciente (
    sk_paciente        INTEGER PRIMARY KEY,
    id_paciente        INTEGER,                 -- id original del CSV (NULL en pacientes nuevos)
    genero             TEXT NOT NULL,           -- Femenino, Masculino, Otro, Desconocido
    alguna_vez_casado  TEXT NOT NULL,           -- Sí, No
    tipo_residencia    TEXT NOT NULL,           -- Urbana, Rural, Desconocido
    tipo_trabajo       TEXT NOT NULL,           -- Empleado privado, Independiente, Empleado público, Niño / menor, Nunca ha trabajado
    tabaquismo         TEXT NOT NULL,           -- Nunca ha fumado, Exfumador, Fuma actualmente, Desconocido
    fuma_o_fumo        TEXT NOT NULL            -- Sí si fuma actualmente o es exfumador
);

-- ---------------------------------------------------------------------
-- DIMENSIÓN 2: Perfil clínico (dimensión basura)
-- Condición (hipertensión + cardíaca) x rango edad x rango glucosa x rango IMC
-- 4 x 5 x 3 x 4 = 240 filas, precargadas en este script.
-- ---------------------------------------------------------------------
CREATE TABLE dim_perfil_clinico (
    sk_perfil_clinico    INTEGER PRIMARY KEY,
    hipertension         TEXT NOT NULL,         -- Sí, No
    enfermedad_cardiaca  TEXT NOT NULL,         -- Sí, No
    condicion            TEXT NOT NULL,         -- Ninguna, Solo hipertensión, Solo cardíaca, Ambas
    rango_edad           TEXT NOT NULL,         -- 0–17, 18–39, 40–59, 60–74, 75+
    rango_glucosa        TEXT NOT NULL,         -- Normal (<100), Prediabetes (100–125), Diabetes (>=126)
    rango_imc            TEXT NOT NULL,         -- Bajo peso (<18.5), Normal, Sobrepeso (25–29.9), Obesidad (>=30)
    UNIQUE (hipertension, enfermedad_cardiaca, rango_edad, rango_glucosa, rango_imc)
);

-- ---------------------------------------------------------------------
-- DIMENSIÓN 3: Tiempo (fecha de carga o de predicción)
-- Precargada con el calendario 2026.
-- ---------------------------------------------------------------------
CREATE TABLE dim_tiempo (
    sk_tiempo   INTEGER PRIMARY KEY,            -- AAAAMMDD
    fecha       TEXT NOT NULL UNIQUE,           -- AAAA-MM-DD
    dia         INTEGER NOT NULL,
    mes         INTEGER NOT NULL,
    nombre_mes  TEXT NOT NULL,
    trimestre   INTEGER NOT NULL,
    anio        INTEGER NOT NULL
);

-- ---------------------------------------------------------------------
-- DIMENSIÓN 4: Predicción (fuente del dato + nivel de riesgo del modelo)
-- 3 fuentes x 4 niveles = 12 filas, precargadas en este script.
-- Cortes de riesgo iguales a nivel_riesgo() de app.py.
-- ---------------------------------------------------------------------
CREATE TABLE dim_prediccion (
    sk_prediccion         INTEGER PRIMARY KEY,
    fuente                TEXT NOT NULL,        -- Histórico Kaggle, Datos futuros CSV, App Streamlit
    tiene_resultado_real  TEXT NOT NULL,        -- Sí solo para el histórico
    nivel_riesgo          TEXT NOT NULL,        -- BAJO, MODERADO, ALTO, Sin predicción
    prob_min              REAL,
    prob_max              REAL,
    accion                TEXT NOT NULL,
    UNIQUE (fuente, nivel_riesgo)
);

-- ---------------------------------------------------------------------
-- TABLA DE HECHOS: una fila por evaluación de un paciente
-- La llena la ETL de KNIME.
-- ---------------------------------------------------------------------
CREATE TABLE fact_evaluacion_acv (
    sk_evaluacion      INTEGER PRIMARY KEY AUTOINCREMENT,
    sk_paciente        INTEGER NOT NULL REFERENCES dim_paciente (sk_paciente),
    sk_perfil_clinico  INTEGER NOT NULL REFERENCES dim_perfil_clinico (sk_perfil_clinico),
    sk_tiempo          INTEGER NOT NULL REFERENCES dim_tiempo (sk_tiempo),
    sk_prediccion      INTEGER NOT NULL REFERENCES dim_prediccion (sk_prediccion),
    edad               REAL    NOT NULL,        -- años
    glucosa_promedio   REAL    NOT NULL,        -- mg/dL
    imc                REAL    NOT NULL,        -- kg/m2 (nulos imputados con la mediana)
    imc_imputado       INTEGER NOT NULL DEFAULT 0 CHECK (imc_imputado IN (0, 1)),
    acv_real           INTEGER CHECK (acv_real IN (0, 1)),          -- variable objetivo (stroke); NULL en pacientes nuevos
    probabilidad_acv   REAL    CHECK (probabilidad_acv BETWEEN 0 AND 1),
    prediccion_acv     INTEGER CHECK (prediccion_acv IN (0, 1)),    -- 1 si probabilidad_acv >= 0.5
    cantidad           INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX ix_fact_paciente   ON fact_evaluacion_acv (sk_paciente);
CREATE INDEX ix_fact_perfil     ON fact_evaluacion_acv (sk_perfil_clinico);
CREATE INDEX ix_fact_tiempo     ON fact_evaluacion_acv (sk_tiempo);
CREATE INDEX ix_fact_prediccion ON fact_evaluacion_acv (sk_prediccion);

-- Carga de dim_perfil_clinico (240 filas)
BEGIN;
INSERT INTO dim_perfil_clinico VALUES (1, 'No', 'No', 'Ninguna', '0–17', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (2, 'No', 'No', 'Ninguna', '0–17', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (3, 'No', 'No', 'Ninguna', '0–17', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (4, 'No', 'No', 'Ninguna', '0–17', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (5, 'No', 'No', 'Ninguna', '0–17', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (6, 'No', 'No', 'Ninguna', '0–17', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (7, 'No', 'No', 'Ninguna', '0–17', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (8, 'No', 'No', 'Ninguna', '0–17', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (9, 'No', 'No', 'Ninguna', '0–17', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (10, 'No', 'No', 'Ninguna', '0–17', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (11, 'No', 'No', 'Ninguna', '0–17', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (12, 'No', 'No', 'Ninguna', '0–17', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (13, 'No', 'No', 'Ninguna', '18–39', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (14, 'No', 'No', 'Ninguna', '18–39', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (15, 'No', 'No', 'Ninguna', '18–39', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (16, 'No', 'No', 'Ninguna', '18–39', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (17, 'No', 'No', 'Ninguna', '18–39', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (18, 'No', 'No', 'Ninguna', '18–39', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (19, 'No', 'No', 'Ninguna', '18–39', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (20, 'No', 'No', 'Ninguna', '18–39', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (21, 'No', 'No', 'Ninguna', '18–39', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (22, 'No', 'No', 'Ninguna', '18–39', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (23, 'No', 'No', 'Ninguna', '18–39', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (24, 'No', 'No', 'Ninguna', '18–39', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (25, 'No', 'No', 'Ninguna', '40–59', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (26, 'No', 'No', 'Ninguna', '40–59', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (27, 'No', 'No', 'Ninguna', '40–59', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (28, 'No', 'No', 'Ninguna', '40–59', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (29, 'No', 'No', 'Ninguna', '40–59', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (30, 'No', 'No', 'Ninguna', '40–59', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (31, 'No', 'No', 'Ninguna', '40–59', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (32, 'No', 'No', 'Ninguna', '40–59', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (33, 'No', 'No', 'Ninguna', '40–59', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (34, 'No', 'No', 'Ninguna', '40–59', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (35, 'No', 'No', 'Ninguna', '40–59', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (36, 'No', 'No', 'Ninguna', '40–59', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (37, 'No', 'No', 'Ninguna', '60–74', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (38, 'No', 'No', 'Ninguna', '60–74', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (39, 'No', 'No', 'Ninguna', '60–74', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (40, 'No', 'No', 'Ninguna', '60–74', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (41, 'No', 'No', 'Ninguna', '60–74', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (42, 'No', 'No', 'Ninguna', '60–74', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (43, 'No', 'No', 'Ninguna', '60–74', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (44, 'No', 'No', 'Ninguna', '60–74', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (45, 'No', 'No', 'Ninguna', '60–74', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (46, 'No', 'No', 'Ninguna', '60–74', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (47, 'No', 'No', 'Ninguna', '60–74', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (48, 'No', 'No', 'Ninguna', '60–74', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (49, 'No', 'No', 'Ninguna', '75+', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (50, 'No', 'No', 'Ninguna', '75+', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (51, 'No', 'No', 'Ninguna', '75+', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (52, 'No', 'No', 'Ninguna', '75+', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (53, 'No', 'No', 'Ninguna', '75+', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (54, 'No', 'No', 'Ninguna', '75+', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (55, 'No', 'No', 'Ninguna', '75+', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (56, 'No', 'No', 'Ninguna', '75+', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (57, 'No', 'No', 'Ninguna', '75+', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (58, 'No', 'No', 'Ninguna', '75+', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (59, 'No', 'No', 'Ninguna', '75+', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (60, 'No', 'No', 'Ninguna', '75+', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (61, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (62, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (63, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (64, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (65, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (66, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (67, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (68, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (69, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (70, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (71, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (72, 'Sí', 'No', 'Solo hipertensión', '0–17', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (73, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (74, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (75, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (76, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (77, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (78, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (79, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (80, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (81, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (82, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (83, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (84, 'Sí', 'No', 'Solo hipertensión', '18–39', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (85, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (86, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (87, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (88, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (89, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (90, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (91, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (92, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (93, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (94, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (95, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (96, 'Sí', 'No', 'Solo hipertensión', '40–59', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (97, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (98, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (99, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (100, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (101, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (102, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (103, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (104, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (105, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (106, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (107, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (108, 'Sí', 'No', 'Solo hipertensión', '60–74', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (109, 'Sí', 'No', 'Solo hipertensión', '75+', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (110, 'Sí', 'No', 'Solo hipertensión', '75+', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (111, 'Sí', 'No', 'Solo hipertensión', '75+', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (112, 'Sí', 'No', 'Solo hipertensión', '75+', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (113, 'Sí', 'No', 'Solo hipertensión', '75+', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (114, 'Sí', 'No', 'Solo hipertensión', '75+', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (115, 'Sí', 'No', 'Solo hipertensión', '75+', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (116, 'Sí', 'No', 'Solo hipertensión', '75+', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (117, 'Sí', 'No', 'Solo hipertensión', '75+', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (118, 'Sí', 'No', 'Solo hipertensión', '75+', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (119, 'Sí', 'No', 'Solo hipertensión', '75+', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (120, 'Sí', 'No', 'Solo hipertensión', '75+', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (121, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (122, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (123, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (124, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (125, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (126, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (127, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (128, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (129, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (130, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (131, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (132, 'No', 'Sí', 'Solo cardíaca', '0–17', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (133, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (134, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (135, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (136, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (137, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (138, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (139, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (140, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (141, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (142, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (143, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (144, 'No', 'Sí', 'Solo cardíaca', '18–39', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (145, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (146, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (147, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (148, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (149, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (150, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (151, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (152, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (153, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (154, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (155, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (156, 'No', 'Sí', 'Solo cardíaca', '40–59', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (157, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (158, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (159, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (160, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (161, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (162, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (163, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (164, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (165, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (166, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (167, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (168, 'No', 'Sí', 'Solo cardíaca', '60–74', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (169, 'No', 'Sí', 'Solo cardíaca', '75+', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (170, 'No', 'Sí', 'Solo cardíaca', '75+', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (171, 'No', 'Sí', 'Solo cardíaca', '75+', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (172, 'No', 'Sí', 'Solo cardíaca', '75+', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (173, 'No', 'Sí', 'Solo cardíaca', '75+', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (174, 'No', 'Sí', 'Solo cardíaca', '75+', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (175, 'No', 'Sí', 'Solo cardíaca', '75+', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (176, 'No', 'Sí', 'Solo cardíaca', '75+', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (177, 'No', 'Sí', 'Solo cardíaca', '75+', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (178, 'No', 'Sí', 'Solo cardíaca', '75+', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (179, 'No', 'Sí', 'Solo cardíaca', '75+', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (180, 'No', 'Sí', 'Solo cardíaca', '75+', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (181, 'Sí', 'Sí', 'Ambas', '0–17', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (182, 'Sí', 'Sí', 'Ambas', '0–17', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (183, 'Sí', 'Sí', 'Ambas', '0–17', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (184, 'Sí', 'Sí', 'Ambas', '0–17', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (185, 'Sí', 'Sí', 'Ambas', '0–17', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (186, 'Sí', 'Sí', 'Ambas', '0–17', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (187, 'Sí', 'Sí', 'Ambas', '0–17', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (188, 'Sí', 'Sí', 'Ambas', '0–17', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (189, 'Sí', 'Sí', 'Ambas', '0–17', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (190, 'Sí', 'Sí', 'Ambas', '0–17', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (191, 'Sí', 'Sí', 'Ambas', '0–17', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (192, 'Sí', 'Sí', 'Ambas', '0–17', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (193, 'Sí', 'Sí', 'Ambas', '18–39', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (194, 'Sí', 'Sí', 'Ambas', '18–39', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (195, 'Sí', 'Sí', 'Ambas', '18–39', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (196, 'Sí', 'Sí', 'Ambas', '18–39', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (197, 'Sí', 'Sí', 'Ambas', '18–39', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (198, 'Sí', 'Sí', 'Ambas', '18–39', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (199, 'Sí', 'Sí', 'Ambas', '18–39', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (200, 'Sí', 'Sí', 'Ambas', '18–39', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (201, 'Sí', 'Sí', 'Ambas', '18–39', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (202, 'Sí', 'Sí', 'Ambas', '18–39', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (203, 'Sí', 'Sí', 'Ambas', '18–39', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (204, 'Sí', 'Sí', 'Ambas', '18–39', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (205, 'Sí', 'Sí', 'Ambas', '40–59', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (206, 'Sí', 'Sí', 'Ambas', '40–59', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (207, 'Sí', 'Sí', 'Ambas', '40–59', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (208, 'Sí', 'Sí', 'Ambas', '40–59', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (209, 'Sí', 'Sí', 'Ambas', '40–59', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (210, 'Sí', 'Sí', 'Ambas', '40–59', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (211, 'Sí', 'Sí', 'Ambas', '40–59', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (212, 'Sí', 'Sí', 'Ambas', '40–59', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (213, 'Sí', 'Sí', 'Ambas', '40–59', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (214, 'Sí', 'Sí', 'Ambas', '40–59', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (215, 'Sí', 'Sí', 'Ambas', '40–59', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (216, 'Sí', 'Sí', 'Ambas', '40–59', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (217, 'Sí', 'Sí', 'Ambas', '60–74', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (218, 'Sí', 'Sí', 'Ambas', '60–74', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (219, 'Sí', 'Sí', 'Ambas', '60–74', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (220, 'Sí', 'Sí', 'Ambas', '60–74', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (221, 'Sí', 'Sí', 'Ambas', '60–74', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (222, 'Sí', 'Sí', 'Ambas', '60–74', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (223, 'Sí', 'Sí', 'Ambas', '60–74', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (224, 'Sí', 'Sí', 'Ambas', '60–74', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (225, 'Sí', 'Sí', 'Ambas', '60–74', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (226, 'Sí', 'Sí', 'Ambas', '60–74', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (227, 'Sí', 'Sí', 'Ambas', '60–74', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (228, 'Sí', 'Sí', 'Ambas', '60–74', 'Diabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (229, 'Sí', 'Sí', 'Ambas', '75+', 'Normal', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (230, 'Sí', 'Sí', 'Ambas', '75+', 'Normal', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (231, 'Sí', 'Sí', 'Ambas', '75+', 'Normal', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (232, 'Sí', 'Sí', 'Ambas', '75+', 'Normal', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (233, 'Sí', 'Sí', 'Ambas', '75+', 'Prediabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (234, 'Sí', 'Sí', 'Ambas', '75+', 'Prediabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (235, 'Sí', 'Sí', 'Ambas', '75+', 'Prediabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (236, 'Sí', 'Sí', 'Ambas', '75+', 'Prediabetes', 'Obesidad');
INSERT INTO dim_perfil_clinico VALUES (237, 'Sí', 'Sí', 'Ambas', '75+', 'Diabetes', 'Bajo peso');
INSERT INTO dim_perfil_clinico VALUES (238, 'Sí', 'Sí', 'Ambas', '75+', 'Diabetes', 'Normal');
INSERT INTO dim_perfil_clinico VALUES (239, 'Sí', 'Sí', 'Ambas', '75+', 'Diabetes', 'Sobrepeso');
INSERT INTO dim_perfil_clinico VALUES (240, 'Sí', 'Sí', 'Ambas', '75+', 'Diabetes', 'Obesidad');
COMMIT;

-- Carga de dim_prediccion (12 filas)
BEGIN;
INSERT INTO dim_prediccion VALUES (1, 'Histórico Kaggle', 'Sí', 'BAJO', 0.0, 0.25, 'Sin alerta');
INSERT INTO dim_prediccion VALUES (2, 'Histórico Kaggle', 'Sí', 'MODERADO', 0.25, 0.5, 'Seguimiento');
INSERT INTO dim_prediccion VALUES (3, 'Histórico Kaggle', 'Sí', 'ALTO', 0.5, 1.0, 'Valoración médica prioritaria');
INSERT INTO dim_prediccion VALUES (4, 'Histórico Kaggle', 'Sí', 'Sin predicción', NULL, NULL, 'Ninguna');
INSERT INTO dim_prediccion VALUES (5, 'Datos futuros CSV', 'No', 'BAJO', 0.0, 0.25, 'Sin alerta');
INSERT INTO dim_prediccion VALUES (6, 'Datos futuros CSV', 'No', 'MODERADO', 0.25, 0.5, 'Seguimiento');
INSERT INTO dim_prediccion VALUES (7, 'Datos futuros CSV', 'No', 'ALTO', 0.5, 1.0, 'Valoración médica prioritaria');
INSERT INTO dim_prediccion VALUES (8, 'Datos futuros CSV', 'No', 'Sin predicción', NULL, NULL, 'Ninguna');
INSERT INTO dim_prediccion VALUES (9, 'App Streamlit', 'No', 'BAJO', 0.0, 0.25, 'Sin alerta');
INSERT INTO dim_prediccion VALUES (10, 'App Streamlit', 'No', 'MODERADO', 0.25, 0.5, 'Seguimiento');
INSERT INTO dim_prediccion VALUES (11, 'App Streamlit', 'No', 'ALTO', 0.5, 1.0, 'Valoración médica prioritaria');
INSERT INTO dim_prediccion VALUES (12, 'App Streamlit', 'No', 'Sin predicción', NULL, NULL, 'Ninguna');
COMMIT;

-- Carga de dim_tiempo (calendario 2026)
BEGIN;
INSERT INTO dim_tiempo VALUES (20260101, '2026-01-01', 1, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260102, '2026-01-02', 2, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260103, '2026-01-03', 3, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260104, '2026-01-04', 4, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260105, '2026-01-05', 5, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260106, '2026-01-06', 6, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260107, '2026-01-07', 7, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260108, '2026-01-08', 8, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260109, '2026-01-09', 9, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260110, '2026-01-10', 10, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260111, '2026-01-11', 11, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260112, '2026-01-12', 12, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260113, '2026-01-13', 13, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260114, '2026-01-14', 14, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260115, '2026-01-15', 15, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260116, '2026-01-16', 16, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260117, '2026-01-17', 17, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260118, '2026-01-18', 18, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260119, '2026-01-19', 19, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260120, '2026-01-20', 20, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260121, '2026-01-21', 21, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260122, '2026-01-22', 22, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260123, '2026-01-23', 23, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260124, '2026-01-24', 24, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260125, '2026-01-25', 25, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260126, '2026-01-26', 26, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260127, '2026-01-27', 27, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260128, '2026-01-28', 28, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260129, '2026-01-29', 29, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260130, '2026-01-30', 30, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260131, '2026-01-31', 31, 1, 'enero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260201, '2026-02-01', 1, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260202, '2026-02-02', 2, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260203, '2026-02-03', 3, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260204, '2026-02-04', 4, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260205, '2026-02-05', 5, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260206, '2026-02-06', 6, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260207, '2026-02-07', 7, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260208, '2026-02-08', 8, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260209, '2026-02-09', 9, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260210, '2026-02-10', 10, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260211, '2026-02-11', 11, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260212, '2026-02-12', 12, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260213, '2026-02-13', 13, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260214, '2026-02-14', 14, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260215, '2026-02-15', 15, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260216, '2026-02-16', 16, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260217, '2026-02-17', 17, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260218, '2026-02-18', 18, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260219, '2026-02-19', 19, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260220, '2026-02-20', 20, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260221, '2026-02-21', 21, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260222, '2026-02-22', 22, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260223, '2026-02-23', 23, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260224, '2026-02-24', 24, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260225, '2026-02-25', 25, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260226, '2026-02-26', 26, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260227, '2026-02-27', 27, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260228, '2026-02-28', 28, 2, 'febrero', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260301, '2026-03-01', 1, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260302, '2026-03-02', 2, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260303, '2026-03-03', 3, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260304, '2026-03-04', 4, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260305, '2026-03-05', 5, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260306, '2026-03-06', 6, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260307, '2026-03-07', 7, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260308, '2026-03-08', 8, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260309, '2026-03-09', 9, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260310, '2026-03-10', 10, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260311, '2026-03-11', 11, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260312, '2026-03-12', 12, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260313, '2026-03-13', 13, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260314, '2026-03-14', 14, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260315, '2026-03-15', 15, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260316, '2026-03-16', 16, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260317, '2026-03-17', 17, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260318, '2026-03-18', 18, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260319, '2026-03-19', 19, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260320, '2026-03-20', 20, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260321, '2026-03-21', 21, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260322, '2026-03-22', 22, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260323, '2026-03-23', 23, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260324, '2026-03-24', 24, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260325, '2026-03-25', 25, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260326, '2026-03-26', 26, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260327, '2026-03-27', 27, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260328, '2026-03-28', 28, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260329, '2026-03-29', 29, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260330, '2026-03-30', 30, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260331, '2026-03-31', 31, 3, 'marzo', 1, 2026);
INSERT INTO dim_tiempo VALUES (20260401, '2026-04-01', 1, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260402, '2026-04-02', 2, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260403, '2026-04-03', 3, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260404, '2026-04-04', 4, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260405, '2026-04-05', 5, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260406, '2026-04-06', 6, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260407, '2026-04-07', 7, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260408, '2026-04-08', 8, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260409, '2026-04-09', 9, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260410, '2026-04-10', 10, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260411, '2026-04-11', 11, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260412, '2026-04-12', 12, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260413, '2026-04-13', 13, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260414, '2026-04-14', 14, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260415, '2026-04-15', 15, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260416, '2026-04-16', 16, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260417, '2026-04-17', 17, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260418, '2026-04-18', 18, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260419, '2026-04-19', 19, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260420, '2026-04-20', 20, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260421, '2026-04-21', 21, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260422, '2026-04-22', 22, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260423, '2026-04-23', 23, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260424, '2026-04-24', 24, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260425, '2026-04-25', 25, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260426, '2026-04-26', 26, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260427, '2026-04-27', 27, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260428, '2026-04-28', 28, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260429, '2026-04-29', 29, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260430, '2026-04-30', 30, 4, 'abril', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260501, '2026-05-01', 1, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260502, '2026-05-02', 2, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260503, '2026-05-03', 3, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260504, '2026-05-04', 4, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260505, '2026-05-05', 5, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260506, '2026-05-06', 6, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260507, '2026-05-07', 7, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260508, '2026-05-08', 8, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260509, '2026-05-09', 9, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260510, '2026-05-10', 10, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260511, '2026-05-11', 11, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260512, '2026-05-12', 12, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260513, '2026-05-13', 13, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260514, '2026-05-14', 14, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260515, '2026-05-15', 15, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260516, '2026-05-16', 16, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260517, '2026-05-17', 17, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260518, '2026-05-18', 18, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260519, '2026-05-19', 19, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260520, '2026-05-20', 20, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260521, '2026-05-21', 21, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260522, '2026-05-22', 22, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260523, '2026-05-23', 23, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260524, '2026-05-24', 24, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260525, '2026-05-25', 25, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260526, '2026-05-26', 26, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260527, '2026-05-27', 27, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260528, '2026-05-28', 28, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260529, '2026-05-29', 29, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260530, '2026-05-30', 30, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260531, '2026-05-31', 31, 5, 'mayo', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260601, '2026-06-01', 1, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260602, '2026-06-02', 2, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260603, '2026-06-03', 3, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260604, '2026-06-04', 4, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260605, '2026-06-05', 5, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260606, '2026-06-06', 6, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260607, '2026-06-07', 7, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260608, '2026-06-08', 8, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260609, '2026-06-09', 9, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260610, '2026-06-10', 10, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260611, '2026-06-11', 11, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260612, '2026-06-12', 12, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260613, '2026-06-13', 13, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260614, '2026-06-14', 14, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260615, '2026-06-15', 15, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260616, '2026-06-16', 16, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260617, '2026-06-17', 17, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260618, '2026-06-18', 18, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260619, '2026-06-19', 19, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260620, '2026-06-20', 20, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260621, '2026-06-21', 21, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260622, '2026-06-22', 22, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260623, '2026-06-23', 23, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260624, '2026-06-24', 24, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260625, '2026-06-25', 25, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260626, '2026-06-26', 26, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260627, '2026-06-27', 27, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260628, '2026-06-28', 28, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260629, '2026-06-29', 29, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260630, '2026-06-30', 30, 6, 'junio', 2, 2026);
INSERT INTO dim_tiempo VALUES (20260701, '2026-07-01', 1, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260702, '2026-07-02', 2, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260703, '2026-07-03', 3, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260704, '2026-07-04', 4, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260705, '2026-07-05', 5, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260706, '2026-07-06', 6, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260707, '2026-07-07', 7, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260708, '2026-07-08', 8, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260709, '2026-07-09', 9, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260710, '2026-07-10', 10, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260711, '2026-07-11', 11, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260712, '2026-07-12', 12, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260713, '2026-07-13', 13, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260714, '2026-07-14', 14, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260715, '2026-07-15', 15, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260716, '2026-07-16', 16, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260717, '2026-07-17', 17, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260718, '2026-07-18', 18, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260719, '2026-07-19', 19, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260720, '2026-07-20', 20, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260721, '2026-07-21', 21, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260722, '2026-07-22', 22, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260723, '2026-07-23', 23, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260724, '2026-07-24', 24, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260725, '2026-07-25', 25, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260726, '2026-07-26', 26, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260727, '2026-07-27', 27, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260728, '2026-07-28', 28, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260729, '2026-07-29', 29, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260730, '2026-07-30', 30, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260731, '2026-07-31', 31, 7, 'julio', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260801, '2026-08-01', 1, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260802, '2026-08-02', 2, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260803, '2026-08-03', 3, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260804, '2026-08-04', 4, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260805, '2026-08-05', 5, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260806, '2026-08-06', 6, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260807, '2026-08-07', 7, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260808, '2026-08-08', 8, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260809, '2026-08-09', 9, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260810, '2026-08-10', 10, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260811, '2026-08-11', 11, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260812, '2026-08-12', 12, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260813, '2026-08-13', 13, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260814, '2026-08-14', 14, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260815, '2026-08-15', 15, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260816, '2026-08-16', 16, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260817, '2026-08-17', 17, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260818, '2026-08-18', 18, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260819, '2026-08-19', 19, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260820, '2026-08-20', 20, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260821, '2026-08-21', 21, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260822, '2026-08-22', 22, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260823, '2026-08-23', 23, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260824, '2026-08-24', 24, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260825, '2026-08-25', 25, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260826, '2026-08-26', 26, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260827, '2026-08-27', 27, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260828, '2026-08-28', 28, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260829, '2026-08-29', 29, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260830, '2026-08-30', 30, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260831, '2026-08-31', 31, 8, 'agosto', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260901, '2026-09-01', 1, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260902, '2026-09-02', 2, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260903, '2026-09-03', 3, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260904, '2026-09-04', 4, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260905, '2026-09-05', 5, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260906, '2026-09-06', 6, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260907, '2026-09-07', 7, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260908, '2026-09-08', 8, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260909, '2026-09-09', 9, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260910, '2026-09-10', 10, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260911, '2026-09-11', 11, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260912, '2026-09-12', 12, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260913, '2026-09-13', 13, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260914, '2026-09-14', 14, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260915, '2026-09-15', 15, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260916, '2026-09-16', 16, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260917, '2026-09-17', 17, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260918, '2026-09-18', 18, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260919, '2026-09-19', 19, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260920, '2026-09-20', 20, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260921, '2026-09-21', 21, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260922, '2026-09-22', 22, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260923, '2026-09-23', 23, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260924, '2026-09-24', 24, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260925, '2026-09-25', 25, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260926, '2026-09-26', 26, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260927, '2026-09-27', 27, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260928, '2026-09-28', 28, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260929, '2026-09-29', 29, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20260930, '2026-09-30', 30, 9, 'septiembre', 3, 2026);
INSERT INTO dim_tiempo VALUES (20261001, '2026-10-01', 1, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261002, '2026-10-02', 2, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261003, '2026-10-03', 3, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261004, '2026-10-04', 4, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261005, '2026-10-05', 5, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261006, '2026-10-06', 6, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261007, '2026-10-07', 7, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261008, '2026-10-08', 8, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261009, '2026-10-09', 9, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261010, '2026-10-10', 10, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261011, '2026-10-11', 11, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261012, '2026-10-12', 12, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261013, '2026-10-13', 13, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261014, '2026-10-14', 14, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261015, '2026-10-15', 15, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261016, '2026-10-16', 16, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261017, '2026-10-17', 17, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261018, '2026-10-18', 18, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261019, '2026-10-19', 19, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261020, '2026-10-20', 20, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261021, '2026-10-21', 21, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261022, '2026-10-22', 22, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261023, '2026-10-23', 23, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261024, '2026-10-24', 24, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261025, '2026-10-25', 25, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261026, '2026-10-26', 26, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261027, '2026-10-27', 27, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261028, '2026-10-28', 28, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261029, '2026-10-29', 29, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261030, '2026-10-30', 30, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261031, '2026-10-31', 31, 10, 'octubre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261101, '2026-11-01', 1, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261102, '2026-11-02', 2, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261103, '2026-11-03', 3, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261104, '2026-11-04', 4, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261105, '2026-11-05', 5, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261106, '2026-11-06', 6, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261107, '2026-11-07', 7, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261108, '2026-11-08', 8, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261109, '2026-11-09', 9, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261110, '2026-11-10', 10, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261111, '2026-11-11', 11, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261112, '2026-11-12', 12, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261113, '2026-11-13', 13, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261114, '2026-11-14', 14, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261115, '2026-11-15', 15, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261116, '2026-11-16', 16, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261117, '2026-11-17', 17, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261118, '2026-11-18', 18, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261119, '2026-11-19', 19, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261120, '2026-11-20', 20, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261121, '2026-11-21', 21, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261122, '2026-11-22', 22, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261123, '2026-11-23', 23, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261124, '2026-11-24', 24, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261125, '2026-11-25', 25, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261126, '2026-11-26', 26, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261127, '2026-11-27', 27, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261128, '2026-11-28', 28, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261129, '2026-11-29', 29, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261130, '2026-11-30', 30, 11, 'noviembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261201, '2026-12-01', 1, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261202, '2026-12-02', 2, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261203, '2026-12-03', 3, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261204, '2026-12-04', 4, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261205, '2026-12-05', 5, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261206, '2026-12-06', 6, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261207, '2026-12-07', 7, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261208, '2026-12-08', 8, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261209, '2026-12-09', 9, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261210, '2026-12-10', 10, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261211, '2026-12-11', 11, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261212, '2026-12-12', 12, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261213, '2026-12-13', 13, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261214, '2026-12-14', 14, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261215, '2026-12-15', 15, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261216, '2026-12-16', 16, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261217, '2026-12-17', 17, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261218, '2026-12-18', 18, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261219, '2026-12-19', 19, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261220, '2026-12-20', 20, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261221, '2026-12-21', 21, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261222, '2026-12-22', 22, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261223, '2026-12-23', 23, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261224, '2026-12-24', 24, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261225, '2026-12-25', 25, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261226, '2026-12-26', 26, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261227, '2026-12-27', 27, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261228, '2026-12-28', 28, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261229, '2026-12-29', 29, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261230, '2026-12-30', 30, 12, 'diciembre', 4, 2026);
INSERT INTO dim_tiempo VALUES (20261231, '2026-12-31', 31, 12, 'diciembre', 4, 2026);
COMMIT;
