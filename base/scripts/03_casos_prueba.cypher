
// ============================================================================
// 03 · CASOS DE PRUEBA (instancias) — positivos, negativos e intermedios/difusos
// ============================================================================
// Generado desde python/casos.py. Cada paciente es un hecho del caso; nada de esto es conocimiento general.

// ---- P01 · Vegana con bebida de almendras de rótulo desconocido (caso A / integrado 1)
// Escenario: MIXTO: crisp positivo en FE, datos faltantes en CA-B12-VD
MATCH (pa:PatronAlimentario {codigo:'VEGANO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P01'})
SET p += {id: 'P01', nombre_caso: 'Vegana con bebida de almendras de rótulo desconocido (caso A / integrado 1)', escenario: 'MIXTO: crisp positivo en FE, datos faltantes en CA-B12-VD', edad: 29, sexo: 'F', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P01-C1'}) SET c.fecha = '2026-07-14', c.mes = 7
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P01-REG'})
SET r += {id: 'P01-REG', dias_registro: 7.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P01-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P01-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P01-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P01-CENA', m: 'CENA', pr: true}, {id: 'P01-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P01'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P01-CS01', a: 'bebida_almendras_desc', f: 7.0, r: 'Tomo un vaso de bebida de almendras por día; no sé si está fortificada'}, {id: 'P01-CS02', a: 'lentejas', f: 1.0, r: 'Como lentejas una vez por semana'},
  {id: 'P01-CS03', a: 'mate', f: 14.0, r: 'Tomo mate con el almuerzo y la cena'}
] AS row
MATCH (p:Paciente {id:'P01'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P01-CS01', cm: 'P01-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P01-CS02', cm: 'P01-ALMUERZO', v: 1.0, co: 'SI'}, {c: 'P01-CS03', cm: 'P01-ALMUERZO', v: 7.0, co: 'SI'},
  {c: 'P01-CS03', cm: 'P01-CENA', v: 7.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P01-H-nivel_hemo', at: 'nivel_hemo', v: 'NULO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'BAJO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P01-H-fortificacion_bebida_almendras', at: 'fortificacion_bebida_almendras', v: 'DESCONOCIDO', f: 'LLM_ENTRADA', ce: 0.92, t: 'No sé si está fortificada'}
] AS row
MATCH (p:Paciente {id:'P01'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P01', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P01'})
MERGE (x:ExposicionSolar {id:'P01-EXP'}) SET x += {id: 'P01-EXP', tiempo_aire_libre_h: 2.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'ALTA', protector_solar: 'NUNCA', fototipo: 'III'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);

// ---- P02 · Celiaquía no controlada (caso integrado 2)
// Escenario: NEGATIVO: derivación general
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P02'})
SET p += {id: 'P02', nombre_caso: 'Celiaquía no controlada (caso integrado 2)', escenario: 'NEGATIVO: derivación general', edad: 45, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P02-C1'}) SET c.fecha = '2026-03-10', c.mes = 3
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P02-REG'})
SET r += {id: 'P02-REG', dias_registro: 3.0, estado_dias: 'CONOCIDO', comidas_principales: 3.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: false, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P02-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P02-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P02-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P02-CENA', m: 'CENA', pr: true}, {id: 'P02-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P02'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P02-CS01', a: 'carne_vacuna', f: 3.0, r: 'Carne tres veces por semana'}, {id: 'P02-CS02', a: 'leche_vaca', f: 7.0, r: 'Leche en el desayuno'}
] AS row
MATCH (p:Paciente {id:'P02'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P02-CS01', cm: 'P02-ALMUERZO', v: 3.0, co: 'SI'}, {c: 'P02-CS02', cm: 'P02-DESAYUNO', v: 7.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P02-H-sintoma', at: 'sintoma', v: 'DIARREA_CRONICA', f: 'LLM_ENTRADA', ce: 0.95, t: 'Tengo diarrea hace meses'}
] AS row
MATCH (p:Paciente {id:'P02'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P02', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P02'}), (c:CondicionDerivacion {codigo:'CELIAQUIA_NO_CONTROLADA'})
MERGE (p)-[x:PRESENTA]->(c) SET x.estado = 'PRESENTE';

// ---- P03 · Omnívora de 55 años con omeprazol y suplemento de calcio + D (caso B / integrado 3)
// Escenario: POSITIVO: fuentes verificadas + advertencias cruzadas; VD difuso
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P03'})
SET p += {id: 'P03', nombre_caso: 'Omnívora de 55 años con omeprazol y suplemento de calcio + D (caso B / integrado 3)', escenario: 'POSITIVO: fuentes verificadas + advertencias cruzadas; VD difuso', edad: 55, sexo: 'F', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'SI', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P03-C1'}) SET c.fecha = '2026-01-20', c.mes = 1
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P03-REG'})
SET r += {id: 'P03-REG', dias_registro: 7.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false, totales_diarios_ca: [1175.9, 1245.8, 1207.4, 1256.3, 1186.4, 1238.8, 1214.4]}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P03-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P03-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P03-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P03-CENA', m: 'CENA', pr: true}, {id: 'P03-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P03'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P03-CS01', a: 'carne_vacuna', f: 5.0, r: 'Carne cinco veces por semana'}, {id: 'P03-CS02', a: 'pollo', f: 2.0, r: 'Pollo dos veces'},
  {id: 'P03-CS03', a: 'leche_fortificada_d', f: 7.0, r: 'Leche fortificada en el desayuno'}, {id: 'P03-CS04', a: 'yogur', f: 7.0, r: 'Yogur en la merienda'},
  {id: 'P03-CS05', a: 'huevo', f: 3.0, r: 'Huevo tres veces'}, {id: 'P03-CS06', a: 'queso', f: 2.0, r: 'Queso dos veces'}
] AS row
MATCH (p:Paciente {id:'P03'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P03-CS01', cm: 'P03-ALMUERZO', v: 3.0, co: 'SI'}, {c: 'P03-CS01', cm: 'P03-CENA', v: 2.0, co: 'SI'}, {c: 'P03-CS02', cm: 'P03-CENA', v: 2.0, co: 'SI'},
  {c: 'P03-CS03', cm: 'P03-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P03-CS04', cm: 'P03-MERIENDA', v: 7.0, co: 'SI'}, {c: 'P03-CS05', cm: 'P03-CENA', v: 3.0, co: 'SI'},
  {c: 'P03-CS06', cm: 'P03-MERIENDA', v: 2.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P03-H-nivel_hemo', at: 'nivel_hemo', v: 'ALTO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P03-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'BAJO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P03-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P03-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P03-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P03-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0}
] AS row
MATCH (p:Paciente {id:'P03'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P03', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P03'})
MERGE (s:Suplemento:Fuente {id:'supl_calcio_d'}) SET s.nombre = 'Calcio + vitamina D', s.tipo = 'CALCIO_D'
MERGE (p)-[t:TOMA]->(s) SET t += {pauta_tomas_28d: 28, tomas_realizadas_28d: 28, regularidad: 'REGULAR', frecuencia_conocida: 'SI', momento_toma: 'CON_COMIDAS', indicado_por_medico: 'DESCONOCIDO', comida: 'P03-ALMUERZO'};
UNWIND [
  {s: 'supl_calcio_d', n: 'CA', d: 600.0, u: 'mg'}, {s: 'supl_calcio_d', n: 'VD', d: 10.0, u: 'µg'}
] AS row
MATCH (s:Suplemento {id: row.s}), (n:Nutriente {codigo: row.n})
MERGE (s)-[c:CONTIENE]->(n) SET c.dosis = row.d, c.unidad = row.u, c.valor = 'SI', c.estado_dosis = 'CONOCIDA';
MATCH (p:Paciente {id:'P03'}), (f:Medicamento {codigo:'IBP'})
MERGE (p)-[u:USA]->(f) SET u.tiempo_uso_meses = 60, u.prolongado = 'PENDIENTE_CRITERIO';
MATCH (p:Paciente {id:'P03'})
MERGE (x:ExposicionSolar {id:'P03-EXP'}) SET x += {id: 'P03-EXP', tiempo_aire_libre_h: 5.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'MEDIA', protector_solar: 'A_VECES', fototipo: 'III'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);

// ---- P04 · Vegano con B12 «cuando se acuerda» (caso C)
// Escenario: NEGATIVO de datos + excepción FE (Q19)
MATCH (pa:PatronAlimentario {codigo:'VEGANO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P04'})
SET p += {id: 'P04', nombre_caso: 'Vegano con B12 «cuando se acuerda» (caso C)', escenario: 'NEGATIVO de datos + excepción FE (Q19)', edad: 34, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'SI', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P04-C1'}) SET c.fecha = '2026-08-05', c.mes = 8
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P04-REG'})
SET r += {id: 'P04-REG', dias_registro: 7.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false, totales_diarios_ca: [233.7, 362.0, 291.5, 381.3, 253.0, 349.2, 304.3]}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P04-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P04-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P04-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P04-CENA', m: 'CENA', pr: true}, {id: 'P04-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P04'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P04-CS01', a: 'lentejas', f: 4.0, r: 'Lentejas cuatro veces'}, {id: 'P04-CS02', a: 'garbanzos', f: 3.0, r: 'Garbanzos tres veces'},
  {id: 'P04-CS03', a: 'naranja', f: 7.0, r: 'Naranja con el almuerzo'}, {id: 'P04-CS04', a: 'bebida_soja_fort', f: 7.0, r: 'Bebida de soja fortificada'},
  {id: 'P04-CS05', a: 'espinaca', f: 2.0, r: 'Espinaca dos veces'}
] AS row
MATCH (p:Paciente {id:'P04'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P04-CS01', cm: 'P04-ALMUERZO', v: 4.0, co: 'SI'}, {c: 'P04-CS02', cm: 'P04-CENA', v: 3.0, co: 'SI'}, {c: 'P04-CS03', cm: 'P04-ALMUERZO', v: 7.0, co: 'SI'},
  {c: 'P04-CS04', cm: 'P04-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P04-CS05', cm: 'P04-CENA', v: 2.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P04-H-nivel_hemo', at: 'nivel_hemo', v: 'NULO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'ALTO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-potenciadores', at: 'potenciadores', v: 'FRECUENTES', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P04-H-frecuencia_suplemento_b12', at: 'frecuencia_suplemento_b12', v: 'DESCONOCIDO', f: 'LLM_ENTRADA', ce: 0.4, t: 'Tomo B12 cuando me acuerdo'}
] AS row
MATCH (p:Paciente {id:'P04'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P04', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P04'})
MERGE (s:Suplemento:Fuente {id:'supl_b12_simple'}) SET s.nombre = 'Vitamina B12 250 µg', s.tipo = 'SIMPLE'
MERGE (p)-[t:TOMA]->(s) SET t += {pauta_tomas_28d: 28, regularidad: 'IRREGULAR', frecuencia_conocida: 'NO', momento_toma: 'DESCONOCIDO', indicado_por_medico: 'NO'};
UNWIND [
  {s: 'supl_b12_simple', n: 'B12', d: 250.0, u: 'µg'}
] AS row
MATCH (s:Suplemento {id: row.s}), (n:Nutriente {codigo: row.n})
MERGE (s)-[c:CONTIENE]->(n) SET c.dosis = row.d, c.unidad = row.u, c.valor = 'SI', c.estado_dosis = 'CONOCIDA';
MATCH (p:Paciente {id:'P04'}), (f:FuenteNoConfiable {codigo:'ESPIRULINA'})
MERGE (p)-[:DECLARA_FUENTE]->(f);
MATCH (p:Paciente {id:'P04'})
MERGE (x:ExposicionSolar {id:'P04-EXP'}) SET x += {id: 'P04-EXP', tiempo_aire_libre_h: 4.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'ALTA', protector_solar: 'NUNCA', fototipo: 'III'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);

// ---- P05 · Trabaja al aire libre con ropa larga y protector (caso D, datos completados)
// Escenario: DIFUSO: VD moderado y proyección invernal alta
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P05'})
SET p += {id: 'P05', nombre_caso: 'Trabaja al aire libre con ropa larga y protector (caso D, datos completados)', escenario: 'DIFUSO: VD moderado y proyección invernal alta', edad: 25, sexo: 'F', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P05-C1'}) SET c.fecha = '2026-01-28', c.mes = 1
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P05-REG'})
SET r += {id: 'P05-REG', dias_registro: 7.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false, totales_diarios_ca: [554.6, 630.3, 588.6, 641.6, 565.9, 622.7, 596.2]}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P05-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P05-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P05-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P05-CENA', m: 'CENA', pr: true}, {id: 'P05-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P05'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P05-CS01', a: 'carne_vacuna', f: 5.0, r: 'Carne cinco veces'}, {id: 'P05-CS02', a: 'pollo', f: 2.0, r: 'Pollo dos veces'},
  {id: 'P05-CS03', a: 'leche_fortificada_d', f: 14.0, r: 'Dos vasos de leche fortificada por día'}
] AS row
MATCH (p:Paciente {id:'P05'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P05-CS01', cm: 'P05-ALMUERZO', v: 5.0, co: 'SI'}, {c: 'P05-CS02', cm: 'P05-CENA', v: 2.0, co: 'SI'}, {c: 'P05-CS03', cm: 'P05-DESAYUNO', v: 7.0, co: 'SI'},
  {c: 'P05-CS03', cm: 'P05-MERIENDA', v: 7.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P05-H-nivel_hemo', at: 'nivel_hemo', v: 'ALTO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P05-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'BAJO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P05-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P05-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P05-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P05-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0}
] AS row
MATCH (p:Paciente {id:'P05'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P05', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P05'})
MERGE (x:ExposicionSolar {id:'P05-EXP'}) SET x += {id: 'P05-EXP', tiempo_aire_libre_h: 30.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'ALTA', protector_solar: 'SIEMPRE', fototipo: 'III'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);

// ---- P06 · Embarazada de 30 años
// Escenario: NEGATIVO: fuera de alcance
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P06'})
SET p += {id: 'P06', nombre_caso: 'Embarazada de 30 años', escenario: 'NEGATIVO: fuera de alcance', edad: 30, sexo: 'F', estado_fisiologico: 'EMBARAZO', protocolo_especifico: false, suplementos: 'SI', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P06-C1'}) SET c.fecha = '2026-04-02', c.mes = 4
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P06-REG'})
SET r += {id: 'P06-REG', dias_registro: 3.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P06-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P06-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P06-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P06-CENA', m: 'CENA', pr: true}, {id: 'P06-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P06'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P06-CS01', a: 'leche_vaca', f: 7.0, r: 'Leche en el desayuno'}
] AS row
MATCH (p:Paciente {id:'P06'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P06-CS01', cm: 'P06-DESAYUNO', v: 7.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;

// ---- P07 · Declara ser vegano y registra huevos
// Escenario: NEGATIVO: contradicción (ADM-04)
MATCH (pa:PatronAlimentario {codigo:'VEGANO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P07'})
SET p += {id: 'P07', nombre_caso: 'Declara ser vegano y registra huevos', escenario: 'NEGATIVO: contradicción (ADM-04)', edad: 27, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P07-C1'}) SET c.fecha = '2026-06-11', c.mes = 6
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P07-REG'})
SET r += {id: 'P07-REG', dias_registro: 5.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P07-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P07-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P07-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P07-CENA', m: 'CENA', pr: true}, {id: 'P07-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P07'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P07-CS01', a: 'lentejas', f: 3.0, r: 'Lentejas tres veces'}, {id: 'P07-CS02', a: 'huevo', f: 3.0, r: 'Huevos tres veces'}
] AS row
MATCH (p:Paciente {id:'P07'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P07-CS01', cm: 'P07-ALMUERZO', v: 3.0, co: 'SI'}, {c: 'P07-CS02', cm: 'P07-DESAYUNO', v: 3.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;

// ---- P08 · Registro de un solo día ordinario
// Escenario: DIFUSO ADM: calidad BAJA → G-06
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P08'})
SET p += {id: 'P08', nombre_caso: 'Registro de un solo día ordinario', escenario: 'DIFUSO ADM: calidad BAJA → G-06', edad: 40, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P08-C1'}) SET c.fecha = '2026-09-15', c.mes = 9
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P08-REG'})
SET r += {id: 'P08-REG', dias_registro: 1.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: false, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P08-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P08-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P08-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P08-CENA', m: 'CENA', pr: true}, {id: 'P08-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P08'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P08-CS01', a: 'carne_vacuna', f: 7.0, r: 'Ese día comí carne'}, {id: 'P08-CS02', a: 'leche_vaca', f: 7.0, r: 'Leche en el desayuno'}
] AS row
MATCH (p:Paciente {id:'P08'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P08-CS01', cm: 'P08-ALMUERZO', v: 7.0, co: 'SI'}, {c: 'P08-CS02', cm: 'P08-DESAYUNO', v: 7.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P08-H-nivel_hemo', at: 'nivel_hemo', v: 'ALTO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P08-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'BAJO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P08-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P08-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P08-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P08-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0}
] AS row
MATCH (p:Paciente {id:'P08'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P08', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);

// ---- P09 · Ovolactovegetariano con ingesta intermedia (Nuñez caso B / Santibañez caso B)
// Escenario: DIFUSO: zona gris en B12 y FE; VD alto provisional
MATCH (pa:PatronAlimentario {codigo:'OVOLACTOVEGETARIANO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P09'})
SET p += {id: 'P09', nombre_caso: 'Ovolactovegetariano con ingesta intermedia (Nuñez caso B / Santibañez caso B)', escenario: 'DIFUSO: zona gris en B12 y FE; VD alto provisional', edad: 34, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P09-C1'}) SET c.fecha = '2026-05-19', c.mes = 5
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P09-REG'})
SET r += {id: 'P09-REG', dias_registro: 4.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false, totales_diarios_ca: [369.1, 467.6, 413.4, 482.4]}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P09-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P09-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P09-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P09-CENA', m: 'CENA', pr: true}, {id: 'P09-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P09'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P09-CS01', a: 'leche_vaca', f: 7.0, r: 'Leche en el desayuno'}, {id: 'P09-CS02', a: 'huevo', f: 7.0, r: 'Un huevo por día'},
  {id: 'P09-CS03', a: 'queso', f: 3.5, r: 'Queso día por medio'}, {id: 'P09-CS04', a: 'lentejas', f: 3.0, r: 'Lentejas tres veces'},
  {id: 'P09-CS05', a: 'te', f: 7.0, r: 'Té con el desayuno'}, {id: 'P09-CS06', a: 'cafe', f: 6.0, r: 'Café a media mañana y a veces después de almorzar'}
] AS row
MATCH (p:Paciente {id:'P09'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P09-CS01', cm: 'P09-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P09-CS02', cm: 'P09-CENA', v: 7.0, co: 'SI'}, {c: 'P09-CS03', cm: 'P09-MERIENDA', v: 3.5, co: 'SI'},
  {c: 'P09-CS04', cm: 'P09-ALMUERZO', v: 3.0, co: 'SI'}, {c: 'P09-CS05', cm: 'P09-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P09-CS06', cm: 'P09-ALMUERZO', v: 1.0, co: 'SI'},
  {c: 'P09-CS06', cm: 'P09-MEDIA_MANANA', v: 5.0, co: 'NO'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P09-H-nivel_hemo', at: 'nivel_hemo', v: 'NULO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P09-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'MEDIO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P09-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P09-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P09-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P09-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0}
] AS row
MATCH (p:Paciente {id:'P09'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P09', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P09'})
MERGE (x:ExposicionSolar {id:'P09-EXP'}) SET x += {id: 'P09-EXP', tiempo_aire_libre_h: 3.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'MEDIA', protector_solar: 'A_VECES', fototipo: 'III'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);

// ---- P10 · Omnívoro de 52 años con gastritis atrófica
// Escenario: NEGATIVO específico (G-12, Q5)
MATCH (pa:PatronAlimentario {codigo:'OMNIVORO'}), (l:Localidad {nombre:'Mendoza'}), (nut:Usuario {id:'NUT-01'})
MERGE (p:Paciente {id:'P10'})
SET p += {id: 'P10', nombre_caso: 'Omnívoro de 52 años con gastritis atrófica', escenario: 'NEGATIVO específico (G-12, Q5)', edad: 52, sexo: 'M', estado_fisiologico: 'NINGUNO', protocolo_especifico: false, suplementos: 'NO', consulta_antecedentes: 'COMPLETA'}
MERGE (p)-[:SIGUE]->(pa)
MERGE (p)-[:RESIDE_EN]->(l)
MERGE (nut)-[:MONITOREA]->(p)
MERGE (c:Consulta {id:'P10-C1'}) SET c.fecha = '2026-10-07', c.mes = 10
MERGE (p)-[:TIENE_CONSULTA]->(c)
MERGE (c)-[:ATENDIDA_POR]->(nut)
MERGE (r:RegistroAlimentario {id:'P10-REG'})
SET r += {id: 'P10-REG', dias_registro: 7.0, estado_dias: 'CONOCIDO', comidas_principales: 4.0, estado_comidas: 'CONOCIDO', incluye_habil: true, incluye_finde: true, relevamiento_cerrado: 'SI', dia_atipico_unico: false, sin_frecuencias: false, comida_aislada: false, totales_diarios_ca: [356.7, 440.8, 394.5, 453.4, 369.3, 432.4, 402.9]}
MERGE (p)-[:APORTA_REGISTRO]->(r);
UNWIND [
  {id: 'P10-DESAYUNO', m: 'DESAYUNO', pr: true}, {id: 'P10-ALMUERZO', m: 'ALMUERZO', pr: true}, {id: 'P10-MERIENDA', m: 'MERIENDA', pr: true},
  {id: 'P10-CENA', m: 'CENA', pr: true}, {id: 'P10-MEDIA_MANANA', m: 'MEDIA_MANANA', pr: false}
] AS row
MATCH (p:Paciente {id:'P10'})
MERGE (cm:Comida {id: row.id}) SET cm.momento = row.m, cm.principal = row.pr
MERGE (p)-[:TIENE_COMIDA]->(cm);
UNWIND [
  {id: 'P10-CS01', a: 'carne_vacuna', f: 4.0, r: 'Carne cuatro veces'}, {id: 'P10-CS02', a: 'leche_vaca', f: 7.0, r: 'Leche en el desayuno'},
  {id: 'P10-CS03', a: 'yogur', f: 3.0, r: 'Yogur tres veces'}
] AS row
MATCH (p:Paciente {id:'P10'}), (a:Alimento {id: row.a})
MERGE (cs:Consumo {id: row.id}) SET cs.frecuencia_semanal = row.f, cs.estado_frecuencia = 'CONOCIDO', cs.relato = row.r,
  cs.modalidad = 'HABITUAL', cs.periodo = 'semana'
MERGE (p)-[:REGISTRA]->(cs)
MERGE (cs)-[:DE]->(a);
UNWIND [
  {c: 'P10-CS01', cm: 'P10-ALMUERZO', v: 4.0, co: 'SI'}, {c: 'P10-CS02', cm: 'P10-DESAYUNO', v: 7.0, co: 'SI'}, {c: 'P10-CS03', cm: 'P10-MERIENDA', v: 3.0, co: 'SI'}
] AS row
MATCH (cs:Consumo {id: row.c}), (cm:Comida {id: row.cm})
MERGE (cs)-[o:OCURRE_EN]->(cm) SET o.veces_semana = row.v, o.coincide_con_comida = row.co;
UNWIND [
  {id: 'P10-H-nivel_hemo', at: 'nivel_hemo', v: 'ALTO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P10-H-nivel_no_hemo', at: 'nivel_no_hemo', v: 'BAJO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P10-H-potenciadores', at: 'potenciadores', v: 'BAJOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P10-H-suplemento_hierro', at: 'suplemento_hierro', v: 'NO', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P10-H-antecedentes_perdida', at: 'antecedentes_perdida', v: 'DESCARTADOS', f: 'NUTRICIONISTA', ce: 1.0},
  {id: 'P10-H-alarmas', at: 'alarmas', v: 'DESCARTADAS', f: 'NUTRICIONISTA', ce: 1.0}
] AS row
MATCH (p:Paciente {id:'P10'})
MERGE (h:Hecho {id: row.id})
SET h.sujeto = 'P10', h.atributo = row.at, h.valor = row.v, h.fuente = row.f, h.confianza_extraccion = row.ce,
    h.texto_original = coalesce(row.t, ''), h.estado_dato = CASE WHEN row.v = 'DESCONOCIDO' THEN 'DESCONOCIDO' ELSE 'CONOCIDO' END
MERGE (p)-[:TIENE_HECHO]->(h);
MATCH (p:Paciente {id:'P10'}), (c:CondicionDerivacion {codigo:'GASTRITIS_ATROFICA'})
MERGE (p)-[x:PRESENTA]->(c) SET x.estado = 'PRESENTE';
MATCH (p:Paciente {id:'P10'})
MERGE (x:ExposicionSolar {id:'P10-EXP'}) SET x += {id: 'P10-EXP', tiempo_aire_libre_h: 6.0, estado_tiempo: 'CONOCIDO', horario_exposicion: 'DENTRO_UVB', a_traves_de_vidrio: 'NO', cobertura_vestimenta: 'MEDIA', protector_solar: 'NUNCA', fototipo: 'IV'}
MERGE (p)-[:TIENE_HABITO_DE]->(x);
