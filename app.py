"""Despliegue del modelo predictivo de ACV con Streamlit.

Minería de Datos en Python — Universidad Pontificia Bolivariana
Jacobo Arévalo Zea · Zharick Rocío Carrillo Grijalba · Nicole Yuqui Vásquez

Ejecutar localmente:  streamlit run app.py
"""
import os
import pickle

import pandas as pd
import streamlit as st

from entrenar_modelo import entrenar

st.set_page_config(page_title="Predicción de ACV", page_icon="🧠", layout="wide")

UMBRAL = 0.5
TRABAJO = {"Empleado privado": "Private", "Independiente": "Self-employed", "Empleado público": "Govt_job",
           "Niño / menor de edad": "children", "Nunca ha trabajado": "Never_worked"}
FUMA = {"Nunca ha fumado": "never smoked", "Exfumador": "formerly smoked",
        "Fuma actualmente": "smokes", "Desconocido": "Unknown"}


@st.cache_resource(show_spinner="Cargando el modelo...")
def cargar_modelo():
    """Carga el pipeline completo (SMOTENC + MinMaxScaler + Random Forest) y la lista de variables.

    Si modelo_final.pkl no está o fue creado con otra versión de scikit-learn, se entrena el mismo
    modelo final con el código del notebook (entrenar_modelo.py) y se guarda en caché.
    """
    if os.path.exists("modelo_final.pkl"):
        try:
            with open("modelo_final.pkl", "rb") as f:
                modelo, variables = pickle.load(f)
            return modelo, variables
        except Exception:
            pass
    modelo, variables = entrenar()
    with open("modelo_final.pkl", "wb") as f:
        pickle.dump([modelo, variables], f)
    return modelo, variables


modelo, variables = cargar_modelo()


def nivel_riesgo(p):
    if p >= UMBRAL:
        return "ALTO"
    if p >= 0.25:
        return "MODERADO"
    return "BAJO"


def preparar(df):
    """Mismas columnas (dummies) y orden del entrenamiento + revisión de consistencia."""
    df = df.copy()
    if "Edad" in df.columns and "age" not in df.columns:
        df = df.rename(columns={"Edad": "age"})
    df = df.reindex(columns=variables, fill_value=0)
    avisos = []
    trabajo = [c for c in variables if c.startswith("work_type_")]
    for i, fila in df.iterrows():
        if df.loc[i, trabajo].sum() > 1:
            activas = [c for c in trabajo if fila[c] == 1]
            if fila["work_type_children"] == 1 and fila["age"] < 18:
                df.loc[i, trabajo] = 0
                df.loc[i, "work_type_children"] = 1
                avisos.append(f"Fila {i}: tenía {activas}; se dejó work_type_children (edad {fila['age']:.0f}).")
            else:
                avisos.append(f"Fila {i}: tiene varias categorías de trabajo activas {activas}.")
    return df, avisos


# ---------------- Encabezado ----------------
st.title("🧠 Predicción de riesgo de Accidente Cerebrovascular (ACV)")
st.caption("Minería de Datos en Python · Universidad Pontificia Bolivariana — "
           "Jacobo Arévalo Zea · Zharick Rocío Carrillo Grijalba · Nicole Yuqui Vásquez")

with st.sidebar:
    st.header("Sobre el modelo")
    st.markdown(
        "- **Modelo:** Random Forest optimizado con GridSearch\n"
        "- **Pipeline:** SMOTENC → MinMaxScaler → Random Forest\n"
        "- **Datos:** Healthcare Stroke Data (5.110 pacientes)\n"
        "- **Prueba (30 %):** AUC ≈ 0.83 · Recall ≈ 0.65\n"
        f"- **Umbral de decisión:** {UMBRAL:.0%}"
    )
    st.info("Herramienta académica de tamizaje. No reemplaza un diagnóstico médico.")

tab1, tab2 = st.tabs(["👤 Paciente individual", "📄 Archivo CSV (varios pacientes)"])

