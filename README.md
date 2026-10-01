# 🧠 Predicción de riesgo de ACV — Minería de Datos en Python

**Universidad Pontificia Bolivariana**
Jacobo Arévalo Zea · Zharick Rocío Carrillo Grijalba · Nicole Yuqui Vásquez

Modelo predictivo que estima la probabilidad de que un paciente sufra un **accidente cerebrovascular (ACV)** a partir de
datos clínicos y demográficos básicos. Se despliega con una **interfaz gráfica en Streamlit**.

## Contenido del repositorio

| Archivo | Descripción |
|---|---|
| `notebooks/Mineria_Datos_Python.ipynb` | Selección de factores, 6 modelos con validación cruzada, revisión de overfitting/underfitting y GridSearch (1.A, 1.B, 1.C) |
| `notebooks/Despliegue_ACV.ipynb` | Despliegue en Colab: carga del modelo, predicción de datos futuros e interfaz con Gradio |
| `app.py` | Despliegue con interfaz gráfica en **Streamlit** (1.D) |
| `entrenar_modelo.py` | Entrena el modelo final (SMOTENC → MinMaxScaler → Random Forest) con el mismo procedimiento del notebook y genera `modelo_final.pkl` |
| `data/healthcare-dataset-stroke-data.csv` | Datos de entrenamiento ([Kaggle](https://www.kaggle.com/datasets/aouatifcherdid/healthcare-dataset-stroke-data)) |
| `data/datos_futuros.csv` | Pacientes nuevos para probar el despliegue |
| `requirements.txt` | Librerías necesarias |

## Modelo

- **Variables (8):** edad, hipertensión, enfermedad cardíaca, glucosa promedio, IMC, estado civil, tipo de trabajo y tabaquismo.
  Se eliminaron `gender` y `Residence_type` por no tener relación con el ACV.
- **Balanceo:** SMOTENC aplicado solo en entrenamiento, dentro del pipeline.
- **Mejor modelo:** Random Forest optimizado con GridSearch: 150 árboles, profundidad 20, mínimo 10 por hoja.
- **Resultados en prueba (30 %):** AUC ≈ 0.83, recall de la clase ACV ≈ 0.65 y precisión ≈ 0.16.
  Sirve como herramienta de alerta (tamizaje), no como diagnóstico.

Al iniciar, la app carga `modelo_final.pkl`. Si no existe, entrena el mismo modelo final con `entrenar_modelo.py` y lo guarda en caché.

## Ejecutar localmente

```bash
pip install -r requirements.txt
streamlit run app.py
```

## Despliegue en Streamlit Community Cloud

1. Entrar a [share.streamlit.io](https://share.streamlit.io) con la cuenta de GitHub.
2. **Create app** y elegir este repositorio, la rama `main` y el archivo `app.py`.
3. **Deploy.**

> Herramienta académica. No reemplaza un diagnóstico médico.
