# ETL de la bodega de ACV en KNIME

Este flujo corresponde al punto 2 de la práctica de BI: transforma el CSV histórico y carga las dimensiones de pacientes y la tabla de hechos de la bodega diseñada por el equipo.

## Archivos

- [ETL_ACV.knwf](../../knime/ETL_ACV.knwf): proyecto KNIME con el CSV y las tablas de equivalencias incluidos.
- [bodega_acv.db](../../bodega/bodega_acv.db): base original, con los catálogos cargados y pacientes y evaluaciones vacíos.
- [crear_bodega.sql](../../bodega/crear_bodega.sql): creación de la bodega del punto 1.
- [flujo.svg](flujo.svg): vista del flujo exportada desde KNIME.
- [validacion.json](validacion.json): resultados de la validación realizada.

## Importar y ejecutar

1. Descargar `knime/ETL_ACV.knwf` e importarlo desde **Local space → Import workflow** en KNIME. Se validó con KNIME Analytics Platform 5.12.
2. Copiar `bodega/bodega_acv.db` a una carpeta de trabajo con el nombre `bodega_acv_trabajo.db`. Así se conserva la base original del repositorio. La copia debe contener sus tres catálogos iniciales.
3. Abrir **DB Connector** y establecer la URL JDBC de esa copia. Por ejemplo, en Windows: `jdbc:sqlite:C:/ruta/bodega_acv_trabajo.db`. La ruta se deja vacía en el archivo distribuido para que cada integrante elija su copia; no requiere usuario ni contraseña.
4. Ejecutar todo el flujo. Los CSV usan rutas relativas al proyecto importado; no es necesario configurar cada lector.
5. Consultar la salida del último **DB Query Reader** y comparar `resultado` con `esperado`.

El archivo se distribuye sin resultados en caché: hay que ejecutarlo para generar sus salidas. No sobrescribir la base original del repositorio con pruebas locales.

## Transformaciones y carga

- **Row Filter**, columnas constantes y **Concatenate** separan los IMC ausentes y presentes para conservar `imc_imputado`.
- **Missing Value** calcula la mediana del IMC y completa los valores ausentes.
- **Column Renamer** adapta los nombres al esquema de la bodega.
- Siete **Joiner** consultan pequeñas tablas de equivalencias para traducir las categorías.
- Para los rangos de edad, glucosa e IMC, **Row Filter** selecciona los intervalos, **Constant Value Column Appender** agrega las etiquetas y **Concatenate** reúne las ramas disjuntas.
- **Column Filter**, **Column Renamer** y **Joiner** conservan el ID original y agregan la clave de paciente.
- **GroupBy** obtiene pacientes únicos.
- Los **DB Query Reader** leen los catálogos existentes. Los **Joiner** encuentran las claves de perfil clínico, fecha y predicción.
- Dos uniones que conservan solo las filas sin coincidencia excluyen pacientes y evaluaciones ya cargados. Los dos **DB Writer** insertan únicamente registros nuevos. Esta ETL no actualiza evaluaciones ya existentes.

Los 78 nodos no incluyen Rule Engine ni SQL Executor. Los DB Query Reader solo consultan la base.

## Criterios utilizados

- Fecha de carga fija: **2026-10-28**. Representa la carga, porque el CSV no tiene fecha clínica. Para otra carga, editar la constante `fecha_carga` y comprobar que exista en el calendario.
- Edad: menor de 18, 18–39, 40–59, 60–74 y 75 o más; se conserva el valor decimal original.
- Glucosa, según el catálogo del punto 1: menor de 100 → Normal; desde 100 hasta menos de 126 → Prediabetes; desde 126 → Diabetes.
- IMC: menor de 18,5 → Bajo peso; desde 18,5 hasta menos de 25 → Normal; desde 25 hasta menos de 30 → Sobrepeso; desde 30 → Obesidad.
- Los tipos de trabajo respetan las etiquetas de la bodega: Empleado privado, Independiente, Empleado público, Niño / menor y Nunca ha trabajado.
- `acv_real` conserva `stroke`. `probabilidad_acv` y `prediccion_acv` quedan NULL. El histórico se relaciona con **Sin predicción**, clave 4, obtenida mediante una unión con el catálogo. La clave 1 corresponde a BAJO y no se utiliza para registros sin predicción.

No se cambian el esquema ni los catálogos. La carga actual utiliza el histórico; el CSV de datos futuros queda como referencia, sin cargar. El entrenamiento y las visualizaciones corresponden a los puntos 3 y 4.

## Validación

El 2026-10-28 se ejecutaron los 78 nodos y se verificaron individualmente los 5.110 registros contra el CSV y los perfiles de la base publicada:

- 5.110 pacientes y 5.110 evaluaciones.
- 240 perfiles, 365 fechas y 12 entradas de predicción.
- 201 IMC imputados con mediana 28,1.
- 249 registros con ACV real.
- Cero errores de claves foráneas e integridad SQLite correcta.
- Esquema y catálogos idénticos a la base de partida.

GroupBy puede advertir que no hay agregaciones: se usa para obtener combinaciones únicas, como en el ejercicio de clase. En la primera carga los lectores de pacientes y evaluaciones existentes devuelven tablas vacías; es lo esperado.