# ---------------- Pestaña 1: paciente individual ----------------
with tab1:
    col_form, col_res = st.columns([1, 1], gap="large")
    with col_form:
        with st.form("formulario"):
            edad = st.slider("Edad (años)", 0, 100, 67)
            c1, c2 = st.columns(2)
            glucosa = c1.number_input("Glucosa promedio (mg/dL)", min_value=40.0, max_value=300.0, value=210.5, step=0.1)
            imc = c2.number_input("Índice de masa corporal (IMC)", min_value=10.0, max_value=100.0, value=32.1, step=0.1)
            c3, c4, c5 = st.columns(3)
            hipertension = c3.radio("Hipertensión", ["No", "Sí"], index=1, horizontal=True)
            cardiaca = c4.radio("Enfermedad cardíaca", ["No", "Sí"], index=1, horizontal=True)
            casado = c5.radio("¿Alguna vez casado(a)?", ["No", "Sí"], index=1, horizontal=True)
            trabajo = st.selectbox("Tipo de trabajo", list(TRABAJO), index=0)
            fuma = st.selectbox("Tabaquismo", list(FUMA), index=1)
            enviado = st.form_submit_button("Predecir", type="primary", use_container_width=True)

    with col_res:
        if enviado:
            fila = dict.fromkeys(variables, 0)
            fila.update({"age": edad, "hypertension": int(hipertension == "Sí"), "heart_disease": int(cardiaca == "Sí"),
                         "avg_glucose_level": glucosa, "bmi": imc, "ever_married_Yes": int(casado == "Sí")})
            fila["work_type_" + TRABAJO[trabajo]] = 1
            fila["smoking_status_" + FUMA[fuma]] = 1
            paciente = pd.DataFrame([fila])[variables]

            p = float(modelo.predict_proba(paciente)[0, 1])
            nivel = nivel_riesgo(p)

            st.subheader("Resultado")
            m1, m2 = st.columns(2)
            m1.metric("Probabilidad de ACV", f"{p:.1%}")
            m2.metric("Nivel de riesgo", nivel)
            st.progress(p)
            if p >= UMBRAL:
                st.error(f"⚠️ **Riesgo {nivel}.** El modelo clasifica al paciente como **posible caso de ACV**. "
                         "Se recomienda valoración médica prioritaria.")
            elif nivel == "MODERADO":
                st.warning(f"🔶 **Riesgo {nivel}.** No supera el umbral, pero se recomienda seguimiento.")
            else:
                st.success(f"✅ **Riesgo {nivel}.** El modelo clasifica al paciente como **sin ACV**.")
        else:
            st.info("Completa los datos del paciente y presiona **Predecir**.")

# ---------------- Pestaña 2: archivo CSV ----------------
with tab2:
    st.markdown("Sube un archivo con el mismo formato de `datos_futuros.csv` (variables en dummies). "
                "Si no tienes uno, usa el botón para probar con los datos futuros del proyecto.")
    archivo = st.file_uploader("Archivo CSV", type="csv")
    usar_ejemplo = st.button("Usar datos_futuros.csv del proyecto")

    df = None
    if archivo is not None:
        df = pd.read_csv(archivo)
    elif usar_ejemplo:
        df = pd.read_csv("data/datos_futuros.csv")

    if df is not None:
        X, avisos = preparar(df)
        for a in avisos:
            st.warning("⚠️ " + a)
        proba = modelo.predict_proba(X)[:, 1]
        salida = df.copy()
        salida["Probabilidad_ACV"] = proba.round(3)
        salida["Prediccion"] = (proba >= UMBRAL).astype(int)
        salida["Riesgo"] = [nivel_riesgo(p) for p in proba]
        st.dataframe(salida[["age", "hypertension", "heart_disease", "avg_glucose_level", "bmi",
                             "Probabilidad_ACV", "Prediccion", "Riesgo"]], use_container_width=True)
        st.download_button("⬇️ Descargar predicciones", salida.to_csv(index=False).encode("utf-8"),
                           file_name="predicciones.csv", mime="text/csv")
