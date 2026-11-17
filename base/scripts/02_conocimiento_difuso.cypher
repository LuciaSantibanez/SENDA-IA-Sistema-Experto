
// ============================================================================
// 02 · CONOCIMIENTO DIFUSO (PI3) — MODELOS, VARIABLES, TÉRMINOS Y REGLAS
// ============================================================================
// Los parámetros de las funciones de pertenencia quedan como PROPIEDADES de los nodos,
// no en el código: validarlos no obliga a reescribir consultas (META-07).
UNWIND [
  {id: 'MD-ADM', s: 'SM-ADM', a: 'Zalazar', sal: 'calidad_registro', u: 'Grado de confianza del registro que viaja con ADMISIBLE', e: 'CANDIDATO'},
  {id: 'MD-CA', s: 'SM-CA', n: 'CA', a: 'Ramirez', sal: 'prioridad_revision_ca', u: 'Indicador auxiliar de prioridad de revisión; no asigna estado', e: 'CANDIDATO'},
  {id: 'MD-FE', s: 'SM-FE', n: 'FE', a: 'Santibañez', sal: 'riesgo_insuficiencia', u: 'Riesgo de ingesta insuficiente de hierro', e: 'CANDIDATO'},
  {id: 'MD-B12', s: 'SM-B12', n: 'B12', a: 'Nuñez', sal: 'riesgo_insuficiencia', u: 'Riesgo de ingesta insuficiente de B12', e: 'CANDIDATO'},
  {id: 'MD-VD', s: 'SM-VD', n: 'VD', a: 'Bataller', sal: 'riesgo_insuficiencia', u: 'Riesgo de aporte insuficiente de vitamina D', e: 'CANDIDATO'}
] AS row
MERGE (m:ModeloDifuso {id: row.id})
SET m.submodulo = row.s, m.autor = row.a, m.salida = row.sal, m.uso_salida = row.u, m.estado_validacion = row.e,
    m.version = 'PG2-1.0', m.operador_and = 'MIN', m.operador_or = 'MAX', m.operador_not = '1-MU',
    m.implicacion = 'MIN', m.agregacion = 'MAX', m.defuzzificacion = 'CENTROIDE', m.puntos = 1001,
    m.corte_bajo = 33.5, m.corte_alto = 66.5
