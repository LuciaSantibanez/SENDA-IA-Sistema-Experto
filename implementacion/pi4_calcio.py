"""PI4 - SENDA / SM-CA. LLM -> JSON -> Cypher fijo -> Neo4j -> explicación.

No carga, modifica ni recalcula el grafo. Uso: python pi4_calcio.py --consulta "..."
Configuración mediante variables de entorno; ver LEEME.txt.
"""
from __future__ import annotations

import argparse
from copy import deepcopy
from uuid import uuid4
import unicodedata
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import sys
import time
import urllib.request

from jsonschema import validate, ValidationError
from neo4j import GraphDatabase, READ_ACCESS, unit_of_work

BASE = Path(__file__).resolve().parent
EXTRACCION = (BASE / "prompts/extraccion.txt").read_text(encoding="utf-8")
EXPLICACION = (BASE / "prompts/explicacion.txt").read_text(encoding="utf-8")
CONSULTAS = {p.stem: p.read_text(encoding="utf-8") for p in (BASE / "consultas").glob("*.cypher")}
SCHEMA = {
    "type": "object", "additionalProperties": False,
    "properties": {
        "intencion": {"type": "string", "enum": ["RESUMEN", "FALTANTES", "TRAZA", "PRIORIDAD", "FUERA_DE_ALCANCE"]},
        "paciente": {"type": ["string", "null"], "pattern": "^P[0-9]{2}$"},
        "nutriente": {"enum": ["CA", "OTRO", None]},
        "requiere_aclaracion": {"type": "boolean"},
    },
    "required": ["intencion", "paciente", "nutriente", "requiere_aclaracion"],
}
SCHEMA_REDACCION = {
    "type": "object", "additionalProperties": False,
    "properties": {"explicacion": {"type": "string", "minLength": 10, "maxLength": 1800}},
    "required": ["explicacion"],
}


class Rechazo(ValueError):
    pass


def json_estricto(texto):
    def unicos(pares):
        obj = {}
        for k, v in pares:
            if k in obj:
                raise Rechazo("JSON con claves duplicadas")
            obj[k] = v
        return obj
    def constante(valor):
        raise Rechazo("Constante JSON inválida: " + valor)
    return json.loads(texto, object_pairs_hook=unicos, parse_constant=constante)


def validar_extraccion(obj, texto):
    validate(obj, SCHEMA)
    # Segunda barrera independiente del modelo para acciones no implementadas.
    if re.search(r"recet|prescrib|diagnostic|dosis|borra|elimina|modifica|ignora.{0,30}reglas", normalizar(texto)):
        raise Rechazo("Este módulo no prescribe, diagnostica ni modifica datos. Consultá el estado, los faltantes, la traza o la prioridad de calcio de un paciente registrado.")
    ids = set(re.findall(r"\bP\d{2}\b", texto.upper()))
    # Un LLM no puede inventar, completar ni elegir un paciente ambiguo.
    if len(ids) != 1 or obj["paciente"] not in ids:
        raise Rechazo("Indicá un único código de paciente, por ejemplo P01.")
    if obj["requiere_aclaracion"]:
        raise Rechazo("Aclarame qué querés consultar sobre el calcio de ese paciente.")
    if obj["nutriente"] != "CA" or obj["intencion"] == "FUERA_DE_ALCANCE":
        raise Rechazo("Este módulo consulta evaluaciones de calcio ya registradas; no diagnostica, prescribe ni modifica datos.")


def conclusion(c):
    if c.get("estado") is None and c.get("situacion_interna") == "PENDIENTE_VALIDACION":
        return "La evaluación de calcio está pendiente de validar un criterio experto."
    return {
        "INFORMACION_INSUFICIENTE": "Todavía falta información para evaluar el calcio.",
        "SIN_SEÑAL_DETECTADA": "No se detectó una señal de ingesta insuficiente de calcio en este registro.",
        "FUERA_DE_ALCANCE": "La evaluación de calcio está fuera del alcance de este módulo.",
        "POSIBLE_INGESTA_INSUFICIENTE": "El grafo señala una posible ingesta insuficiente de calcio.",
    }.get(c.get("estado"), "No se recuperó una conclusión interpretable de calcio.")


