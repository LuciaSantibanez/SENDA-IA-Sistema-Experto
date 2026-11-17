
// =============================================================================
// 05 · CONSULTAS SOBRE LA BASE DE CONOCIMIENTO (solo lectura)
// =============================================================================
// Para la captura del esquema en Neo4j Browser:   CALL db.schema.visualization();
// En Neo4j Bloom: perspectiva generada automáticamente sobre todas las etiquetas.

// ------------------------------------------------------------------ IQ · Consultas de inferencia (sección d del informe)

// IQ1 (inferencia crisp, cruza SM-CA, SM-B12 y SM-VD)
// «¿Qué rótulo hay que pedirle a cada paciente para destrabar a la vez varios nutrientes, y qué estado queda mientras tanto?»
MATCH (p:Paciente)-[:REGISTRA]->(cs:Consumo)-[:DE]->(a:Alimento:Fortificado)-[d:DECLARA {valor:'DESCONOCIDO'}]->(n:Nutriente)
MATCH (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)-[:EVALUA]->(n)
WHERE e.fuente_verificada <> 'SI'
WITH p, a, collect(n.codigo) AS nutrientes_bloqueados, collect(e.estado) AS estados
MERGE (df:DatoFaltante {clave: p.id + '|' + a.id})
RETURN p.id AS paciente, a.nombre AS producto, nutrientes_bloqueados, estados,
       df.texto AS pedido_unico, size(nutrientes_bloqueados) AS nutrientes_que_destraba
ORDER BY nutrientes_que_destraba DESC;

// IQ2 (fuzzificación e inferencia Mamdani calculadas en Cypher desde los datos crudos)
// «¿Qué tan compatible es el patrón de hierro de cada paciente con una ingesta insuficiente?»
// Entradas: porciones/semana de grupos FUENTE_DE hierro no hemo; comidas/semana con inhibidor coincidente (FE-02)
// más tomas de calcio con las comidas (FE-11). Parámetros leídos de los :TerminoDifuso.
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(:EvaluacionNutriente {nutriente:'FE', capa_difusa_estado:'EJECUTADA'})
OPTIONAL MATCH (p)-[:REGISTRA]->(cs:Consumo)-[:DE]->(:Alimento)-[:PERTENECE_A]->(:GrupoAlimento)-[:FUENTE_DE {forma:'NO_HEMO'}]->(:Nutriente {codigo:'FE'})
WITH p, sum(coalesce(cs.frecuencia_semanal, 0.0)) AS x_noh
OPTIONAL MATCH (p)-[:REGISTRA]->(ci:Consumo)-[:DE]->(:Alimento)-[:CONTIENE_FACTOR]->(:Inhibidor), (ci)-[o:OCURRE_EN]->(cm:Comida)
WHERE o.coincide_con_comida = 'SI' AND cm.principal = true
WITH p, x_noh, sum(coalesce(o.veces_semana, 0.0)) AS inh_alimentos
OPTIONAL MATCH (p)-[tm:TOMA]->(:Suplemento)-[:CONTIENE]->(:Nutriente {codigo:'CA'})
WHERE tm.momento_toma = 'CON_COMIDAS'
WITH p, x_noh, inh_alimentos, sum(coalesce(tm.tomas_realizadas_28d, 0) / 4.0) AS inh_suplementos
WITH p, x_noh, inh_alimentos + inh_suplementos AS x_inh
MATCH (:VariableDifusa {id:'V-FE-NOH'})-[:TIENE_TERMINO]->(tn:TerminoDifuso)
WITH p, x_noh, x_inh, collect({e: tn.etiqueta, mu: CASE WHEN tn.tipo_funcion = 'HOMBRO_IZQ' AND x_noh <= tn.centro THEN 1.0
                                                          WHEN tn.tipo_funcion = 'HOMBRO_DER' AND x_noh >= tn.centro THEN 1.0
                                                          ELSE exp(-1.0 * (x_noh - tn.centro)^2 / (2.0 * tn.sigma^2)) END}) AS mu_noh
MATCH (:VariableDifusa {id:'V-FE-INH'})-[:TIENE_TERMINO]->(ti:TerminoDifuso)
WITH p, x_noh, x_inh, mu_noh, collect({e: ti.etiqueta, mu: CASE WHEN ti.tipo_funcion = 'HOMBRO_IZQ' AND x_inh <= ti.centro THEN 1.0
                                                                 WHEN ti.tipo_funcion = 'HOMBRO_DER' AND x_inh >= ti.centro THEN 1.0
                                                                 ELSE exp(-1.0 * (x_inh - ti.centro)^2 / (2.0 * ti.sigma^2)) END}) AS mu_inh