WITH m, row MATCH (s:Submodulo {id: row.s}) MERGE (m)-[:PERTENECE_A]->(s)
WITH m, row WHERE row.n IS NOT NULL MATCH (n:Nutriente {codigo: row.n}) MERGE (m)-[:APLICA_A]->(n);
MATCH (m:ModeloDifuso), (c:CriterioCandidato) WHERE c.nombre = 'PARAM_FZ_' + substring(m.id, 3)
MERGE (m)-[:PARAMETRIZADO_POR]->(c);
MATCH (m:ModeloDifuso {id:'MD-VD'}), (c:CriterioCandidato {nombre:'PARAM_INDICE_UVB_VD'}) MERGE (m)-[:PARAMETRIZADO_POR]->(c);
MATCH (m:ModeloDifuso), (c:CriterioCandidato {nombre:'POLITICA_CORTES_SALIDA'}) WHERE m.salida = 'riesgo_insuficiencia'
MERGE (m)-[:PARAMETRIZADO_POR]->(c);
UNWIND [
  {id: 'V-ADM-DIAS', nom: 'dias_registro', rol: 'ENTRADA', mn: 0, mx: 7, u: 'días', f: 'Días que representan alimentación habitual (se trunca en 7)', d: 'CONSERVAR', ms: ['MD-ADM'], rp: ['PARAM_MIN_DIAS']},
  {id: 'V-ADM-COM', nom: 'comidas_principales', rol: 'ENTRADA', mn: 0, mx: 4, u: 'comidas/día', f: 'Promedio de desayuno / almuerzo / merienda / cena presentes', d: 'CONSERVAR', ms: ['MD-ADM'], rp: []},
  {id: 'V-ADM-CAL', nom: 'calidad_registro', rol: 'SALIDA', mn: 0, mx: 100, u: 'índice', f: 'Índice de confianza (no probabilidad)', d: 'CONSERVAR', ms: ['MD-ADM'], rp: []},
  {id: 'V-CA-ING', nom: 'ingesta_relativa_ca', rol: 'ENTRADA', mn: 0, mx: 200, u: '% referencia', f: '100 × ingesta_total / referencia CA-05', d: 'FUSIONAR (ex cercania_criterio_calcio: x = ingesta_relativa − 100)', ms: ['MD-CA'], rp: ['PARAM_UMBRAL_CA']},
  {id: 'V-CA-VAR', nom: 'variabilidad_diaria_ca', rol: 'ENTRADA', mn: 0, mx: 100, u: '% (CV)', f: '100 × desvío estándar / media de los totales diarios (n ≥ 2)', d: 'CONSERVAR', ms: ['MD-CA'], rp: []},
  {id: 'V-CA-PRI', nom: 'prioridad_revision_ca', rol: 'SALIDA', mn: 0, mx: 100, u: 'índice', f: 'Prioridad auxiliar de revisión', d: 'CONSERVAR (σ normalizado 20 → 21.23)', ms: ['MD-CA'], rp: []},
  {id: 'V-FE-NOH', nom: 'consumo_hierro_no_hemo', rol: 'ENTRADA', mn: 0, mx: 21, u: 'porciones/semana', f: 'Σ porciones de grupos fuente de hierro no hemo (se trunca en 21)', d: 'CONSERVAR (instancia de nivel_consumo(grupo))', ms: ['MD-FE'], rp: []},
  {id: 'V-FE-INH', nom: 'inhibidores_en_comidas', rol: 'ENTRADA', mn: 0, mx: 21, u: 'comidas/semana', f: 'Σ comidas con inhibidor coincidente (FE-02) + tomas de calcio con comidas (FE-11)', d: 'CONSERVAR', ms: ['MD-FE'], rp: []},
  {id: 'V-B12-ING', nom: 'ingesta_relativa_b12', rol: 'ENTRADA', mn: 0, mx: 200, u: '% referencia', f: '100 × ingesta dietaria B12 / 2.4 µg', d: 'CONSERVAR', ms: ['MD-B12'], rp: ['PARAM_UMBRAL_B12']},
  {id: 'V-B12-ADH', nom: 'adherencia_suplemento_b12', rol: 'ENTRADA', mn: 0, mx: 100, u: '% pauta', f: '100 × tomas realizadas / tomas indicadas (28 días)', d: 'CONSERVAR', ms: ['MD-B12'], rp: ['PARAM_REGULARIDAD_SUPL']},
  {id: 'V-VD-APO', nom: 'aporte_oral_relativo_vd', rol: 'ENTRADA', mn: 0, mx: 200, u: '% referencia', f: '100 × (dieta + suplemento promedio) / 15 µg', d: 'CONSERVAR (misma escala y cruces que ingesta_relativa; σ mayor)', ms: ['MD-VD'], rp: ['PARAM_UMBRAL_VD']},
  {id: 'V-VD-EXP', nom: 'exposicion_uvb_efectiva', rol: 'ENTRADA', mn: 0, mx: 100, u: 'índice', f: 'E = 100 · f_tiempo · f_UV · f_piel · f_protector · f_fototipo', d: 'FUSIONAR (tiempo; estación; latitud; protección; fototipo)', ms: ['MD-VD'], rp: ['PARAM_TIEMPO_SOL', 'PARAM_LATITUD']},
  {id: 'V-RIESGO', nom: 'riesgo_insuficiencia', rol: 'SALIDA', mn: 0, mx: 100, u: 'índice', f: 'Índice de compatibilidad con ingesta insuficiente (no probabilidad)', d: 'FUSIONAR (salida común FE / B12 / VD)', ms: ['MD-FE', 'MD-B12', 'MD-VD'], rp: []}
] AS row
MERGE (v:VariableDifusa {id: row.id})
SET v.nombre = row.nom, v.rol = row.rol, v.universo_min = row.mn, v.universo_max = row.mx, v.unidad = row.u,
    v.formula = row.f, v.decision_pg2 = row.d, v.estado_validacion = 'CANDIDATO'
