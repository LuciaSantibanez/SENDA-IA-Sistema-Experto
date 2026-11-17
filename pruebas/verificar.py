"""Repite las pruebas contra el grafo cargado y Ollama local."""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "implementacion"))
from asistente import resolver

CASOS = [
    ("P01","Compará calcio y hierro de P01", ["CA","FE"]),
    ("P02","Revisión integral de P02", ["CA","FE","B12","VD"]),
    ("P03","Contrastá B12 y vitamina D de P03", ["B12","VD"]),
    ("P05","Explicá la vitamina D y el calcio de P05", ["VD","CA"]),
    ("P09","¿Qué muestran hierro y B12 en P09?", ["FE","B12"]),
]
if __name__ == "__main__":
    esperados = {r["paciente"]:r for r in csv.DictReader((ROOT/"base/carga/casos_resultado_esperado.csv").open(encoding="utf-8-sig"))}
    for pid, pregunta, codigos in CASOS:
        if sys.argv[1:] and pid not in sys.argv[1:]:
            continue
        r = resolver(pregunta)
        assert set(r["modulos"]) == set(codigos), pid
        for cod in codigos:
            fila = r["modulos"][cod]
            ctx = fila["resumen"]
            assert ctx["estado"] == esperados[pid][cod].split()[0], (pid,cod,ctx["estado"])
            assert ctx["admisibilidad"] == esperados[pid]["ADM"].split()[0]
            assert fila["traza"] and ctx["estado"].replace("_"," ").lower() in r["respuesta"]
        if pid in ("P05","P09"):
            assert any(f["difuso"]["activaciones"] for f in r["modulos"].values())
        (ROOT/f"pruebas/{pid}.json").write_text(json.dumps(r,ensure_ascii=False,indent=2),encoding="utf-8")
        print(pid, "OK",flush=True)