def llamar_llm(system, user, schema, historial=None):
    payload = {
        "model": os.getenv("OLLAMA_MODEL", "qwen3:1.7b"),
        "messages": [{"role": "system", "content": system + "\nEsquema JSON obligatorio:\n" + json.dumps(schema, ensure_ascii=False)},
                     {"role": "user", "content": user}] + (historial or []),
        "stream": False, "think": False, "format": schema,
        "options": {"temperature": 0, "seed": 42, "num_ctx": 2048, "num_predict": 220},
        "keep_alive": "10m",
    }
    req = urllib.request.Request(os.getenv("OLLAMA_URL", "http://127.0.0.1:11434").rstrip("/") + "/api/chat",
                                 data=json.dumps(payload).encode("utf-8"), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=float(os.getenv("LLM_TIMEOUT", "600"))) as response:
        result = json.load(response)
    if not result.get("done") or result.get("done_reason") == "length":
        raise Rechazo("Respuesta del modelo incompleta; no se utiliza.")
    return result["message"]["content"], {k: result.get(k) for k in ["model", "total_duration", "prompt_eval_count", "eval_count"]}


def conectar():
    password = os.getenv("NEO4J_PASSWORD")
    auth = (os.getenv("NEO4J_USER", "neo4j"), password) if password else None
    return GraphDatabase.driver(os.getenv("NEO4J_URI", "bolt://127.0.0.1:17687"), auth=auth,
                                connection_timeout=15, max_transaction_retry_time=10, notifications_min_severity="OFF")


def recuperar(obj, auditoria):
    parametros = {"paciente": obj["paciente"], "nutriente": "CA"}
    nombres = ["resumen"]
    if obj["intencion"] != "RESUMEN":
        nombres.append({"FALTANTES": "faltantes", "TRAZA": "traza", "PRIORIDAD": "prioridad"}[obj["intencion"]])
    if obj["intencion"] == "PRIORIDAD":
        nombres.append("criterios")
    @unit_of_work(timeout=20)
    def leer(tx):
        resultados = {}
        ejecuciones = []
        for nombre in nombres:
            query = CONSULTAS[nombre]
            cursor = tx.run(query, **parametros)
            filas = [r.data() for r in cursor]
            summary = cursor.consume()
            if summary.counters.contains_updates:
                raise Rechazo("La consulta produjo una escritura inesperada.")
            resultados[nombre] = filas
            ejecuciones.append({"consulta_id": nombre, "cypher": query, "parametros": parametros, "filas": filas})
        return resultados, ejecuciones
    with conectar() as driver:
        with driver.session(database=os.getenv("NEO4J_DATABASE", "neo4j"), default_access_mode=READ_ACCESS) as session:
            resultados, ejecuciones = session.execute_read(leer)
    auditoria["consultas"] = ejecuciones
    filas = resultados["resumen"]
    if not filas:
        raise Rechazo("No se encontró una evaluación de calcio para ese código. Verificá el paciente; no se infiere ningún estado.")
    if len(filas) != 1:
        raise Rechazo("Se recuperó más de una evaluación de calcio. La base requiere revisión antes de explicar.")
    contexto = deepcopy(filas[0]["contexto"])
    contexto["detalle"] = {k: v for k, v in resultados.items() if k != "resumen"}
    return contexto


def datos_exactos(c):
    lineas = [f"Paciente: {c['paciente']} | Nutriente: calcio",
              "Estado: " + (c.get("estado") or "sin estado asignado"),
              "Situación interna: " + (c.get("situacion_interna") or "no registrada"),
              "Admisibilidad: " + (c.get("admisibilidad") or "no registrada")]
    if c.get("ingesta_estimada") is not None:
        lineas.append(f"Ingesta registrada: {c['ingesta_estimada']} {c.get('unidad') or '(unidad no registrada)'}/día | Alcance: {c.get('ingesta_alcance') or 'no registrado'}")
    if c.get("prioridad_revision_ca") is not None:
        lineas.append(f"Prioridad auxiliar: {c['prioridad_revision_ca']} puntos | {c.get('etiqueta_prioridad')} | Provisional: {c.get('resultado_provisional')}")
    else:
        lineas.append("Prioridad auxiliar: no recuperada (no equivale a cero).")
    return "\n".join(lineas)


