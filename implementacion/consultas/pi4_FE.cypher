MATCH (p:Paciente {id: $paciente})-[:TIENE_EVALUACION]->
      (e:EvaluacionNutriente)-[:EVALUA]->(n:Nutriente {codigo: 'FE'})
OPTIONAL MATCH (e)-[:REGISTRA]->(t:PasoTraza)
WITH p, e, n, t ORDER BY t.orden, t.regla
WITH p, e, n,
     [x IN collect(CASE WHEN t IS NULL THEN null ELSE {
         orden: t.orden, regla: t.regla, efecto: t.efecto,
         estado_propuesto: t.estado_propuesto, grado: t.grado,
         razonamiento: t.texto
     } END) WHERE x IS NOT NULL] AS trazas
OPTIONAL MATCH (e)-[:GENERA]->(adv:Advertencia)
WITH p, e, n, trazas,
     [x IN collect(DISTINCT adv.texto) WHERE x IS NOT NULL] AS advertencias
OPTIONAL MATCH (e)-[:GENERA]->(df:DatoFaltante)
WITH p, e, n, trazas, advertencias,
     [x IN collect(DISTINCT df.texto) WHERE x IS NOT NULL] AS faltantes_fe
OPTIONAL MATCH (p)-[:TIENE_EVALUACION]->(:EvaluacionAdmisibilidad)-[:GENERA]->(dfa:DatoFaltante)
WITH p, e, n, trazas, advertencias, faltantes_fe,
     [x IN collect(DISTINCT dfa.texto) WHERE x IS NOT NULL] AS faltantes_adm
WITH p, e, n, trazas, advertencias, faltantes_fe + faltantes_adm AS faltantes
OPTIONAL MATCH (e)-[:INTERRUMPIDA_POR|EXCLUIDA_POR]->(c)
WITH p, e, n, trazas, advertencias, faltantes,
     [x IN collect(DISTINCT coalesce(c.nombre, c.descripcion)) WHERE x IS NOT NULL] AS condiciones
RETURN {
  paciente: p.id,
  nutriente: n.nombre,
  evaluacion: e.id,
  estado: e.estado,
  situacion_interna: e.situacion_interna,
  fundamento: e.fundamento,
  regla_estado: e.regla_estado,
  fuente_verificada: e.fuente_verificada,
  tipo_fuente_verificada: e.tipo_fuente_verificada,
  motivo_fuera_alcance: e.motivo_fuera_alcance,
  condiciones: condiciones,
  riesgo_difuso: e.riesgo_difuso,
  etiqueta_riesgo: e.etiqueta_riesgo,
  resultado_provisional: e.resultado_provisional,
  trazas: trazas,
  advertencias: advertencias,
  datos_faltantes: faltantes
} AS contexto