# Cambios en KNIME por la corrección del diseño de la bodega

> **Segunda corrección (12 de noviembre de 2026).** Aplicando la misma regla de la docente (la variable objetivo y todo lo que cambia en el momento de la medición va en la tabla de hechos), se eliminó también `dim_prediccion`: la `fuente` del dato y el `nivel_riesgo` del modelo pasaron a la tabla de hechos como atributos de la medición. La bodega queda con **2 dimensiones** (`dim_paciente` y `dim_tiempo`). En el flujo se borraron el lector de `dim_prediccion` y el Joiner *"Buscar la clave real de predicción"*; el Column Filter de evaluaciones incluye `fuente` y `nivel_riesgo`; el antijoin de duplicados compara `sk_paciente`, `sk_tiempo` y `fuente`; y la consulta de validación se actualizó. El flujo queda con **74 nodos**. Estos cambios ya están aplicados en `knime/ETL_ACV.knwf`.

## Primera corrección

## Qué cambió en la bodega

La docente pidió separar lo que es de la persona de lo que se mide en cada consulta:

- **`dim_paciente`** ahora incluye `hipertension` y `enfermedad_cardiaca`, porque son de la persona y no cambian en cada consulta.
- **`fact_evaluacion_acv`** ahora incluye `rango_edad`, `rango_glucosa` y `rango_imc`, porque salen de valores que se miden en cada evaluación.
- **`dim_perfil_clinico` se eliminó**, y con ella la llave `sk_perfil_clinico` de la tabla de hechos.

Usar el `bodega/bodega_acv.db` nuevo. Trae `dim_tiempo` (365 filas) y `dim_prediccion` (12 filas) cargadas; `dim_paciente` y la tabla de hechos están vacías.

---

## ETL_ACV.knwf: 6 pasos

**Estos cambios ya están aplicados en `knime/ETL_ACV.knwf`.** Solo falta el paso 1 (apuntar el DB Connector a la copia de la bodega nueva) y ejecutar. La lista queda como registro de lo que se cambió. Los nodos se identifican por su número (#) en el flujo.

### 1. Conectar la bodega nueva
Copiar el `bodega_acv.db` nuevo como `bodega_acv_trabajo.db` y apuntar el **DB Connector (#50)** a esa copia. No reutilizar la copia anterior: tiene el esquema viejo.

### 2. Borrar la búsqueda del perfil clínico
Eliminar estos dos nodos:
- **DB Query Reader (#30)**, el que tiene `SELECT * FROM dim_perfil_clinico`.
- **Joiner (#40)**, el que cruza por hipertension, enfermedad_cardiaca, rango_edad, rango_glucosa y rango_imc para sacar `sk_perfil_clinico`.

### 3. Reconectar
Conectar la salida del **Joiner (#402)** a la entrada del **Constant Value Column Appender (#41)**, el que agrega `fecha_carga`. Antes ahí llegaba la salida del Joiner #40.

### 4. GroupBy (#20): agregar dos columnas a la agrupación
En *Group settings*, pasar a la lista incluida:
- `hipertension`
- `enfermedad_cardiaca`

Quedan 10 columnas: sk_paciente, id_paciente, genero, alguna_vez_casado, tipo_residencia, tipo_trabajo, tabaquismo, fuma_o_fumo, hipertension, enfermedad_cardiaca. Así el DB Writer (#21) escribe estas dos columnas en `dim_paciente`.

### 5. Column Filter (#42): columnas de la tabla de hechos
- **Quitar:** `sk_perfil_clinico`
- **Agregar:** `rango_edad`, `rango_glucosa`, `rango_imc`

Quedan 12 columnas: sk_paciente, sk_tiempo, sk_prediccion, edad, rango_edad, glucosa_promedio, rango_glucosa, imc, rango_imc, imc_imputado, acv_real, cantidad.

### 6. DB Query Reader (#44): consulta de validación
Reemplazar el SQL por este, que ya no cuenta perfiles y sí revisa las columnas nuevas:

```sql
SELECT 'pacientes' control, COUNT(*) resultado, 5110 esperado FROM dim_paciente
UNION ALL SELECT 'evaluaciones históricas', COUNT(*), 5110 FROM fact_evaluacion_acv
UNION ALL SELECT 'calendario 2026', COUNT(*), 365 FROM dim_tiempo
UNION ALL SELECT 'catálogo predicción', COUNT(*), 12 FROM dim_prediccion
UNION ALL SELECT 'IMC imputados', SUM(imc_imputado), 201 FROM fact_evaluacion_acv
UNION ALL SELECT 'ACV reales', SUM(acv_real), 249 FROM fact_evaluacion_acv
UNION ALL SELECT 'hipertensos', SUM(hipertension = 'Sí'), 498 FROM dim_paciente
UNION ALL SELECT 'con enfermedad cardíaca', SUM(enfermedad_cardiaca = 'Sí'), 276 FROM dim_paciente
UNION ALL SELECT 'mayores de 75', SUM(rango_edad = '75+'), 518 FROM fact_evaluacion_acv
UNION ALL SELECT 'errores de claves foráneas', COUNT(*), 0 FROM pragma_foreign_key_check
UNION ALL SELECT 'predicciones pendientes', COUNT(*), 5110 FROM fact_evaluacion_acv WHERE probabilidad_acv IS NULL AND prediccion_acv IS NULL;
```

### Ejecutar y comprobar
Ejecutar todo el flujo. En la salida del DB Query Reader (#44), `resultado` debe ser igual a `esperado` en todas las filas. Estos valores se comprobaron con una carga de prueba de los 5.110 registros sobre la bodega corregida.

Luego actualizar los pantallazos del flujo ETL (figuras 3 a 6 del informe), porque ya no aparecen los dos nodos borrados. El flujo queda con 76 nodos.

---

## PracticaBodega.knwf (minería y gráficas)

Solo hay que cambiar algo si alguna consulta usa `dim_perfil_clinico` o `sk_perfil_clinico`. Si leían solo edad, glucosa, IMC y `acv_real` de la tabla de hechos, no cambia nada.

Si alguna consulta usa esa tabla, reemplazarla por esta, que trae las mismas columnas que antes:

```sql
SELECT f.edad, f.glucosa_promedio, f.imc, f.acv_real,
       f.rango_edad, f.rango_glucosa, f.rango_imc,
       p.genero, p.alguna_vez_casado, p.tipo_trabajo, p.tabaquismo,
       p.hipertension, p.enfermedad_cardiaca
FROM fact_evaluacion_acv f
JOIN dim_paciente p ON f.sk_paciente = p.sk_paciente
WHERE f.acv_real IS NOT NULL
```

Los resultados del árbol de decisión y las 3 gráficas no cambian, porque los datos son los mismos.
