MATCH (p:Paciente {id:$pid})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12'})
OPTIONAL MATCH (p)-[:SIGUE]->(pa:PatronAlimentario)
CALL (e) {
  MATCH (e)-[:REGISTRA]->(t:PasoTraza)
  OPTIONAL MATCH (t)-[:APLICA_REGLA]->(r:Regla)
  OPTIONAL MATCH (r)-[:VALIDADA_CON]->(q:PreguntaExperta)
  OPTIONAL MATCH (t)-[:SE_APOYA_EN]->(ev)
  WITH t, r, q, collect(DISTINCT coalesce(ev.relato, ev.nombre, ev.codigo, ev.id)) AS evid
  ORDER BY t.orden, t.regla
  RETURN collect({regla:t.regla, efecto:t.efecto, estado_propuesto:t.estado_propuesto, texto:t.texto,
                  evidencia:evid, respaldo:CASE WHEN q IS NULL THEN null ELSE q.id + ': ' + q.texto END}) AS traza }
CALL (e) { OPTIONAL MATCH (e)-[:GENERA]->(a:Advertencia) RETURN collect(a.regla + ': ' + a.texto) AS advertencias }
CALL (e) { OPTIONAL MATCH (e)-[:GENERA]->(d:DatoFaltante)
       RETURN collect(CASE WHEN d IS NULL THEN null ELSE {pedido:d.texto, regla:d.regla, pregunta_experta:d.pregunta} END) AS datos_faltantes }
CALL (e) { OPTIONAL MATCH (e)-[:INTERRUMPIDA_POR]->(c) OPTIONAL MATCH (e)-[:SE_DERIVA_A]->(m)
       RETURN collect(DISTINCT c.nombre) AS condiciones_derivacion, collect(DISTINCT [l IN labels(m) WHERE l <> 'Usuario'][0]) AS se_deriva_a }
CALL (e) { OPTIONAL MATCH (cc:CriterioCandidato)
       WHERE (e.capa_difusa_estado = 'EJECUTADA' AND cc.nombre IN ['PARAM_FZ_B12','POLITICA_CORTES_SALIDA','POLITICA_ZONA_MODERADA'])
          OR (size(e.estados_propuestos) > 1 AND cc.nombre = 'POLITICA_META_01')
       RETURN collect(cc.nombre + ' (' + cc.estado_validacion + ')') AS criterios_no_validados_usados }
RETURN {paciente:p.id, edad:p.edad, patron:pa.codigo, nutriente:'Vitamina B12',
        estado:e.estado, situacion_interna:e.situacion_interna, regla_estado:e.regla_estado,
        ingesta_estimada:e.ingesta_estimada, ingesta_relativa:e.ingesta_relativa, valor_referencia:e.valor_referencia,
        unidad:'µg/día', aporte_suplementos:e.aporte_suplementos, adherencia_suplemento:e.adherencia_suplemento,
        riesgo_difuso:e.riesgo_difuso, etiqueta_riesgo:e.etiqueta_riesgo, resultado_provisional:e.resultado_provisional,
        componente_limitante:e.componente_limitante, motivo_fuera_alcance:e.motivo_fuera_alcance,
        condiciones_derivacion:condiciones_derivacion, se_deriva_a:se_deriva_a,
        traza:traza, advertencias:advertencias, datos_faltantes:datos_faltantes,
        criterios_no_validados_usados:criterios_no_validados_usados} AS contexto