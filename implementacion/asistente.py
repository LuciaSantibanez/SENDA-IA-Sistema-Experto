"""Consola PG3. Interpreta una consulta, reúne las trazas y presenta los resultados del grafo."""
import argparse
import json
import os
import re
import unicodedata
import urllib.request
from pathlib import Path

from pi4_calcio import conectar, CONSULTAS, BASE

ALIAS = {"CA": r"calcio|ca", "FE": r"hierro|fe", "B12": r"b12|cobalamina", "VD": r"vitamina d|vd"}
MAESTRO = (BASE / "prompts/maestro.txt").read_text(encoding="utf-8-sig")


def modelo(instruccion, entrada, esquema):
    payload = {"model": os.getenv("OLLAMA_MODEL", "qwen2.5:1.5b"), "stream": False,
               "think": False, "format": esquema, "options": {"temperature": 0, "num_ctx": 4096, "num_thread": 2, "num_predict": 160},
               "messages": [{"role":"system","content":instruccion},
                            {"role":"user","content":entrada}]}
    url = os.getenv("OLLAMA_URL","http://127.0.0.1:11434").rstrip("/") + "/api/chat"
    request = urllib.request.Request(url, json.dumps(payload).encode(), {"Content-Type":"application/json"})
    with urllib.request.urlopen(request, timeout=180) as response:
        return json.loads(json.load(response)["message"]["content"])


def resolver(pregunta):
    normal = unicodedata.normalize("NFKD", pregunta.lower()).encode("ascii","ignore").decode()
    ids = set(re.findall(r"\bp\d{2}\b", normal))
    if re.search(r"diagnostic|prescri|tratamiento|dosis|medicame|recet", normal):
        raise ValueError("SENDA permite revisar evaluaciones registradas. Las decisiones clínicas requieren revisión profesional.")
    if len(ids) != 1:
        raise ValueError("Indicá un solo caso registrado, por ejemplo P01.")
    pid = ids.pop().upper()
    pedidos = [k for k, expr in ALIAS.items() if re.search(r"\b(?:" + expr + r")\b", normal)]
    if re.search(r"\bintegral\b|todos los nutrientes", normal):
        pedidos = list(ALIAS)
    if not pedidos:
        raise ValueError("Indicá calcio, hierro, B12, vitamina D o una revisión integral.")
    esquema = {"type":"object","properties":{"paciente":{"type":"string"},
               "modulos":{"type":"array","items":{"enum":list(ALIAS)}}},"required":["paciente","modulos"]}
    ruta = modelo(MAESTRO, pregunta, esquema)
    exacta = ruta.get("paciente") == pid and set(ruta.get("modulos", [])) == set(pedidos)
    modulos = list(dict.fromkeys(ruta["modulos"])) if exacta else pedidos
    filas = {}
    with conectar() as driver, driver.session(database=os.getenv("NEO4J_DATABASE","neo4j"),default_access_mode="READ") as ses:
        def leer(tx):
            adm = tx.run(CONSULTAS["pi4_ADM"], paciente=pid).single()
            if not adm:
                raise ValueError(f"Sin admisibilidad registrada para {pid}.")
            for cod in modulos:
                par = {"paciente":pid, "nutriente":cod}
                resumen = tx.run(CONSULTAS["resumen"], par).single()
                if not resumen:
                    raise ValueError(f"Sin evaluación registrada para {pid} / {cod}.")
                filas[cod] = {"resumen":resumen["contexto"], "traza":tx.run(CONSULTAS["traza"],par).data(),
                              "difuso":tx.run(CONSULTAS["difuso"],par).single().data()}
                if cod != "CA":
                    especializado = tx.run(CONSULTAS["pi4_" + cod], paciente=pid, pid=pid, nutriente=cod).single()
                    if not especializado:
                        raise ValueError(f"El submódulo {cod} no devolvió contexto.")
                    filas[cod]["contexto_PI4"] = especializado["contexto"]
                filas[cod]["admision_PI4"] = adm["contexto"]
        ses.execute_read(leer)
    opciones = []
    for cod, fila in filas.items():
        ctx = fila["resumen"]
        for item in ctx["traza"]:
            if item.get("texto"):
                opciones.append(f"{cod} · {item['regla']} · {item['texto']}")
    indices = []
    if opciones:
        indices = modelo("Elegí hasta tres índices de los fundamentos que mejor explican el resultado solicitado. Usá solo la lista numerada. Respondé en JSON.",
                         pregunta + "\n" + json.dumps(list(enumerate(opciones)),ensure_ascii=False),
                         {"type":"object","properties":{"seleccion":{"type":"array","items":{"type":"integer"},"maxItems":3}},"required":["seleccion"]}).get("seleccion",[])
    fundamentos = [opciones[i] for i in dict.fromkeys(indices) if type(i) is int and 0 <= i < len(opciones)][:3] or opciones[:1]
    respuesta = [f"{pid} · Admisibilidad: {next(iter(filas.values()))['resumen']['admisibilidad']}"]
    for cod, fila in filas.items():
        ctx, dif = fila["resumen"], fila["difuso"]
        respuesta.append(f"{cod}: {ctx['estado'].replace('_',' ').lower()}. {ctx.get('fundamento') or ''}")
        for clave, etiqueta in [("prioridad_ca","Prioridad auxiliar de revisión"),("indice","Índice difuso")]:
            if dif.get(clave) is not None:
                respuesta.append(f"{etiqueta}: {dif[clave]} (valor auxiliar sujeto a revisión profesional).")
        respuesta.extend(x["texto"] for x in ctx["datos_faltantes"] + ctx["advertencias"] if x.get("texto"))
    respuesta.extend(fundamentos)
    return {"pregunta":pregunta,"modelo":os.getenv("OLLAMA_MODEL","qwen2.5:1.5b"),"ruta_llm":ruta,"ruta_verificada":exacta,"paciente":pid,"modulos":filas,
            "fundamentos_seleccionados":fundamentos,"respuesta":"\n".join(dict.fromkeys(respuesta))}


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("pregunta", nargs="?")
    p.add_argument("--registro",type=Path)
    args = p.parse_args()
    try:
        resultado = resolver(args.pregunta or input("Consulta SENDA > "))
        print(resultado["respuesta"])
        if args.registro:
            args.registro.write_text(json.dumps(resultado,ensure_ascii=False,indent=2),encoding="utf-8")
    except (ValueError, OSError) as exc:
        p.exit(1, str(exc)+"\n")