def huella_json(obj):
    return hashlib.sha256(json.dumps(obj, ensure_ascii=False, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()


def elegir_evidencia(a, intencion):
    """Selecciona una razón recuperada; conserva su ruta y contenido originales."""
    qs=a["consultas"]
    if intencion == "FALTANTES":
        for qi,q in enumerate(qs):
            if q["consulta_id"] == "faltantes" and q["filas"]:
                return [qi, "filas", 0, "pedido"], q["filas"][0]["pedido"], q["filas"][0]["regla"]
    c=qs[0]["filas"][0]["contexto"]
    campo="traza_admisibilidad" if c.get("admisibilidad") != "ADMISIBLE" else "traza"
    pasos=c[campo]
    preferida="CA-D05" if intencion == "PRIORIDAD" else None
    candidato=next((i for i,t in enumerate(pasos) if t.get("regla")==preferida), None)
    if candidato is None:
        candidato=next((i for i,t in enumerate(pasos) if t.get("efecto") in {"VEREDICTO","FUENTE_VERIFICADA","ESTADO"}), 0)
    if not pasos: raise Rechazo("No se recuperó una evidencia explicable.")
    t=pasos[candidato]
    return [0,"filas",0,"contexto",campo,candidato,"texto"],t["texto"],t["regla"]


def normalizar(t):
    return ''.join(c for c in unicodedata.normalize('NFD',t.lower()) if unicodedata.category(c)!='Mn')


def verificar_redaccion(obj, fuente):
    validate(obj, SCHEMA_REDACCION)
    t=normalizar(obj["explicacion"]); f=normalizar(fuente)
    if not 5 <= len(t.split()) <= 70: raise Rechazo("Usá entre cinco y setenta palabras.")
    # Solo cifras literalmente presentes en esta evidencia, no en otros pacientes.
    numeros=lambda texto: {n.replace(',', '.') for n in re.findall(r"[0-9]+(?:[.,][0-9]+)?",texto)}
    if not numeros(t) <= numeros(f):
        raise Rechazo("La explicación incorpora cifras ajenas a la evidencia.")
    for termino in ["vegetarian","vegan","huevo","embarazo","celiaquia","suplemento","prioridad","validacion","riesgo","deficiencia","normal","salud","probabilidad","exces","toxic","peligro"]:
        if termino in t and termino not in f: raise Rechazo("Concepto no recuperado: "+termino)
    if re.search(r"debes|deberias|te recomiendo|se recomienda|tienes|tenes|padece|asegura|garantiza",t):
        raise Rechazo("No agregues recomendaciones ni afirmaciones clínicas.")
    clinico=re.sub(r"\bno diagnosticad[oa]s?\b", "",t) if "sin diagnostico" in f else t
    if "diagnosticad" in clinico: raise Rechazo("No conviertas una sospecha en un diagnóstico confirmado.")
    if "desconocido" in f and not re.search(r"desconoc|no se conoce|no se sabe|sin conocer|no esta disponible",t):
        raise Rechazo("Conservá explícitamente que el contenido o rótulo es desconocido.")
    if "vegano" in f and not (re.search(r"\bvegan[oa]s?\b",t) and "huevo" in t):
        raise Rechazo("Conservá la contradicción entre VEGANO y Huevo.")
    if "vegano" in f and re.search(r"no consume|no come|excluye|excluyen|sin huevo",t):
        raise Rechazo("El registro incluye Huevo aunque la persona declara VEGANO; no niegues el registro.")
    if re.search(r"redactor|prompt|mi tarea|mi funcion",t): raise Rechazo("Explicá la evidencia del paciente sin hablar del redactor ni de tu tarea.")
    if "sospecha" in f and "sospecha" not in t: raise Rechazo("Es una sospecha registrada, no un diagnóstico.")
    for motivo in ["embarazo","celiaquia"]:
        if motivo in f and motivo not in t: raise Rechazo("Conservá el motivo explícito de la evidencia: "+motivo+". No agregues instrucciones a la explicación.")
    if re.search(r"omiti|omite|explico|explicacion|ese codigo|no mencionado|no se ha cambiado|evidencia proporcionada",t): raise Rechazo("La respuesta debe describir el caso, sin comentarios sobre la tarea de redacción.")
    if re.search(r"inmediat|urgent|emergencia",t) and not re.search(r"inmediat|urgent|emergencia",f): raise Rechazo("La evidencia no establece urgencia ni atención inmediata; conservá solamente la prioridad auxiliar de revisión.")
    if re.search(r"se ha derivado|fue derivad|se ha interrumpido",t): raise Rechazo("El grafo prescribe una acción del módulo; no acredita que ya se haya realizado.")
    if "no se puede explicar" in t: raise Rechazo("Fuera de alcance significa que el módulo no evalúa ese caso; sí puede explicar su límite.")
    if re.search(r"limite\s+q\d+",t): raise Rechazo("No llames límite a un identificador Q. Omití ese código y explicá solamente la exclusión de alcance.")
    if "prioridad" in f and not ("prioridad" in t and "auxiliar" in t):
        raise Rechazo("Conservá que se trata de una prioridad auxiliar de revisión.")
    if "prioridad" in f:
        for nivel in ["alta","media","baja"]:
            if re.search(r"\b"+nivel+r"\b",t) and not re.search(r"\b"+nivel+r"\b",f): raise Rechazo("No cambies el nivel de prioridad.")
        if "ingesta" in t: raise Rechazo("Esta evidencia describe prioridad, no una categoría de ingesta.")


def resolver(texto):
    inicio=time.monotonic()
    a={"recorrido_id":str(uuid4()),"fecha_utc":datetime.now(timezone.utc).isoformat(),"entrada":texto,
       "modelo":os.getenv("OLLAMA_MODEL","qwen3:1.7b"),"consultas":[],
       "codigo_sha256":hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
       "prompt_sha256":{"extraccion":hashlib.sha256(EXTRACCION.encode()).hexdigest(),"explicacion":hashlib.sha256(EXPLICACION.encode()).hexdigest()}}
    try:
        if not texto.strip() or len(texto)>1500: raise Rechazo("Ingresá una consulta de entre 1 y 1500 caracteres.")
        bruto,meta=llamar_llm(EXTRACCION,texto,SCHEMA)
        a.update(extraccion_bruta=bruto,metrica_extraccion=meta)
        obj=json_estricto(bruto); a["extraccion"]=obj; validar_extraccion(obj,texto)
        c=recuperar(obj,a); a["contexto"]=c
        a["H1_resultados_neo4j"]=huella_json(a["consultas"])
        ruta,fuente,regla=elegir_evidencia(a,obj["intencion"])
        a["evidencia_seleccionada"]={"ruta_en_consultas":ruta,"texto":fuente,"regla":regla}
        entrada=json.dumps({"evidencia":fuente},ensure_ascii=False)
        historial=[]
        a["intentos_explicacion"]=[]
        aceptada=None
        for _ in range(3):
            enviado=json.dumps([{"role":"user","content":entrada}]+historial,ensure_ascii=False)
            bruto,meta=llamar_llm(EXPLICACION,entrada,SCHEMA_REDACCION,historial)
            intento={"entrada_exacta":enviado,"H2_entrada":hashlib.sha256(enviado.encode()).hexdigest(),"salida":bruto,"metricas":meta}
            a["intentos_explicacion"].append(intento)
            try:
                exp=json_estricto(bruto); verificar_redaccion(exp,fuente); aceptada=exp["explicacion"]; break
            except (Rechazo,ValidationError,json.JSONDecodeError) as ex:
                intento["rechazo"]=str(ex)[:400]
                historial += [{"role":"assistant","content":bruto},{"role":"user","content":"Tu respuesta fue rechazada: "+str(ex)[:400]+" Reescribí únicamente la evidencia original, sin mencionar esta corrección."}]
        a["resultado"]="EXITO" if aceptada else "INCOMPLETO_EXPLICACION"
        a["explicacion"]={"texto":aceptada or fuente,"origen":"LLM" if aceptada else "CITA_LITERAL_GRAFO","regla":regla}
        partes=[datos_exactos(c),conclusion(c),"Explicación ["+regla+"]: "+a["explicacion"]["texto"]]
        if c.get("situacion_interna")=="PENDIENTE_VALIDACION":
            partes.append("Falta validar el criterio experto; esto no equivale a pedir más datos al paciente.")
        if c.get("prioridad_revision_ca") is not None:
            partes.append("La prioridad es auxiliar y provisional; no representa riesgo clínico, probabilidad ni un estado nutricional.")
        pedidos=[d["texto"] for d in c.get("datos_faltantes",[])]
        pedidos += [d["pedido"] for d in c.get("detalle",{}).get("faltantes",[])]
        for pedido in dict.fromkeys(pedidos): partes.append("Dato solicitado por el grafo: "+pedido.strip())
        for adv in c.get("advertencias",[]): partes.append("Advertencia ["+adv["regla"]+"]: "+adv["texto"])
        if c.get("accion_admisibilidad") not in (None,"NINGUNA"):
            partes.append("Acción de admisibilidad recuperada: "+c["accion_admisibilidad"])
        partes.append("Alcance: evaluación dietaria del registro; no es diagnóstico ni prescripción.")
        if not aceptada: partes.append("La explicación del LLM fue rechazada. Se muestra la evidencia literal; la integración no se considera exitosa.")
        a["respuesta"]="\n\n".join(partes)
        if huella_json(a["consultas"])!=a["H1_resultados_neo4j"]: raise Rechazo("Se alteró el registro de recuperación.")
    except (Rechazo,ValidationError,json.JSONDecodeError) as ex:
        a.update(resultado="ACLARACION_O_BLOQUEO",motivo_tecnico=str(ex)[:600],respuesta=str(ex) if isinstance(ex,Rechazo) else "El modelo no devolvió el formato requerido; reformulá la consulta.")
    except Exception as ex:
        a.update(resultado="ERROR_SERVICIO",tipo_error=type(ex).__name__,respuesta="No se pudo completar la consulta; verificá Neo4j y Ollama.")
    a["duracion_segundos"]=round(time.monotonic()-inicio,3)
    return a


def mostrar(a, completo=True):
    print("RECORRIDO:", a.get("recorrido_id", "sin ID"), flush=True)
    print("\nUSUARIO:", a["entrada"], flush=True)
    print("EXTRACCION:", json.dumps(a.get("extraccion"), ensure_ascii=False), flush=True)
    for q in a["consultas"]:
        print("\nCYPHER", q["consulta_id"], "| parámetros:", json.dumps(q["parametros"], ensure_ascii=False))
        if completo:
            print(q["cypher"])
            print("RESULTADO NEO4J:", json.dumps(q["filas"], ensure_ascii=False))
        elif q["consulta_id"] == "resumen" and q["filas"]:
            c = q["filas"][0]["contexto"]
            claves = ["paciente", "estado", "situacion_interna", "ingesta_alcance", "prioridad_revision_ca"]
            print("RESULTADO NEO4J (resumen):", json.dumps({k: c.get(k) for k in claves}, ensure_ascii=False))
    print("\nRESPUESTA:\n" + a["respuesta"])
    print("RESULTADO:", a["resultado"], "| Duración:", a["duracion_segundos"], "s", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--consulta")
    parser.add_argument("--salida", type=Path, help="Archivo JSONL de auditoría (sin credenciales)")
    parser.add_argument("--compacto", action="store_true")
    args = parser.parse_args()
    while True:
        try:
            texto = args.consulta or input("\nConsulta de calcio (salir para terminar): ")
        except (EOFError, KeyboardInterrupt):
            break
        if texto.strip().lower() == "salir":
            break
        a = resolver(texto)
        mostrar(a, not args.compacto)
        if args.salida:
            args.salida.parent.mkdir(parents=True, exist_ok=True)
            with args.salida.open("a", encoding="utf-8") as f:
                f.write(json.dumps(a, ensure_ascii=False) + "\n")
        if args.consulta:
            return 0 if a["resultado"] == "EXITO" else 2
    return 0


if __name__ == "__main__":
    sys.exit(main())