WITH p, x_noh, x_inh,
     [m IN mu_noh WHERE m.e = 'bajo' | m.mu][0] AS c_bajo, [m IN mu_noh WHERE m.e = 'medio' | m.mu][0] AS c_medio, [m IN mu_noh WHERE m.e = 'alto' | m.mu][0] AS c_alto,
     [m IN mu_inh WHERE m.e = 'bajo' | m.mu][0] AS i_bajo, [m IN mu_inh WHERE m.e = 'moderado' | m.mu][0] AS i_mod, [m IN mu_inh WHERE m.e = 'frecuente' | m.mu][0] AS i_frec
// Reglas FE-F01 a FE-F06: AND = MIN, OR = MAX
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec,
     CASE WHEN c_bajo < i_frec THEN c_bajo ELSE i_frec END AS a1,
     CASE WHEN c_bajo < (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) THEN c_bajo ELSE (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) END AS a2,
     CASE WHEN c_medio < i_frec THEN c_medio ELSE i_frec END AS a3,
     CASE WHEN c_medio < (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) THEN c_medio ELSE (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) END AS a4,
     CASE WHEN c_alto < (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) THEN c_alto ELSE (CASE WHEN i_bajo > i_mod THEN i_bajo ELSE i_mod END) END AS a5,
     CASE WHEN c_alto < i_frec THEN c_alto ELSE i_frec END AS a6
// Agregación por consecuente: alto = a1; moderado = MAX(a2, a3, a6); bajo = MAX(a4, a5)
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec, a1, a2, a3, a4, a5, a6,
     a1 AS h_alto, reduce(m = 0.0, v IN [a2, a3, a6] | CASE WHEN v > m THEN v ELSE m END) AS h_mod,
     CASE WHEN a4 > a5 THEN a4 ELSE a5 END AS h_bajo
MATCH (:VariableDifusa {id:'V-RIESGO'})-[:TIENE_TERMINO]->(to:TerminoDifuso)
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec, a1, a2, a3, a4, a5, a6, h_alto, h_mod, h_bajo,
     collect({c: to.centro, s: to.sigma, h: CASE to.etiqueta WHEN 'alto' THEN h_alto WHEN 'moderado' THEN h_mod ELSE h_bajo END}) AS salida
UNWIND range(0, 1000) AS i
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec, a1, a2, a3, a4, a5, a6, salida, i / 10.0 AS z
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec, a1, a2, a3, a4, a5, a6, z,
     reduce(m = 0.0, k IN salida | CASE WHEN (CASE WHEN k.h < exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) THEN k.h ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END) > m
                                          THEN (CASE WHEN k.h < exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) THEN k.h ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END) ELSE m END) AS mu_z
WITH p, x_noh, x_inh, c_bajo, c_medio, c_alto, i_bajo, i_mod, i_frec, a1, a2, a3, a4, a5, a6, sum(z * mu_z) / sum(mu_z) AS z_star
RETURN p.id AS paciente, x_noh AS porciones_no_hemo_sem, x_inh AS comidas_con_inhibidor_sem,
       round(c_bajo * 1000) / 1000.0 AS mu_consumo_bajo, round(c_medio * 1000) / 1000.0 AS mu_consumo_medio,
       round(i_mod * 1000) / 1000.0 AS mu_inhib_moderado, round(i_frec * 1000) / 1000.0 AS mu_inhib_frecuente,
       [round(a1 * 1000) / 1000.0, round(a2 * 1000) / 1000.0, round(a3 * 1000) / 1000.0, round(a4 * 1000) / 1000.0, round(a5 * 1000) / 1000.0, round(a6 * 1000) / 1000.0] AS alfas_F01_a_F06,
       round(z_star * 100) / 100.0 AS riesgo_fe,
       CASE WHEN z_star < 33.5 THEN 'BAJO' WHEN z_star > 66.5 THEN 'ALTO' ELSE 'MODERADO' END AS etiqueta
ORDER BY riesgo_fe DESC;

