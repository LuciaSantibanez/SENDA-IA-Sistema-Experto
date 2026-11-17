MATCH (:Paciente {id:$paciente})-[:TIENE_EVALUACION]->(e)
WHERE (e:EvaluacionNutriente AND e.nutriente=$nutriente) OR e:EvaluacionAdmisibilidad
MATCH (e)-[:REGISTRA]->(t:PasoTraza)
OPTIONAL MATCH (t)-[:APLICA_REGLA]->(r)
OPTIONAL MATCH (t)-[:SE_APOYA_EN]->(ev)
OPTIONAL MATCH (r)-[:RESPALDADA_POR]->(f:FuenteConocimiento)
OPTIONAL MATCH (r)-[:VALIDADA_CON]->(q:PreguntaExperta)
RETURN e.id AS evaluacion,t.orden AS orden,t.regla AS regla,t.texto AS razonamiento,
 t.efecto AS efecto,t.estado_propuesto AS estado_propuesto,
 collect(DISTINCT ev{.id,.atributo,.valor,.relato,.nombre}) AS evidencias,
 collect(DISTINCT f.id) AS fuentes,collect(DISTINCT q.id) AS preguntas_experta
ORDER BY evaluacion,orden,regla,razonamiento
