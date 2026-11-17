
// =============================================================================
// 00 · LIMPIEZA Y RESTRICCIONES
// =============================================================================
// 0.1 Limpieza inicial (la base se reconstruye completa: reproducibilidad)
MATCH (n) DETACH DELETE n;

// 0.2 Restricciones de unicidad (Neo4j 5). Garantizan que MERGE no duplique nodos
//     y documentan la clave de cada etiqueta del esquema.
CREATE CONSTRAINT paciente_id IF NOT EXISTS FOR (n:Paciente) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT nutriente_codigo IF NOT EXISTS FOR (n:Nutriente) REQUIRE n.codigo IS UNIQUE;
CREATE CONSTRAINT alimento_id IF NOT EXISTS FOR (n:Alimento) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT suplemento_id IF NOT EXISTS FOR (n:Suplemento) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT consumo_id IF NOT EXISTS FOR (n:Consumo) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT comida_id IF NOT EXISTS FOR (n:Comida) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT hecho_id IF NOT EXISTS FOR (n:Hecho) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT regla_id IF NOT EXISTS FOR (n:Regla) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT regla_difusa_id IF NOT EXISTS FOR (n:ReglaDifusa) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT modelo_difuso_id IF NOT EXISTS FOR (n:ModeloDifuso) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT variable_difusa_id IF NOT EXISTS FOR (n:VariableDifusa) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT termino_difuso_id IF NOT EXISTS FOR (n:TerminoDifuso) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT criterio_nombre IF NOT EXISTS FOR (n:CriterioCandidato) REQUIRE n.nombre IS UNIQUE;
CREATE CONSTRAINT frame_nombre IF NOT EXISTS FOR (n:Frame) REQUIRE n.nombre IS UNIQUE;
CREATE CONSTRAINT slot_id IF NOT EXISTS FOR (n:Slot) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT pregunta_id IF NOT EXISTS FOR (n:PreguntaExperta) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT fuente_conocimiento_id IF NOT EXISTS FOR (n:FuenteConocimiento) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT evaluacion_nutriente_id IF NOT EXISTS FOR (n:EvaluacionNutriente) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT evaluacion_adm_id IF NOT EXISTS FOR (n:EvaluacionAdmisibilidad) REQUIRE n.id IS UNIQUE;
CREATE CONSTRAINT dato_faltante_clave IF NOT EXISTS FOR (n:DatoFaltante) REQUIRE n.clave IS UNIQUE;
CREATE INDEX paso_traza_regla IF NOT EXISTS FOR (n:PasoTraza) ON (n.regla);