// IQ3 (inferencia cruzada entre submódulos)
// «Para cada suplemento que toma un paciente: ¿qué nutrientes verifica, a qué otros submódulos afecta y cómo?»
MATCH (p:Paciente)-[tm:TOMA]->(s:Suplemento)-[ct:CONTIENE]->(n:Nutriente)<-[:EVALUA]-(e:EvaluacionNutriente)<-[:TIENE_EVALUACION]-(p)
OPTIONAL MATCH (n)-[inh:INHIBE_ABSORCION]->(n2:Nutriente)<-[:EVALUA]-(e2:EvaluacionNutriente)<-[:TIENE_EVALUACION]-(p)
WHERE tm.momento_toma = 'CON_COMIDAS'
OPTIONAL MATCH (n)<-[:FAVORECE_ABSORCION]-(n3:Nutriente)<-[:CONTIENE]-(s)
OPTIONAL MATCH (p)-[:USA]->(med:Medicamento)-[:REDUCE_ABSORCION]->(n)
RETURN p.id AS paciente, s.nombre AS suplemento, n.codigo AS nutriente, ct.dosis AS dosis, ct.unidad AS unidad,
       CASE WHEN tm.frecuencia_conocida = 'SI' THEN toString(round(ct.dosis * tm.tomas_realizadas_28d / 28.0 * 100) / 100.0) ELSE 'DESCONOCIDO (G-03)' END AS aporte_diario_promedio,
       e.ingesta_relativa AS ingesta_relativa_total, coalesce(e.estado, e.situacion_interna) AS estado_del_nutriente,
       CASE WHEN n2 IS NULL THEN '—' ELSE 'Inhibe ' + n2.codigo + ' no hemo (FE-11) → ' + coalesce(e2.estado, e2.situacion_interna) END AS efecto_cruzado,
       CASE WHEN n3 IS NULL THEN '—' ELSE n3.codigo + ' del mismo producto favorece su absorción' END AS sinergia,
       CASE WHEN med IS NULL THEN '—' ELSE med.nombre + ' reduce su absorción (G-11)' END AS medicacion
ORDER BY paciente, nutriente;

// ------------------------------------------------------------------ C · Consultas mínimas pedidas (Paso 5)

// C1 · Conceptos relacionados: «¿Con qué conceptos está conectada la vitamina B12 y por qué relación?»
MATCH (n:Nutriente {codigo:'B12'})-[r]-(x)
WHERE NOT x:EvaluacionNutriente AND NOT x:DatoFaltante
RETURN type(r) AS relacion, labels(x)[0] AS tipo, collect(DISTINCT coalesce(x.nombre, x.codigo, x.id)) AS conceptos
ORDER BY relacion;

// C2 · Recorrido entre entidades: «¿De qué alimentos registrados obtiene cada nutriente la paciente P03 y por qué vía?»
MATCH (p:Paciente {id:'P03'})-[:REGISTRA]->(cs:Consumo)-[:DE]->(a:Alimento)-[r:APORTA|DECLARA]->(n:Nutriente)
WHERE type(r) = 'APORTA' OR r.valor = 'SI'
RETURN n.codigo AS nutriente, a.nombre AS alimento, cs.frecuencia_semanal AS porciones_semana,
       CASE type(r) WHEN 'APORTA' THEN 'contenido natural' ELSE 'rótulo (fortificado)' END AS via,
       round(cs.frecuencia_semanal / 7.0 * coalesce(r.cantidad, r.contenido) * 100) / 100.0 AS aporte_diario
ORDER BY nutriente, aporte_diario DESC;

// C3 · Herencia en la red semántica: «¿Qué grupos excluye y qué fuentes alternativas exige cada patrón, incluyendo lo heredado?»
MATCH (pa:PatronAlimentario) WHERE pa.codigo <> 'PATRON'
OPTIONAL MATCH (pa)-[:ES_UN*0..3]->(sup:PatronAlimentario)-[:EXCLUYE]->(g:GrupoAlimento)
OPTIONAL MATCH (pa)-[:ES_UN*0..3]->(sup2:PatronAlimentario)-[:REQUIERE_FUENTE_ALTERNATIVA]->(n:Nutriente)
RETURN pa.codigo AS patron, collect(DISTINCT g.codigo) AS excluye, collect(DISTINCT n.codigo) AS requiere_fuente_alternativa
ORDER BY patron;

// C4 · Evidencias de una conclusión: «¿Qué reglas, hechos y documentos sostienen el estado de hierro de P01?»
MATCH (e:EvaluacionNutriente {id:'P01-FE'})-[:REGISTRA]->(t:PasoTraza)-[:APLICA_REGLA]->(r)
OPTIONAL MATCH (t)-[:SE_APOYA_EN]->(ev)
OPTIONAL MATCH (r)-[:RESPALDADA_POR]->(doc:FuenteConocimiento)
OPTIONAL MATCH (r)-[:VALIDADA_CON]->(q:PreguntaExperta)
RETURN t.orden AS orden, t.regla AS regla, t.efecto AS efecto, coalesce(t.estado_propuesto, '') AS propone, t.texto AS razonamiento,
       collect(DISTINCT coalesce(ev.atributo + '=' + ev.valor, ev.relato, ev.nombre, ev.momento, ev.id)) AS evidencias,
       collect(DISTINCT doc.id) AS documentos, collect(DISTINCT q.id) AS preguntas_experta