WITH v, row UNWIND row.ms AS mid
MATCH (m:ModeloDifuso {id: mid}) MERGE (m)-[:DEFINE_VARIABLE]->(v);
UNWIND [
  {v: 'V-ADM-DIAS', c: 'PARAM_MIN_DIAS'}, {v: 'V-CA-ING', c: 'PARAM_UMBRAL_CA'}, {v: 'V-B12-ING', c: 'PARAM_UMBRAL_B12'},
  {v: 'V-B12-ADH', c: 'PARAM_REGULARIDAD_SUPL'}, {v: 'V-VD-APO', c: 'PARAM_UMBRAL_VD'}, {v: 'V-VD-EXP', c: 'PARAM_TIEMPO_SOL'},
  {v: 'V-VD-EXP', c: 'PARAM_LATITUD'}
] AS row
MATCH (v:VariableDifusa {id: row.v}), (c:CriterioCandidato {nombre: row.c}) MERGE (v)-[:REEMPLAZA_PARAMETRO]->(c);
UNWIND [
  {id: 'T-ADM-DIAS-escasa', v: 'V-ADM-DIAS', e: 'escasa', f: 'HOMBRO_IZQ', c: 1.0, s: 0.9, o: 1}, {id: 'T-ADM-DIAS-parcial', v: 'V-ADM-DIAS', e: 'parcial', f: 'GAUSSIANA', c: 3.0, s: 1.05, o: 2},
  {id: 'T-ADM-DIAS-amplia', v: 'V-ADM-DIAS', e: 'amplia', f: 'HOMBRO_DER', c: 6.0, s: 1.05, o: 3}, {id: 'T-ADM-COM-escasa', v: 'V-ADM-COM', e: 'escasa', f: 'HOMBRO_IZQ', c: 1.0, s: 0.65, o: 1},
  {id: 'T-ADM-COM-parcial', v: 'V-ADM-COM', e: 'parcial', f: 'GAUSSIANA', c: 2.5, s: 0.6, o: 2}, {id: 'T-ADM-COM-completa', v: 'V-ADM-COM', e: 'completa', f: 'HOMBRO_DER', c: 4.0, s: 0.6, o: 3},
  {id: 'T-ADM-CAL-baja', v: 'V-ADM-CAL', e: 'baja', f: 'GAUSSIANA', c: 18.0, s: 12.0, o: 1}, {id: 'T-ADM-CAL-media', v: 'V-ADM-CAL', e: 'media', f: 'GAUSSIANA', c: 50.0, s: 12.0, o: 2},
  {id: 'T-ADM-CAL-alta', v: 'V-ADM-CAL', e: 'alta', f: 'GAUSSIANA', c: 84.0, s: 12.0, o: 3}, {id: 'T-CA-ING-baja', v: 'V-CA-ING', e: 'baja', f: 'HOMBRO_IZQ', c: 55.0, s: 12.74, o: 1},
  {id: 'T-CA-ING-limitrofe', v: 'V-CA-ING', e: 'limitrofe', f: 'GAUSSIANA', c: 80.0, s: 8.49, o: 2}, {id: 'T-CA-ING-adecuada', v: 'V-CA-ING', e: 'adecuada', f: 'HOMBRO_DER', c: 105.0, s: 12.74, o: 3},
  {id: 'T-CA-VAR-baja', v: 'V-CA-VAR', e: 'baja', f: 'GAUSSIANA', c: 0.0, s: 20.0, o: 1}, {id: 'T-CA-VAR-intermedia', v: 'V-CA-VAR', e: 'intermedia', f: 'GAUSSIANA', c: 50.0, s: 20.0, o: 2},
  {id: 'T-CA-VAR-alta', v: 'V-CA-VAR', e: 'alta', f: 'GAUSSIANA', c: 100.0, s: 20.0, o: 3}, {id: 'T-CA-PRI-baja', v: 'V-CA-PRI', e: 'baja', f: 'GAUSSIANA', c: 0.0, s: 21.23, o: 1},
  {id: 'T-CA-PRI-media', v: 'V-CA-PRI', e: 'media', f: 'GAUSSIANA', c: 50.0, s: 21.23, o: 2}, {id: 'T-CA-PRI-alta', v: 'V-CA-PRI', e: 'alta', f: 'GAUSSIANA', c: 100.0, s: 21.23, o: 3},
  {id: 'T-FE-NOH-bajo', v: 'V-FE-NOH', e: 'bajo', f: 'HOMBRO_IZQ', c: 0.0, s: 1.5, o: 1}, {id: 'T-FE-NOH-medio', v: 'V-FE-NOH', e: 'medio', f: 'GAUSSIANA', c: 4.0, s: 1.5, o: 2},
  {id: 'T-FE-NOH-alto', v: 'V-FE-NOH', e: 'alto', f: 'HOMBRO_DER', c: 8.0, s: 2.5, o: 3}, {id: 'T-FE-INH-bajo', v: 'V-FE-INH', e: 'bajo', f: 'HOMBRO_IZQ', c: 0.0, s: 2.5, o: 1},
  {id: 'T-FE-INH-moderado', v: 'V-FE-INH', e: 'moderado', f: 'GAUSSIANA', c: 7.0, s: 2.5, o: 2}, {id: 'T-FE-INH-frecuente', v: 'V-FE-INH', e: 'frecuente', f: 'HOMBRO_DER', c: 14.0, s: 3.5, o: 3},
  {id: 'T-B12-ING-baja', v: 'V-B12-ING', e: 'baja', f: 'HOMBRO_IZQ', c: 55.0, s: 12.74, o: 1}, {id: 'T-B12-ING-limitrofe', v: 'V-B12-ING', e: 'limitrofe', f: 'GAUSSIANA', c: 80.0, s: 8.49, o: 2},
  {id: 'T-B12-ING-adecuada', v: 'V-B12-ING', e: 'adecuada', f: 'HOMBRO_DER', c: 105.0, s: 12.74, o: 3}, {id: 'T-B12-ADH-irregular', v: 'V-B12-ADH', e: 'irregular', f: 'HOMBRO_IZQ', c: 35.0, s: 12.74, o: 1},
  {id: 'T-B12-ADH-intermedia', v: 'V-B12-ADH', e: 'intermedia', f: 'GAUSSIANA', c: 65.0, s: 12.74, o: 2}, {id: 'T-B12-ADH-regular', v: 'V-B12-ADH', e: 'regular', f: 'HOMBRO_DER', c: 95.0, s: 12.74, o: 3},
  {id: 'T-VD-APO-baja', v: 'V-VD-APO', e: 'baja', f: 'HOMBRO_IZQ', c: 50.0, s: 16.99, o: 1}, {id: 'T-VD-APO-limitrofe', v: 'V-VD-APO', e: 'limitrofe', f: 'GAUSSIANA', c: 80.0, s: 8.49, o: 2},
  {id: 'T-VD-APO-adecuada', v: 'V-VD-APO', e: 'adecuada', f: 'HOMBRO_DER', c: 110.0, s: 16.99, o: 3}, {id: 'T-VD-EXP-escasa', v: 'V-VD-EXP', e: 'escasa', f: 'HOMBRO_IZQ', c: 5.0, s: 8.49, o: 1},
  {id: 'T-VD-EXP-moderada', v: 'V-VD-EXP', e: 'moderada', f: 'GAUSSIANA', c: 30.0, s: 12.74, o: 2}, {id: 'T-VD-EXP-buena', v: 'V-VD-EXP', e: 'buena', f: 'HOMBRO_DER', c: 60.0, s: 12.74, o: 3},
  {id: 'T-RIESGO-bajo', v: 'V-RIESGO', e: 'bajo', f: 'GAUSSIANA', c: 0.0, s: 21.23, o: 1}, {id: 'T-RIESGO-moderado', v: 'V-RIESGO', e: 'moderado', f: 'GAUSSIANA', c: 50.0, s: 21.23, o: 2},
  {id: 'T-RIESGO-alto', v: 'V-RIESGO', e: 'alto', f: 'GAUSSIANA', c: 100.0, s: 21.23, o: 3}
] AS row
MATCH (v:VariableDifusa {id: row.v})
MERGE (t:TerminoDifuso {id: row.id})
SET t.etiqueta = row.e, t.tipo_funcion = row.f, t.centro = row.c, t.sigma = row.s, t.estado_validacion = 'CANDIDATO'
MERGE (v)-[x:TIENE_TERMINO]->(t) SET x.orden = row.o;
// Validación con la experta de los cruces 70 % / 90 % (Q9) y de la adherencia (Q28)
MATCH (t:TerminoDifuso), (q:PreguntaExperta {id:'Q9'}) WHERE t.id STARTS WITH 'T-B12-ING' OR t.id STARTS WITH 'T-CA-ING' OR t.id STARTS WITH 'T-VD-APO'
MERGE (t)-[:VALIDADO_CON]->(q);
MATCH (t:TerminoDifuso), (q:PreguntaExperta {id:'Q28'}) WHERE t.id STARTS WITH 'T-B12-ADH' MERGE (t)-[:VALIDADO_CON]->(q);
MATCH (t:TerminoDifuso), (q:PreguntaExperta) WHERE t.id STARTS WITH 'T-ADM-DIAS' AND q.id IN ['Q1','Q3'] MERGE (t)-[:VALIDADO_CON]->(q);
MATCH (t:TerminoDifuso), (q:PreguntaExperta) WHERE t.id STARTS WITH 'T-VD-EXP' AND q.id IN ['Q24','Q27'] MERGE (t)-[:VALIDADO_CON]->(q);
UNWIND [
  {id: 'ADM-F01', m: 'MD-ADM', t: 'SI días ES amplia Y comidas ES completa ENTONCES calidad ES alta', r: 'Q1;Q2', c: 'T-ADM-CAL-alta', cr: 'ADM-06'},
  {id: 'ADM-F02', m: 'MD-ADM', t: 'SI días ES parcial Y comidas ES completa ENTONCES calidad ES media', r: 'Q3', c: 'T-ADM-CAL-media', cr: 'ADM-06'},
  {id: 'ADM-F03', m: 'MD-ADM', t: 'SI días ES amplia Y comidas ES parcial ENTONCES calidad ES media', r: 'Supuesto de diseño', c: 'T-ADM-CAL-media', cr: 'ADM-06'},
  {id: 'ADM-F04', m: 'MD-ADM', t: 'SI días ES escasa Y comidas ES completa ENTONCES calidad ES baja', r: 'Q3', c: 'T-ADM-CAL-baja', cr: 'ADM-06'},
  {id: 'ADM-F05', m: 'MD-ADM', t: 'SI días ES parcial Y comidas ES parcial ENTONCES calidad ES media', r: 'Supuesto de diseño', c: 'T-ADM-CAL-media', cr: 'ADM-06'},
  {id: 'ADM-F06', m: 'MD-ADM', t: 'SI días ES escasa O comidas ES escasa ENTONCES calidad ES baja', r: 'Piso de diseño', c: 'T-ADM-CAL-baja', cr: 'ADM-06'},
  {id: 'CA-D01', m: 'MD-CA', t: 'SI ingesta ES baja O variabilidad ES alta ENTONCES prioridad ES alta', r: 'Diseño (Ramirez)', c: 'T-CA-PRI-alta', cr: 'G-07'},
  {id: 'CA-D02', m: 'MD-CA', t: 'SI ingesta ES limítrofe Y (variabilidad ES baja O intermedia) ENTONCES prioridad ES media', r: 'Diseño (Ramirez)', c: 'T-CA-PRI-media', cr: 'G-07'},
  {id: 'CA-D03', m: 'MD-CA', t: 'SI ingesta ES adecuada Y variabilidad ES intermedia ENTONCES prioridad ES media', r: 'Diseño (Ramirez)', c: 'T-CA-PRI-media', cr: 'G-07'},
  {id: 'CA-D04', m: 'MD-CA', t: 'SI ingesta ES adecuada Y variabilidad ES baja ENTONCES prioridad ES baja', r: 'Diseño (Ramirez)', c: 'T-CA-PRI-baja', cr: 'G-07'},
  {id: 'FE-F01', m: 'MD-FE', t: 'SI consumo no hemo ES bajo Y inhibidores ES frecuente ENTONCES riesgo ES alto', r: 'FE-03;FE-05', c: 'T-RIESGO-alto', cr: 'FE-03'},
  {id: 'FE-F02', m: 'MD-FE', t: 'SI consumo no hemo ES bajo Y (inhibidores ES bajo O moderado) ENTONCES riesgo ES moderado', r: 'Supuesto de diseño', c: 'T-RIESGO-moderado', cr: 'FE-03'},
  {id: 'FE-F03', m: 'MD-FE', t: 'SI consumo no hemo ES medio Y inhibidores ES frecuente ENTONCES riesgo ES moderado', r: 'FE-05', c: 'T-RIESGO-moderado', cr: 'FE-05'},
  {id: 'FE-F04', m: 'MD-FE', t: 'SI consumo no hemo ES medio Y (inhibidores ES bajo O moderado) ENTONCES riesgo ES bajo', r: 'Supuesto de diseño', c: 'T-RIESGO-bajo', cr: 'FE-07'},
  {id: 'FE-F05', m: 'MD-FE', t: 'SI consumo no hemo ES alto Y (inhibidores ES bajo O moderado) ENTONCES riesgo ES bajo', r: 'FE-04;FE-07', c: 'T-RIESGO-bajo', cr: 'FE-07'},
  {id: 'FE-F06', m: 'MD-FE', t: 'SI consumo no hemo ES alto Y inhibidores ES frecuente ENTONCES riesgo ES moderado', r: 'Hipótesis (P3c)', c: 'T-RIESGO-moderado', cr: 'FE-05'},
  {id: 'B12-FZ-01', m: 'MD-B12', t: 'SI ingesta ES baja Y adherencia ES irregular ENTONCES riesgo ES alto', r: 'R06;CASO_C', c: 'T-RIESGO-alto', cr: 'R06'},
  {id: 'B12-FZ-02', m: 'MD-B12', t: 'SI ingesta ES baja Y adherencia ES intermedia ENTONCES riesgo ES moderado', r: 'Q28 (P-F4 a validar)', c: 'T-RIESGO-moderado', cr: 'B12-07'},
  {id: 'B12-FZ-03', m: 'MD-B12', t: 'SI ingesta ES limítrofe Y (adherencia ES irregular O intermedia) ENTONCES riesgo ES moderado', r: 'Q9', c: 'T-RIESGO-moderado', cr: 'G-07'},
  {id: 'B12-FZ-04', m: 'MD-B12', t: 'SI ingesta ES adecuada O adherencia ES regular ENTONCES riesgo ES bajo', r: 'G-14;B12-07', c: 'T-RIESGO-bajo', cr: 'G-14'},
  {id: 'VD-FZ-01', m: 'MD-VD', t: 'SI aporte ES baja Y exposición ES escasa ENTONCES riesgo ES alto', r: 'Q9;R15', c: 'T-RIESGO-alto', cr: 'VD-13'},
  {id: 'VD-FZ-02', m: 'MD-VD', t: 'SI aporte ES baja Y exposición NO ES escasa ENTONCES riesgo ES moderado', r: 'Q26', c: 'T-RIESGO-moderado', cr: 'VD-14'},
  {id: 'VD-FZ-03', m: 'MD-VD', t: 'SI aporte ES limítrofe Y exposición NO ES buena ENTONCES riesgo ES moderado', r: 'Q9', c: 'T-RIESGO-moderado', cr: 'VD-13'},
  {id: 'VD-FZ-04', m: 'MD-VD', t: 'SI aporte ES adecuada O (aporte NO ES baja Y exposición ES buena) ENTONCES riesgo ES bajo', r: 'G-14;Q26', c: 'T-RIESGO-bajo', cr: 'G-14'}
] AS row
MATCH (m:ModeloDifuso {id: row.m}), (tc:TerminoDifuso {id: row.c})
MERGE (r:ReglaDifusa {id: row.id})
SET r.texto = row.t, r.respaldo = row.r, r.peso = 1.0, r.estado_validacion = 'CANDIDATO'
MERGE (m)-[:CONTIENE_REGLA]->(r)
MERGE (r)-[:CONSECUENTE]->(tc)
WITH r, row MATCH (rc:Regla {id: row.cr}) MERGE (r)-[:GRADUA]->(rc);
// Antecedentes en forma normal conjuntiva: OR = MAX dentro de cada grupo; AND = MIN entre grupos; negado → 1 − μ
UNWIND [
  {r: 'ADM-F01', g: 1, t: 'T-ADM-DIAS-amplia', neg: false}, {r: 'ADM-F01', g: 2, t: 'T-ADM-COM-completa', neg: false}, {r: 'ADM-F02', g: 1, t: 'T-ADM-DIAS-parcial', neg: false},
  {r: 'ADM-F02', g: 2, t: 'T-ADM-COM-completa', neg: false}, {r: 'ADM-F03', g: 1, t: 'T-ADM-DIAS-amplia', neg: false}, {r: 'ADM-F03', g: 2, t: 'T-ADM-COM-parcial', neg: false},
  {r: 'ADM-F04', g: 1, t: 'T-ADM-DIAS-escasa', neg: false}, {r: 'ADM-F04', g: 2, t: 'T-ADM-COM-completa', neg: false}, {r: 'ADM-F05', g: 1, t: 'T-ADM-DIAS-parcial', neg: false},
  {r: 'ADM-F05', g: 2, t: 'T-ADM-COM-parcial', neg: false}, {r: 'ADM-F06', g: 1, t: 'T-ADM-DIAS-escasa', neg: false}, {r: 'ADM-F06', g: 1, t: 'T-ADM-COM-escasa', neg: false},
  {r: 'CA-D01', g: 1, t: 'T-CA-ING-baja', neg: false}, {r: 'CA-D01', g: 1, t: 'T-CA-VAR-alta', neg: false}, {r: 'CA-D02', g: 1, t: 'T-CA-ING-limitrofe', neg: false},
  {r: 'CA-D02', g: 2, t: 'T-CA-VAR-baja', neg: false}, {r: 'CA-D02', g: 2, t: 'T-CA-VAR-intermedia', neg: false}, {r: 'CA-D03', g: 1, t: 'T-CA-ING-adecuada', neg: false},
  {r: 'CA-D03', g: 2, t: 'T-CA-VAR-intermedia', neg: false}, {r: 'CA-D04', g: 1, t: 'T-CA-ING-adecuada', neg: false}, {r: 'CA-D04', g: 2, t: 'T-CA-VAR-baja', neg: false},
  {r: 'FE-F01', g: 1, t: 'T-FE-NOH-bajo', neg: false}, {r: 'FE-F01', g: 2, t: 'T-FE-INH-frecuente', neg: false}, {r: 'FE-F02', g: 1, t: 'T-FE-NOH-bajo', neg: false},
  {r: 'FE-F02', g: 2, t: 'T-FE-INH-bajo', neg: false}, {r: 'FE-F02', g: 2, t: 'T-FE-INH-moderado', neg: false}, {r: 'FE-F03', g: 1, t: 'T-FE-NOH-medio', neg: false},
  {r: 'FE-F03', g: 2, t: 'T-FE-INH-frecuente', neg: false}, {r: 'FE-F04', g: 1, t: 'T-FE-NOH-medio', neg: false}, {r: 'FE-F04', g: 2, t: 'T-FE-INH-bajo', neg: false},
  {r: 'FE-F04', g: 2, t: 'T-FE-INH-moderado', neg: false}, {r: 'FE-F05', g: 1, t: 'T-FE-NOH-alto', neg: false}, {r: 'FE-F05', g: 2, t: 'T-FE-INH-bajo', neg: false},
  {r: 'FE-F05', g: 2, t: 'T-FE-INH-moderado', neg: false}, {r: 'FE-F06', g: 1, t: 'T-FE-NOH-alto', neg: false}, {r: 'FE-F06', g: 2, t: 'T-FE-INH-frecuente', neg: false},
  {r: 'B12-FZ-01', g: 1, t: 'T-B12-ING-baja', neg: false}, {r: 'B12-FZ-01', g: 2, t: 'T-B12-ADH-irregular', neg: false}, {r: 'B12-FZ-02', g: 1, t: 'T-B12-ING-baja', neg: false},
  {r: 'B12-FZ-02', g: 2, t: 'T-B12-ADH-intermedia', neg: false}, {r: 'B12-FZ-03', g: 1, t: 'T-B12-ING-limitrofe', neg: false}, {r: 'B12-FZ-03', g: 2, t: 'T-B12-ADH-irregular', neg: false},
  {r: 'B12-FZ-03', g: 2, t: 'T-B12-ADH-intermedia', neg: false}, {r: 'B12-FZ-04', g: 1, t: 'T-B12-ING-adecuada', neg: false}, {r: 'B12-FZ-04', g: 1, t: 'T-B12-ADH-regular', neg: false},
  {r: 'VD-FZ-01', g: 1, t: 'T-VD-APO-baja', neg: false}, {r: 'VD-FZ-01', g: 2, t: 'T-VD-EXP-escasa', neg: false}, {r: 'VD-FZ-02', g: 1, t: 'T-VD-APO-baja', neg: false},
  {r: 'VD-FZ-02', g: 2, t: 'T-VD-EXP-escasa', neg: true}, {r: 'VD-FZ-03', g: 1, t: 'T-VD-APO-limitrofe', neg: false}, {r: 'VD-FZ-03', g: 2, t: 'T-VD-EXP-buena', neg: true},
  {r: 'VD-FZ-04', g: 1, t: 'T-VD-APO-adecuada', neg: false}, {r: 'VD-FZ-04', g: 1, t: 'T-VD-APO-baja', neg: true}, {r: 'VD-FZ-04', g: 2, t: 'T-VD-APO-adecuada', neg: false},
  {r: 'VD-FZ-04', g: 2, t: 'T-VD-EXP-buena', neg: false}
] AS row
MATCH (r:ReglaDifusa {id: row.r}), (t:TerminoDifuso {id: row.t})
MERGE (r)-[a:ANTECEDENTE {grupo: row.g}]->(t) SET a.negado = row.neg;
// Reglas crisp reemplazadas por reglas difusas (estado REEMPLAZADA en PG2)
UNWIND [['VD-13', 'VD-FZ-01'], ['VD-14', 'VD-FZ-02']] AS par
MATCH (rc:Regla {id: par[0]}), (rd:ReglaDifusa {id: par[1]}) MERGE (rc)-[:REEMPLAZADA_POR]->(rd);
MATCH (rc:Regla {id:'VD-27'}), (rn:Regla {id:'VD-FZ-06'}) MERGE (rc)-[:REEMPLAZADA_POR]->(rn);

