MATCH (p:Paciente {id:$pid})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'VD'})
OPTIONAL MATCH (p)-[:SIGUE]->(pa:PatronAlimentario)
OPTIONAL MATCH (p)-[:TIENE_HABITO_DE]->(x:ExposicionSolar)
CALL (e) {
  MATCH (e)-[:REGISTRA]->(t:PasoTraza)
  OPTIONAL MATCH (t)-[:APLICA_REGLA]->(r:Regla)
  OPTIONAL MATCH (r)-[:VALIDADA_CON]->(q:PreguntaExperta)
  OPTIONAL MATCH (t)-[:SE_APOYA_EN]->(ev)
  WITH t, q, collect(DISTINCT coalesce(ev.relato, ev.nombre, ev.codigo, ev.id)) AS evid
  ORDER BY t.orden, t.regla
  RETURN collect({regla:t.regla, efecto:t.efecto, estado_propuesto:t.estado_propuesto, texto:t.texto, evidencia:evid,
                  respaldo_experta:CASE WHEN q IS NULL THEN null ELSE q.id + ': ' + q.texto END}) AS traza }
CALL (e) { OPTIONAL MATCH (e)-[pe:PERTENECE]->(t:TerminoDifuso)<-[:TIENE_TERMINO]-(v:VariableDifusa)
       WITH v, t, pe ORDER BY v.id, t.centro
       RETURN collect(CASE WHEN t IS NULL THEN null ELSE v.nombre + ' ES ' + t.etiqueta + ' (μ = ' + toString(pe.mu) + ')' END) AS pertenencias }
CALL (e) { OPTIONAL MATCH (e)-[pe:PERTENECE]->(t:TerminoDifuso)<-[:TIENE_TERMINO]-(v:VariableDifusa)
       WITH v, t, pe ORDER BY pe.mu DESC
       WITH v, collect(t.etiqueta)[0] AS dom
       RETURN collect(CASE WHEN v IS NULL THEN null ELSE [v.id, dom] END) AS dominantes }
CALL (e) { OPTIONAL MATCH (e)-[:GENERA]->(a:Advertencia) RETURN collect(a.regla + ': ' + a.texto) AS advertencias }
CALL (e) { OPTIONAL MATCH (e)-[:GENERA]->(d:DatoFaltante)
       RETURN collect(CASE WHEN d IS NULL THEN null ELSE {pedido:d.texto, regla:d.regla, pregunta_experta:d.pregunta} END) AS datos_faltantes }
CALL (e) { OPTIONAL MATCH (e)-[:INTERRUMPIDA_POR]->(c) OPTIONAL MATCH (e)-[:SE_DERIVA_A]->(m)
       RETURN collect(DISTINCT c.nombre) AS condiciones_derivacion, collect(DISTINCT [l IN labels(m) WHERE l <> 'Usuario'][0]) AS se_deriva_a }
CALL (e) { OPTIONAL MATCH (cc:CriterioCandidato)
       WHERE (e.capa_difusa_estado = 'EJECUTADA' AND cc.nombre IN ['PARAM_FZ_VD','PARAM_INDICE_UVB_VD','POLITICA_CORTES_SALIDA','POLITICA_ZONA_MODERADA'])
          OR (size(e.estados_propuestos) > 1 AND cc.nombre = 'POLITICA_META_01')
       RETURN collect(cc.nombre + ' (' + cc.estado_validacion + ')') AS criterios_no_validados_usados }
RETURN {paciente:p.id, edad:p.edad, patron:pa.codigo, nutriente:'Vitamina D',
        estado:e.estado, situacion_interna:e.situacion_interna, regla_estado:e.regla_estado,
        etiqueta_aporte:[d IN dominantes WHERE d[0] = 'V-VD-APO' | d[1]][0], etiqueta_exposicion:[d IN dominantes WHERE d[0] = 'V-VD-EXP' | d[1]][0],
        aporte_oral:{ingesta_dietaria:e.ingesta_dietaria, aporte_suplementos:e.aporte_suplementos, ingesta_estimada:e.ingesta_estimada,
                     aporte_relativo:e.aporte_relativo, valor_referencia:e.valor_referencia, unidad:'µg/día'},
        exposicion:{estado:e.exposicion_estado, indice_E:e.exposicion_uvb, mes_consulta:e.mes_consulta, indice_uv_mes:e.iuv_mes,
                    horas_semana:x.tiempo_aire_libre_h, horario:x.horario_exposicion, vestimenta:x.cobertura_vestimenta, protector:x.protector_solar, fototipo:x.fototipo},
        riesgo_difuso:e.riesgo_difuso, etiqueta_riesgo:e.etiqueta_riesgo, componente_limitante:e.componente_limitante,
        riesgo_invierno:e.riesgo_invierno, etiqueta_invierno:e.etiqueta_invierno, resultado_provisional:e.resultado_provisional,
        fuente_verificada:e.fuente_verificada, tipo_fuente_verificada:e.tipo_fuente_verificada,
        pertenencias:pertenencias, condiciones_derivacion:condiciones_derivacion, se_deriva_a:se_deriva_a,
        traza:traza, advertencias:advertencias, datos_faltantes:datos_faltantes,
        criterios_no_validados_usados:criterios_no_validados_usados} AS contexto