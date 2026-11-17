MATCH (p:Paciente {id:$paciente})-[:TIENE_EVALUACION]->(e)
WHERE (e:EvaluacionNutriente AND e.nutriente=$nutriente) OR e:EvaluacionAdmisibilidad
MATCH (e)-[:GENERA]->(d:DatoFaltante)
OPTIONAL MATCH (d)-[:SIRVE_A]->(n:Nutriente)
RETURN d.clave AS clave,d.texto AS pedido,d.regla AS regla,d.pregunta AS pregunta_experta,
 collect(DISTINCT n.codigo) AS nutrientes_beneficiados
ORDER BY clave,pedido
