MATCH (p:Paciente {id: $paciente})-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
OPTIONAL MATCH (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
OPTIONAL MATCH (ea)-[:REGISTRA]->(t:PasoTraza)
WITH p, ea, r, t ORDER BY t.orden
WITH p, ea, r, [x IN collect(CASE WHEN t IS NULL THEN null ELSE {
        orden: t.orden, regla: t.regla, efecto: t.efecto, valor: t.valor, texto: t.texto
     } END) WHERE x IS NOT NULL] AS trazas
OPTIONAL MATCH (ea)-[:INTERRUMPIDA_POR]->(c:CondicionDerivacion)
OPTIONAL MATCH (ea)-[:EXCLUIDA_POR]->(ca:CriterioAlcance)
OPTIONAL MATCH (ea)-[:GENERA]->(df:DatoFaltante)
WITH p, ea, r, trazas,
     head([x IN collect(DISTINCT c.nombre) WHERE x IS NOT NULL]) AS motivo_derivacion,
     head([x IN collect(DISTINCT ca.descripcion) WHERE x IS NOT NULL]) AS motivo_alcance,
     [x IN collect(DISTINCT df.texto) WHERE x IS NOT NULL] AS datos_faltantes
RETURN {
  paciente: p.id,
  nombre_caso: p.nombre_caso,
  veredicto: ea.veredicto,
  accion: ea.accion,
  calidad_registro: ea.calidad_registro,
  indice_calidad: ea.indice_calidad,
  etiqueta_difusa: ea.etiqueta_difusa,
  tope_aplicado: ea.tope_aplicado,
  motivo: coalesce(motivo_derivacion, motivo_alcance),
  datos_faltantes: datos_faltantes,
  dias_registro: r.dias_registro,
  comidas_principales: r.comidas_principales,
  incluye_habil: r.incluye_habil,
  incluye_finde: r.incluye_finde,
  trazas: trazas
} AS contexto