ORDER BY orden;

// C5 · Información de distintos submódulos: «¿Cuál es el resultado consolidado de cada paciente?»
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
MATCH (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
WITH p, ea, e ORDER BY e.nutriente
WITH p, ea, collect(e.nutriente + '=' + coalesce(e.estado, e.situacion_interna)) AS estados
OPTIONAL MATCH (p)-[:TIENE_RESULTADO]->(:ResultadoConsolidado)-[:PIDE]->(df:DatoFaltante)
RETURN p.id AS paciente, ea.veredicto AS admisibilidad, coalesce(ea.calidad_registro, '—') AS calidad, estados,
       collect(df.texto) AS datos_a_pedir
ORDER BY paciente;

// C6 · Dato compartido entre submódulos (META-04): «¿Qué pedido resuelve más de un submódulo?»
MATCH (df:DatoFaltante)-[:SIRVE_A]->(n:Nutriente)<-[:EVALUA]-(:Submodulo)
WITH df, collect(DISTINCT n.codigo) AS nutrientes
WHERE size(nutrientes) > 1
RETURN split(df.clave, '|')[0] AS paciente, df.texto AS pedido_unico, nutrientes, df.regla AS regla;

// C7 · Derivar ≠ fuera de alcance: «¿Por qué no se evaluó cada caso no admisible?»
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
WHERE ea.veredicto <> 'ADMISIBLE'
OPTIONAL MATCH (ea)-[:INTERRUMPIDA_POR]->(c:CondicionDerivacion)
OPTIONAL MATCH (ea)-[:EXCLUIDA_POR]->(ca:CriterioAlcance)
OPTIONAL MATCH (ea)-[:SE_DERIVA_A]->(u:Usuario)
OPTIONAL MATCH (ea)-[:GENERA]->(df:DatoFaltante)
RETURN p.id AS paciente, ea.veredicto AS veredicto, ea.accion AS accion,
       coalesce(c.nombre, ca.descripcion, df.texto) AS motivo, coalesce(u.rol, '—') AS se_deriva_a;

// C8 · Trazado difuso: «¿Por qué el riesgo de vitamina D de P05 es moderado y qué pasaría en invierno?»
MATCH (e:EvaluacionNutriente {id:'P05-VD'})-[en:ENTRADA]->(v:VariableDifusa)
WITH e, collect(v.nombre + ' = ' + toString(round(en.valor * 100) / 100.0)) AS entradas
MATCH (e)-[pe:PERTENECE]->(t:TerminoDifuso)
WHERE pe.mu > 0.01
WITH e, entradas, collect(t.id + ': μ=' + toString(round(pe.mu * 1000) / 1000.0)) AS pertenencias
MATCH (e)-[ac:ACTIVA]->(r:ReglaDifusa)
WITH e, entradas, pertenencias, r, ac ORDER BY ac.alfa DESC
WITH e, entradas, pertenencias, collect(r.id + ' α=' + toString(round(ac.alfa * 1000) / 1000.0)) AS activaciones
OPTIONAL MATCH (e)-[:PROYECTA]->(pi:ProyeccionInvernal)
RETURN e.exposicion_uvb AS indice_E, entradas, pertenencias, activaciones, e.riesgo_difuso AS riesgo, e.etiqueta_riesgo AS etiqueta,
       e.componente_limitante AS componente, pi.riesgo AS riesgo_julio, pi.etiqueta AS etiqueta_julio, e.situacion_interna AS situacion;

// C9 · Conocimiento pendiente de validación: «¿Qué parte del conocimiento no está aprobada y a qué reglas afecta?»
MATCH (c:CriterioCandidato)
WHERE c.estado_validacion <> 'VALIDADO'
OPTIONAL MATCH (x)-[:REEMPLAZA_PARAMETRO|PARAMETRIZADO_POR|UMBRAL_ALERTA|USA_CRITERIO]-(c)
OPTIONAL MATCH (c)-[:VALIDADO_CON]->(q:PreguntaExperta)
RETURN c.nombre AS criterio, c.estado_validacion AS estado, c.valor AS valor_propuesto, c.comportamiento_pendiente AS que_hace_mientras,
       collect(DISTINCT coalesce(x.id, x.codigo, x.nombre)) AS afecta_a, collect(DISTINCT q.id) AS evidencia
ORDER BY estado, criterio;

// C10 · Trazabilidad del conocimiento: «¿De qué trabajos individuales viene cada regla consolidada y cómo cambió en PG2?»
MATCH (ro:ReglaOriginal)-[:CONSOLIDADA_EN]->(r:Regla)
OPTIONAL MATCH (r)-[:VALIDADA_CON]->(q:PreguntaExperta)
WITH r, collect(DISTINCT ro.clave) AS origenes, collect(DISTINCT q.id) AS preguntas
RETURN r.id AS regla, r.estado_pg2 AS estado_pg2, size(origenes) AS cantidad_origenes, origenes, preguntas, r.cambio_pg2 AS cambio
ORDER BY cantidad_origenes DESC LIMIT 15;

// C11 · Frames: «¿Qué slots tiene F-EvaluacionNutriente y cómo se representan en Neo4j?» (y la jerarquía de frames)
MATCH (f:Frame {nombre:'F-EvaluacionNutriente'})-[:TIENE_SLOT]->(s:Slot)
RETURN f.nombre AS frame, s.nombre AS slot, s.tipo AS tipo, s.representacion AS representacion, s.faceta AS faceta;
MATCH ruta = (f:Frame)-[:ES_UN*1..3]->(raiz:Frame)
WITH ruta, size([(raiz)-[:ES_UN]->(x) | x]) AS padres
WHERE padres = 0
RETURN [x IN nodes(ruta) | x.nombre] AS jerarquia;

// C12 · Inventario del esquema (complementa CALL db.schema.visualization())
MATCH (n) WITH labels(n)[0] AS etiqueta, count(*) AS nodos RETURN etiqueta, nodos ORDER BY nodos DESC;
MATCH ()-[r]->() WITH type(r) AS relacion, count(*) AS cantidad RETURN relacion, cantidad ORDER BY cantidad DESC;

// ------------------------------------------------------------------ L · Consultas para el LLM (PI4)
// En el servicio, 'P01' se reemplaza por el parámetro $id_paciente.

// L1 · Contexto de explicación por nutriente (salida JSON para el LLM de salida)
WITH 'P01' AS id_paciente
MATCH (p:Paciente {id: id_paciente})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)-[:EVALUA]->(n:Nutriente)
OPTIONAL MATCH (e)-[:REGISTRA]->(t:PasoTraza)
WITH p, e, n, t ORDER BY t.orden
WITH p, e, n, collect(t.regla + ': ' + t.texto) AS traza
OPTIONAL MATCH (e)-[:GENERA]->(adv:Advertencia)
WITH p, e, n, traza, collect(DISTINCT adv.texto) AS advertencias
OPTIONAL MATCH (e)-[:GENERA]->(df:DatoFaltante)
WITH p, e, n, traza, advertencias, collect(DISTINCT df.texto) AS datos_faltantes
RETURN {paciente: p.id, nutriente: n.nombre, estado: e.estado, situacion_interna: e.situacion_interna,
        fundamento: e.fundamento, ingesta_relativa: e.ingesta_relativa, referencia: e.valor_referencia, unidad: e.unidad,
        riesgo_difuso: e.riesgo_difuso, etiqueta_riesgo: e.etiqueta_riesgo, resultado_provisional: e.resultado_provisional,
        componente_limitante: e.componente_limitante, traza: traza, advertencias: advertencias,
        datos_faltantes: datos_faltantes,
        restricciones_redaccion: ['No diagnosticar ni nombrar enfermedades', 'No prescribir dosis ni suplementos',
                                  'No recomendar tomar más sol ni retirar el protector', 'Usar solo hechos y reglas activados']} AS contexto
ORDER BY n.codigo;

// L2 · Hechos de entrada que el LLM extrajo con baja confianza (revisión antes de razonar; no es grado difuso)
MATCH (p:Paciente)-[:TIENE_HECHO]->(h:Hecho), (c:CriterioCandidato {nombre:'PARAM_CONFIANZA_EXTRACCION'})
WHERE h.fuente = 'LLM_ENTRADA'
RETURN p.id AS paciente, h.atributo AS atributo, h.valor AS valor, h.texto_original AS texto, h.confianza_extraccion AS confianza,
       CASE WHEN h.confianza_extraccion < toFloat(c.valor) THEN 'REVISAR_ANTES_DE_RAZONAR' ELSE 'ACEPTADO' END AS accion;

// L3 · Lista única de datos a pedir (META-04) para el mensaje al paciente
WITH 'P01' AS id_paciente
MATCH (:Paciente {id: id_paciente})-[:TIENE_RESULTADO]->(:ResultadoConsolidado)-[:PIDE]->(df:DatoFaltante)
RETURN df.texto AS pedido, df.nutrientes AS sirve_a, df.regla AS regla, df.pregunta AS respaldo_experta;
