MATCH (p:Paciente {id:$paciente})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)-[:EVALUA]->(n:Nutriente {codigo:$nutriente})
OPTIONAL MATCH (p)-[:TIENE_EVALUACION]->(a:EvaluacionAdmisibilidad)
OPTIONAL MATCH (e)-[:REGISTRA]->(t:PasoTraza)
WITH p,e,n,a,t ORDER BY t.orden,t.regla,t.texto
WITH p,e,n,a,collect(t{.regla,.texto,.efecto,.estado_propuesto}) AS traza
OPTIONAL MATCH (e)-[:GENERA]->(adv:Advertencia)
WITH p,e,n,a,traza,collect(DISTINCT adv{.regla,.texto}) AS advertencias
OPTIONAL MATCH (e)-[:GENERA]->(df:DatoFaltante)
WITH p,e,n,a,traza,advertencias,collect(DISTINCT df{.clave,.texto,.regla,.pregunta}) AS faltantes
OPTIONAL MATCH (a)-[:REGISTRA]->(ta:PasoTraza)
WITH p,e,n,a,traza,advertencias,faltantes,ta ORDER BY ta.orden,ta.regla
WITH p,e,n,a,traza,advertencias,faltantes,collect(ta{.regla,.texto,.efecto}) AS traza_admisibilidad
RETURN {paciente:p.id,nutriente:n.codigo,estado:coalesce(e.estado,e.situacion_interna),estado_concluido:e.estado,situacion_interna:e.situacion_interna,
 fundamento:e.fundamento,ingesta_estimada:e.ingesta_estimada,ingesta_alcance:e.ingesta_alcance,
 ingesta_relativa:e.ingesta_relativa,referencia:e.valor_referencia,unidad:e.unidad,
 prioridad_revision_ca:e.prioridad_revision_ca,etiqueta_prioridad:e.etiqueta_prioridad,
 resultado_provisional:e.resultado_provisional,capa_difusa_estado:e.capa_difusa_estado,
 admisibilidad:a.veredicto,accion_admisibilidad:a.accion,traza:traza,
 traza_admisibilidad:traza_admisibilidad,advertencias:advertencias,datos_faltantes:faltantes} AS contexto

