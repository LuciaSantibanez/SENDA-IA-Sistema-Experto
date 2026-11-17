MATCH (:Paciente {id:$paciente})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:$nutriente})
OPTIONAL MATCH (e)-[:USA_MODELO]->(m:ModeloDifuso)
OPTIONAL MATCH (e)-[en:ENTRADA]->(v:VariableDifusa)
WITH e,m,collect(v{.id,.nombre,.unidad,valor:en.valor}) AS entradas
OPTIONAL MATCH (e)-[ac:ACTIVA]->(r:ReglaDifusa)
WITH e,m,entradas,r,ac ORDER BY ac.alfa DESC,r.id
RETURN m.id AS modelo,m.estado_validacion AS validacion_modelo,
 e.capa_difusa_estado AS ejecucion,e.prioridad_revision_ca AS prioridad,
 e.etiqueta_prioridad AS etiqueta,e.resultado_provisional AS provisional,
 entradas,collect(r{.id,alfa:ac.alfa}) AS activaciones
