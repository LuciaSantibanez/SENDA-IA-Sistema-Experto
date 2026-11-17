MATCH (:Paciente {id:$paciente})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:$nutriente})
OPTIONAL MATCH (e)-[a:ACTIVA]->(r:ReglaDifusa)
RETURN e.riesgo_difuso AS indice, e.etiqueta_riesgo AS etiqueta, e.prioridad_revision_ca AS prioridad_ca,
       collect(r{.id, alfa:a.alfa}) AS activaciones