// Coeficientes del índice de exposición UVB (Bataller PI3 c.3)
UNWIND [
  {c: 'PIEL', v: 'ALTA', k: 0.25, d: 'Ropa larga (poca piel expuesta)'}, {c: 'PIEL', v: 'MEDIA', k: 0.5, d: 'Manga corta y pantalón largo'}, {c: 'PIEL', v: 'BAJA', k: 1.0, d: 'Brazos y piernas descubiertos'},
  {c: 'PROTECTOR', v: 'SIEMPRE', k: 0.5, d: 'Protector siempre'}, {c: 'PROTECTOR', v: 'A_VECES', k: 0.75, d: 'Protector a veces'}, {c: 'PROTECTOR', v: 'NUNCA', k: 1.0, d: 'Sin protector'},
  {c: 'FOTOTIPO', v: 'I', k: 1.0, d: 'Fitzpatrick I'}, {c: 'FOTOTIPO', v: 'II', k: 1.0, d: 'Fitzpatrick II'}, {c: 'FOTOTIPO', v: 'III', k: 1.0, d: 'Fitzpatrick III'},
  {c: 'FOTOTIPO', v: 'IV', k: 0.75, d: 'Fitzpatrick IV'}, {c: 'FOTOTIPO', v: 'V', k: 0.4, d: 'Fitzpatrick V'}, {c: 'FOTOTIPO', v: 'VI', k: 0.4, d: 'Fitzpatrick VI'}
] AS row
MERGE (f:FactorExposicion {id: row.c + '-' + row.v})
SET f.codigo = row.c, f.valor_entrada = row.v, f.coeficiente = row.k, f.descripcion = row.d, f.estado_validacion = 'CANDIDATO'
WITH f MATCH (v:VariableDifusa {id:'V-VD-EXP'}) MERGE (v)-[:SE_COMPONE_DE]->(f);
