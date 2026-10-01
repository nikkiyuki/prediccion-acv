"""Entrena el modelo final con el mismo procedimiento del notebook notebooks/Mineria_Datos_Python.ipynb.

Modelo final: Random Forest optimizado con GridSearch
(n_estimators=150, max_depth=20, min_samples_leaf=10, max_samples=0.9),
dentro de un pipeline SMOTENC -> MinMaxScaler -> Random Forest, entrenado con el 100 % de los datos.

Uso:  python entrenar_modelo.py   (genera modelo_final.pkl)
"""
import pickle

import pandas as pd
from imblearn.over_sampling import SMOTENC
from imblearn.pipeline import Pipeline
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.preprocessing import MinMaxScaler


def entrenar(ruta_datos="data/healthcare-dataset-stroke-data.csv"):
    datos1 = pd.read_csv(ruta_datos)

    # Limpieza y selección de factores
    datos1 = datos1.drop(["id", "gender", "Residence_type"], axis=1)
    datos1[["bmi"]] = SimpleImputer(strategy="median").fit_transform(datos1[["bmi"]])

    # Variables dummies
    d = pd.get_dummies(datos1, columns=["ever_married"], drop_first=True, dtype=int)
    d = pd.get_dummies(d, columns=["work_type", "smoking_status"], drop_first=False, dtype=int)
    X, y = d.drop("stroke", axis=1), d["stroke"]

    numericas = ["age", "avg_glucose_level", "bmi"]
    posiciones_cat = [i for i, c in enumerate(X.columns) if c not in numericas]

    modelo = Pipeline([
        ("balanceo", SMOTENC(categorical_features=posiciones_cat, k_neighbors=2, random_state=42)),
        ("escalado", ColumnTransformer([("num", MinMaxScaler(), numericas)], remainder="passthrough")),
        ("modelo", RandomForestClassifier(n_estimators=150, max_samples=0.9, criterion="gini",
                                          max_depth=20, min_samples_leaf=10, random_state=42)),
    ])
    modelo.fit(X, y)
    return modelo, X.columns.tolist()


if __name__ == "__main__":
    modelo, variables = entrenar()
    with open("modelo_final.pkl", "wb") as f:
        pickle.dump([modelo, variables], f)
    print("modelo_final.pkl generado. Variables:", variables)
