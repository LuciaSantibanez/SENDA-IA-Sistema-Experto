
// ============================================================================
// 01 · ONTOLOGÍA DEL DOMINIO, FRAMES, REGLAS Y FUENTES DE CONOCIMIENTO
// ============================================================================
// Generado por python/generar_script.py desde carga/*.csv — no editar a mano.

// 1.1 Submódulos y dependencias (PG1 c.2 y c.5)
UNWIND [
  {id: 'SM-ADM', nombre: 'Admisibilidad del caso', responsable: 'Zalazar'}, {id: 'SM-CA', nombre: 'Calcio', responsable: 'Ramirez', nutriente: 'CA'},
  {id: 'SM-FE', nombre: 'Hierro', responsable: 'Santibañez', nutriente: 'FE'}, {id: 'SM-B12', nombre: 'Vitamina B12', responsable: 'Nuñez', nutriente: 'B12'},
  {id: 'SM-VD', nombre: 'Vitamina D', responsable: 'Bataller', nutriente: 'VD'}, {id: 'SM-INT', nombre: 'Resultado consolidado', responsable: 'Grupo'}
] AS row
MERGE (s:Submodulo {id: row.id}) SET s.nombre = row.nombre, s.responsable = row.responsable;
UNWIND [
  {codigo: 'CA', nombre: 'Calcio', unidad: 'mg', formas: []}, {codigo: 'FE', nombre: 'Hierro', unidad: 'mg', formas: ['HEMO', 'NO_HEMO']},
  {codigo: 'B12', nombre: 'Vitamina B12', unidad: 'µg', formas: []}, {codigo: 'VD', nombre: 'Vitamina D', unidad: 'µg', formas: ['D2', 'D3']}
] AS row
MERGE (n:Nutriente {codigo: row.codigo}) SET n.nombre = row.nombre, n.unidad = row.unidad, n.formas = row.formas
WITH n, row MATCH (s:Submodulo {id: 'SM-' + row.codigo}) MERGE (s)-[:EVALUA]->(n);
UNWIND [
  {a: 'SM-CA', b: 'SM-ADM', t: 'SECUENCIAL_CONDICIONAL'}, {a: 'SM-FE', b: 'SM-ADM', t: 'SECUENCIAL_CONDICIONAL'}, {a: 'SM-B12', b: 'SM-ADM', t: 'SECUENCIAL_CONDICIONAL'},
  {a: 'SM-VD', b: 'SM-ADM', t: 'SECUENCIAL_CONDICIONAL'}, {a: 'SM-VD', b: 'SM-CA', t: 'HECHO_COMPARTIDO'}, {a: 'SM-FE', b: 'SM-CA', t: 'INTERACCION_ABSORCION'},
  {a: 'SM-FE', b: 'SM-B12', t: 'HECHO_COMPARTIDO'}, {a: 'SM-ADM', b: 'SM-FE', t: 'BANDERA_SEGURIDAD'}, {a: 'SM-INT', b: 'SM-ADM', t: 'CONDICIONAL'},
  {a: 'SM-INT', b: 'SM-CA', t: 'CONDICIONAL'}, {a: 'SM-INT', b: 'SM-FE', t: 'CONDICIONAL'}, {a: 'SM-INT', b: 'SM-B12', t: 'CONDICIONAL'},
  {a: 'SM-INT', b: 'SM-VD', t: 'CONDICIONAL'}
] AS row
MATCH (a:Submodulo {id: row.a}), (b:Submodulo {id: row.b}) MERGE (a)-[d:DEPENDE_DE]->(b) SET d.tipo = row.t;
// Relaciones entre nutrientes que conectan submódulos (H12 de PG1)
MATCH (vd:Nutriente {codigo:'VD'}), (ca:Nutriente {codigo:'CA'}), (fe:Nutriente {codigo:'FE'})
MERGE (vd)-[:FAVORECE_ABSORCION]->(ca)
MERGE (ca)-[i:INHIBE_ABSORCION]->(fe) SET i.forma = 'NO_HEMO', i.regla = 'FE-11';

// 1.2 Estados de salida (PG0 / H9: único vocabulario de salida)
UNWIND [
  {codigo: 'FUERA_DE_ALCANCE', prioridad: 4}, {codigo: 'POSIBLE_INGESTA_INSUFICIENTE', prioridad: 3},
  {codigo: 'INFORMACION_INSUFICIENTE', prioridad: 2}, {codigo: 'SIN_SEÑAL_DETECTADA', prioridad: 1}
] AS row
MERGE (e:Estado {codigo: row.codigo}) SET e.prioridad = row.prioridad;

// 1.3 Usuarios y actores
MERGE (n:Usuario:Nutricionista {id:'NUT-01'}) SET n.rol = 'NUTRICIONISTA', n.nombre = 'Nutricionista entrevistada'
MERGE (m:Usuario:Medico {id:'MED-01'}) SET m.rol = 'MEDICO', m.nombre = 'Médico de referencia';

// 1.4 Patrones alimentarios: jerarquía ES_UN, exclusiones y fuentes alternativas (F-PatronAlimentario)
UNWIND [
  {codigo: 'BEBIDAS_VEGETALES'}, {codigo: 'CARNES'}, {codigo: 'CEREALES'}, {codigo: 'FRUTAS'}, {codigo: 'HOJAS_VERDES'}, {codigo: 'HUEVOS'},
  {codigo: 'INFUSIONES'}, {codigo: 'LACTEOS'}, {codigo: 'LEGUMBRES'}, {codigo: 'PESCADOS'}
] AS row
MERGE (:GrupoAlimento {codigo: row.codigo});
UNWIND [
  {codigo: 'PATRON'}, {codigo: 'OMNIVORO', padre: 'PATRON'}, {codigo: 'PESCETARIANO', padre: 'PATRON'},
  {codigo: 'VEGETARIANO', padre: 'PATRON'}, {codigo: 'OVOLACTOVEGETARIANO', padre: 'VEGETARIANO'}, {codigo: 'VEGANO', padre: 'VEGETARIANO'}
] AS row
MERGE (p:PatronAlimentario {codigo: row.codigo});
UNWIND [
  {codigo: 'OMNIVORO', padre: 'PATRON'}, {codigo: 'PESCETARIANO', padre: 'PATRON'}, {codigo: 'VEGETARIANO', padre: 'PATRON'},
  {codigo: 'OVOLACTOVEGETARIANO', padre: 'VEGETARIANO'}, {codigo: 'VEGANO', padre: 'VEGETARIANO'}
] AS row
MATCH (h:PatronAlimentario {codigo: row.codigo}), (p:PatronAlimentario {codigo: row.padre}) MERGE (h)-[:ES_UN]->(p);
UNWIND [
  {p: 'PESCETARIANO', g: 'CARNES'}, {p: 'VEGETARIANO', g: 'CARNES'}, {p: 'VEGETARIANO', g: 'PESCADOS'},
  {p: 'VEGANO', g: 'HUEVOS'}, {p: 'VEGANO', g: 'LACTEOS'}
] AS row
MATCH (p:PatronAlimentario {codigo: row.p}), (g:GrupoAlimento {codigo: row.g}) MERGE (p)-[:EXCLUYE]->(g);
UNWIND [
  {p: 'VEGETARIANO', n: 'FE', r: 'FE-01'}, {p: 'VEGANO', n: 'B12', r: 'R05'},
  {p: 'VEGANO', n: 'CA', r: 'CA-01'}, {p: 'VEGANO', n: 'VD', r: 'R14'}
] AS row
MATCH (p:PatronAlimentario {codigo: row.p}), (n:Nutriente {codigo: row.n})
MERGE (p)-[x:REQUIERE_FUENTE_ALTERNATIVA]->(n) SET x.regla = row.r;
UNWIND [
  {g: 'CARNES', n: 'FE', f: 'HEMO'}, {g: 'PESCADOS', n: 'FE', f: 'HEMO'}, {g: 'LEGUMBRES', n: 'FE', f: 'NO_HEMO'},
  {g: 'HOJAS_VERDES', n: 'FE', f: 'NO_HEMO'}, {g: 'LACTEOS', n: 'CA', f: ''}, {g: 'BEBIDAS_VEGETALES', n: 'CA', f: 'SI_FORTIFICADA'},
  {g: 'CARNES', n: 'B12', f: ''}, {g: 'PESCADOS', n: 'B12', f: ''}, {g: 'HUEVOS', n: 'B12', f: ''},
  {g: 'LACTEOS', n: 'B12', f: ''}, {g: 'PESCADOS', n: 'VD', f: ''}, {g: 'HUEVOS', n: 'VD', f: ''}
] AS row
MATCH (g:GrupoAlimento {codigo: row.g}), (n:Nutriente {codigo: row.n})
MERGE (g)-[x:FUENTE_DE]->(n) SET x.forma = row.f;

// 1.5 Alimentos, aportes por porción y declaraciones de rótulo (fortificado = rol, H6)
UNWIND [
  {id: 'carne_vacuna', nombre: 'Carne vacuna', grupo: 'CARNES', origen: 'ANIMAL', porcion: '100 g', fortificado: false}, {id: 'pollo', nombre: 'Pollo', grupo: 'CARNES', origen: 'ANIMAL', porcion: '100 g', fortificado: false},
  {id: 'pescado_graso', nombre: 'Pescado graso (salmón / caballa)', grupo: 'PESCADOS', origen: 'ANIMAL', porcion: '100 g', fortificado: false}, {id: 'huevo', nombre: 'Huevo', grupo: 'HUEVOS', origen: 'ANIMAL', porcion: '1 unidad (50 g)', fortificado: false},
  {id: 'leche_vaca', nombre: 'Leche de vaca', grupo: 'LACTEOS', origen: 'ANIMAL', porcion: '250 ml', fortificado: false}, {id: 'leche_fortificada_d', nombre: 'Leche fortificada con vitamina D', grupo: 'LACTEOS', origen: 'ANIMAL', porcion: '250 ml', fortificado: true},
  {id: 'yogur', nombre: 'Yogur', grupo: 'LACTEOS', origen: 'ANIMAL', porcion: '200 g', fortificado: false}, {id: 'queso', nombre: 'Queso', grupo: 'LACTEOS', origen: 'ANIMAL', porcion: '30 g', fortificado: false},
  {id: 'lentejas', nombre: 'Lentejas cocidas', grupo: 'LEGUMBRES', origen: 'VEGETAL', porcion: '100 g', fortificado: false}, {id: 'garbanzos', nombre: 'Garbanzos cocidos', grupo: 'LEGUMBRES', origen: 'VEGETAL', porcion: '100 g', fortificado: false},
  {id: 'espinaca', nombre: 'Espinaca cocida', grupo: 'HOJAS_VERDES', origen: 'VEGETAL', porcion: '100 g', fortificado: false}, {id: 'naranja', nombre: 'Naranja / cítricos', grupo: 'FRUTAS', origen: 'VEGETAL', porcion: '1 unidad', fortificado: false},
  {id: 'mate', nombre: 'Mate', grupo: 'INFUSIONES', origen: 'VEGETAL', porcion: '1 toma', fortificado: false}, {id: 'te', nombre: 'Té', grupo: 'INFUSIONES', origen: 'VEGETAL', porcion: '1 taza', fortificado: false},
  {id: 'cafe', nombre: 'Café', grupo: 'INFUSIONES', origen: 'VEGETAL', porcion: '1 taza', fortificado: false}, {id: 'bebida_almendras_desc', nombre: 'Bebida de almendras (marca desconocida)', grupo: 'BEBIDAS_VEGETALES', origen: 'VEGETAL', porcion: '200 ml', fortificado: true},
  {id: 'bebida_soja_fort', nombre: 'Bebida de soja fortificada (rótulo verificado)', grupo: 'BEBIDAS_VEGETALES', origen: 'VEGETAL', porcion: '200 ml', fortificado: true}, {id: 'pan', nombre: 'Pan / harinas', grupo: 'CEREALES', origen: 'VEGETAL', porcion: '50 g', fortificado: false}
] AS row
MERGE (a:Alimento:Fuente {id: row.id})
SET a.nombre = row.nombre, a.origen = row.origen, a.porcion = row.porcion
WITH a, row MATCH (g:GrupoAlimento {codigo: row.grupo}) MERGE (a)-[:PERTENECE_A]->(g);
MATCH (a:Alimento) WHERE a.id IN ['leche_fortificada_d', 'bebida_almendras_desc', 'bebida_soja_fort'] SET a:Fortificado;
UNWIND [
  {a: 'carne_vacuna', n: 'FE', c: 2.6, u: 'mg', f: 'HEMO', b: 'ALTA'}, {a: 'carne_vacuna', n: 'B12', c: 2.0, u: 'µg', b: 'ALTA'}, {a: 'pollo', n: 'FE', c: 1.0, u: 'mg', f: 'HEMO', b: 'ALTA'},
  {a: 'pollo', n: 'B12', c: 0.3, u: 'µg', b: 'ALTA'}, {a: 'pescado_graso', n: 'VD', c: 13.0, u: 'µg', f: 'D3', b: 'ALTA'}, {a: 'pescado_graso', n: 'B12', c: 3.0, u: 'µg', b: 'ALTA'},
  {a: 'huevo', n: 'B12', c: 0.5, u: 'µg', b: 'ALTA'}, {a: 'huevo', n: 'VD', c: 1.1, u: 'µg', f: 'D3', b: 'ALTA'}, {a: 'huevo', n: 'FE', c: 0.9, u: 'mg', f: 'NO_HEMO', b: 'MEDIA'},
  {a: 'huevo', n: 'CA', c: 25, u: 'mg', b: 'ALTA'}, {a: 'leche_vaca', n: 'CA', c: 300, u: 'mg', b: 'ALTA'}, {a: 'leche_vaca', n: 'B12', c: 1.2, u: 'µg', b: 'ALTA'},
  {a: 'yogur', n: 'CA', c: 250, u: 'mg', b: 'ALTA'}, {a: 'yogur', n: 'B12', c: 0.9, u: 'µg', b: 'ALTA'}, {a: 'queso', n: 'CA', c: 200, u: 'mg', b: 'ALTA'},
  {a: 'queso', n: 'B12', c: 0.4, u: 'µg', b: 'ALTA'}, {a: 'lentejas', n: 'FE', c: 3.3, u: 'mg', f: 'NO_HEMO', b: 'VARIABLE'}, {a: 'lentejas', n: 'CA', c: 19, u: 'mg', b: 'MEDIA'},
  {a: 'garbanzos', n: 'FE', c: 2.9, u: 'mg', f: 'NO_HEMO', b: 'VARIABLE'}, {a: 'garbanzos', n: 'CA', c: 49, u: 'mg', b: 'MEDIA'}, {a: 'espinaca', n: 'CA', c: 136, u: 'mg', b: 'BAJA'},
  {a: 'espinaca', n: 'FE', c: 3.6, u: 'mg', f: 'NO_HEMO', b: 'VARIABLE'}
] AS row
MATCH (a:Alimento {id: row.a}), (n:Nutriente {codigo: row.n})
MERGE (a)-[x:APORTA]->(n) SET x.cantidad = row.c, x.unidad = row.u, x.forma = coalesce(row.f, ''), x.biodisponibilidad = row.b;
UNWIND [
  {a: 'leche_fortificada_d', n: 'CA', v: 'SI', c: 300, u: 'mg'}, {a: 'leche_fortificada_d', n: 'B12', v: 'SI', c: 1.2, u: 'µg'}, {a: 'leche_fortificada_d', n: 'VD', v: 'SI', c: 1.5, u: 'µg'},
  {a: 'bebida_almendras_desc', n: 'CA', v: 'DESCONOCIDO', u: 'mg'}, {a: 'bebida_almendras_desc', n: 'B12', v: 'DESCONOCIDO', u: 'µg'}, {a: 'bebida_almendras_desc', n: 'VD', v: 'DESCONOCIDO', u: 'µg'},
  {a: 'bebida_soja_fort', n: 'CA', v: 'SI', c: 240, u: 'mg'}, {a: 'bebida_soja_fort', n: 'VD', v: 'SI', c: 1.5, u: 'µg'}, {a: 'bebida_soja_fort', n: 'B12', v: 'NO', u: 'µg'}
] AS row
MATCH (a:Alimento {id: row.a}), (n:Nutriente {codigo: row.n})
MERGE (a)-[x:DECLARA]->(n) SET x.valor = row.v, x.unidad = row.u, x.contenido = row.c;

// 1.6 Factores modificadores (medicamentos, inhibidores, potenciadores)
UNWIND [
  {c: 'IBP', nom: 'Inhibidores de la bomba de protones (omeprazol)', cl: 'MEDICAMENTO'}, {c: 'METFORMINA', nom: 'Metformina', cl: 'MEDICAMENTO'}, {c: 'ANTICONVULSIVANTE', nom: 'Anticonvulsivantes', cl: 'MEDICAMENTO'},
  {c: 'GLUCOCORTICOIDE', nom: 'Glucocorticoides', cl: 'MEDICAMENTO'}, {c: 'POLIFENOLES', nom: 'Polifenoles de mate / té / café', cl: 'INHIBIDOR'}, {c: 'CALCIO_COMIDA', nom: 'Calcio tomado con las comidas', cl: 'INHIBIDOR'},
  {c: 'VITAMINA_C', nom: 'Vitamina C (cítricos)', cl: 'POTENCIADOR'}
] AS row
MERGE (f:FactorModificador {codigo: row.c}) SET f.nombre = row.nom, f.clase = row.cl;
MATCH (f:FactorModificador {clase:'MEDICAMENTO'}) SET f:Medicamento;
MATCH (f:FactorModificador {clase:'INHIBIDOR'}) SET f:Inhibidor;
MATCH (f:FactorModificador {clase:'POTENCIADOR'}) SET f:Potenciador;
UNWIND [
  {c: 'IBP', n: 'B12', e: 'REDUCE_ABSORCION', f: ''}, {c: 'IBP', n: 'FE', e: 'REDUCE_ABSORCION', f: ''}, {c: 'METFORMINA', n: 'B12', e: 'REDUCE_ABSORCION', f: ''},
  {c: 'ANTICONVULSIVANTE', n: 'VD', e: 'REDUCE_ABSORCION', f: ''}, {c: 'GLUCOCORTICOIDE', n: 'VD', e: 'REDUCE_ABSORCION', f: ''}, {c: 'POLIFENOLES', n: 'FE', e: 'REDUCE_ABSORCION', f: 'NO_HEMO'},
  {c: 'CALCIO_COMIDA', n: 'FE', e: 'REDUCE_ABSORCION', f: 'NO_HEMO'}
] AS row
MATCH (f:FactorModificador {codigo: row.c}), (n:Nutriente {codigo: row.n})
MERGE (f)-[x:REDUCE_ABSORCION]->(n) SET x.forma = row.f;
UNWIND [
  {c: 'VITAMINA_C', n: 'FE', e: 'FAVORECE_ABSORCION', f: 'NO_HEMO'}
] AS row
MATCH (f:FactorModificador {codigo: row.c}), (n:Nutriente {codigo: row.n})
MERGE (f)-[x:FAVORECE_ABSORCION]->(n) SET x.forma = row.f;
UNWIND [
  {a: 'naranja', f: 'VITAMINA_C'}, {a: 'mate', f: 'POLIFENOLES'}, {a: 'te', f: 'POLIFENOLES'},
  {a: 'cafe', f: 'POLIFENOLES'}
] AS row
MATCH (a:Alimento {id: row.a}), (f:FactorModificador {codigo: row.f}) MERGE (a)-[:CONTIENE_FACTOR]->(f);

// 1.7 Fuentes no confiables (relativas al nutriente, G-09)
UNWIND [
  {c: 'ESPIRULINA', nom: 'Espirulina', n: 'B12', m: 'FORMA_INACTIVA'}, {c: 'ALGA', nom: 'Algas', n: 'B12', m: 'FORMA_INACTIVA'},
  {c: 'TEMPEH', nom: 'Tempeh', n: 'B12', m: 'FORMA_INACTIVA'}, {c: 'PAN_HARINA', nom: 'Pan y harinas', n: 'B12', m: 'NO_FORTIFICADA'},
  {c: 'SOL_TRAS_VIDRIO', nom: 'Sol a través del vidrio', n: 'VD', m: 'UVB_BLOQUEADA'}, {c: 'HONGO_SIN_UV', nom: 'Hongos sin declaración de vitamina D', n: 'VD', m: 'SIN_DECLARACION'}
] AS row
MERGE (f:FuenteNoConfiable {codigo: row.c}) SET f.nombre = row.nom
WITH f, row MATCH (n:Nutriente {codigo: row.n}) MERGE (f)-[x:NO_APORTA]->(n) SET x.motivo = row.m;

// 1.8 Catálogo de derivación (Q4) y criterios de alcance (ADM-01)
UNWIND [
  {c: 'SANGRADO_DIGESTIVO', nom: 'Sangrado digestivo', t: 'SINTOMA', a: 'GENERAL', v: 'VALIDADA'}, {c: 'PERDIDA_PESO_INVOLUNTARIA', nom: 'Pérdida de peso involuntaria importante', t: 'SINTOMA', a: 'GENERAL', v: 'VALIDADA'},
  {c: 'DESMAYO_DEBILIDAD_INTENSA', nom: 'Desmayos o debilidad intensa', t: 'SINTOMA', a: 'GENERAL', v: 'VALIDADA'}, {c: 'SINTOMAS_NEUROLOGICOS', nom: 'Síntomas neurológicos', t: 'SINTOMA', a: 'GENERAL', v: 'VALIDADA'},
  {c: 'ANEMIA_CONOCIDA', nom: 'Anemia conocida (incluye anemia perniciosa)', t: 'ANTECEDENTE_DX', a: 'GENERAL', v: 'VALIDADA'}, {c: 'CELIAQUIA_NO_CONTROLADA', nom: 'Sospecha de celiaquía sin diagnóstico o sin tratamiento', t: 'ANTECEDENTE_DX', a: 'GENERAL', v: 'VALIDADA'},
  {c: 'CIRUGIA_BARIATRICA', nom: 'Cirugía bariátrica', t: 'ANTECEDENTE_DX', a: 'GENERAL', v: 'VALIDADA'}, {c: 'ENF_MALABSORTIVA', nom: 'Enfermedad malabsortiva', t: 'ANTECEDENTE_DX', a: 'GENERAL', v: 'VALIDADA'},
  {c: 'GASTRITIS_ATROFICA', nom: 'Gastritis atrófica diagnosticada', t: 'ANTECEDENTE_DX', a: 'ESPECIFICA', n: 'B12', v: 'CANDIDATA'}, {c: 'OSTEOMALACIA', nom: 'Osteomalacia', t: 'ANTECEDENTE_DX', a: 'ESPECIFICA', n: 'VD', v: 'CANDIDATA'},
  {c: 'HIPO_HIPERCALCEMIA', nom: 'Hipo o hipercalcemia', t: 'ANTECEDENTE_DX', a: 'ESPECIFICA', n: 'VD', v: 'CANDIDATA'}, {c: 'ENF_RENAL_CRONICA', nom: 'Enfermedad renal crónica', t: 'ANTECEDENTE_DX', a: 'ESPECIFICA', n: 'VD', v: 'CANDIDATA'},
  {c: 'ENF_HEPATICA_CRONICA', nom: 'Enfermedad hepática crónica', t: 'ANTECEDENTE_DX', a: 'ESPECIFICA', n: 'VD', v: 'CANDIDATA'}
] AS row
MERGE (c:CondicionDerivacion {codigo: row.c})
SET c.nombre = row.nom, c.tipo = row.t, c.alcance = row.a, c.estado_validacion = row.v, c.en_catalogo = true
WITH c, row WHERE row.n IS NOT NULL
MATCH (n:Nutriente {codigo: row.n}) MERGE (c)-[:AFECTA_A]->(n);
UNWIND [
  {c: 'EDAD_FUERA_DE_RANGO', d: 'Edad menor de 18 o mayor de 64 años'}, {c: 'EMBARAZO', d: 'Embarazo'},
  {c: 'LACTANCIA', d: 'Lactancia'}, {c: 'PROTOCOLO_ESPECIFICO', d: 'Caso con protocolo clínico propio'}
] AS row
MERGE (c:CriterioAlcance {codigo: row.c}) SET c.descripcion = row.d;

// 1.9 Valores de referencia (NIH ODS; Q10: prioridad a referencias argentinas cuando existan)
UNWIND [
  {id: 'REF-CA-18', n: 'CA', emin: 18, emax: 18, s: 'AMBOS', v: 1300, u: 'mg', ul: 3000, f: 'NIH_ODS'}, {id: 'REF-CA-19-50', n: 'CA', emin: 19, emax: 50, s: 'AMBOS', v: 1000, u: 'mg', ul: 2500, f: 'NIH_ODS'},
  {id: 'REF-CA-51-F', n: 'CA', emin: 51, emax: 64, s: 'F', v: 1200, u: 'mg', ul: 2000, f: 'NIH_ODS'}, {id: 'REF-CA-51-M', n: 'CA', emin: 51, emax: 64, s: 'M', v: 1000, u: 'mg', ul: 2000, f: 'NIH_ODS'},
  {id: 'REF-FE-18-F', n: 'FE', emin: 18, emax: 18, s: 'F', v: 15, u: 'mg', ul: 45, f: 'NIH_ODS'}, {id: 'REF-FE-18-M', n: 'FE', emin: 18, emax: 18, s: 'M', v: 11, u: 'mg', ul: 45, f: 'NIH_ODS'},
  {id: 'REF-FE-19-50-F', n: 'FE', emin: 19, emax: 50, s: 'F', v: 18, u: 'mg', ul: 45, f: 'NIH_ODS'}, {id: 'REF-FE-19-50-M', n: 'FE', emin: 19, emax: 50, s: 'M', v: 8, u: 'mg', ul: 45, f: 'NIH_ODS'},
  {id: 'REF-FE-51', n: 'FE', emin: 51, emax: 64, s: 'AMBOS', v: 8, u: 'mg', ul: 45, f: 'NIH_ODS'}, {id: 'REF-B12', n: 'B12', emin: 18, emax: 64, s: 'AMBOS', v: 2.4, u: 'µg', f: 'NIH_ODS'},
  {id: 'REF-VD', n: 'VD', emin: 18, emax: 64, s: 'AMBOS', v: 15, u: 'µg', ul: 100, f: 'NIH_ODS'}
] AS row
MERGE (vr:ValorReferencia {id: row.id})
SET vr.edad_min = row.emin, vr.edad_max = row.emax, vr.sexo = row.s, vr.valor = row.v, vr.unidad = row.u,
    vr.limite_superior = row.ul, vr.fuente = row.f, vr.estado = 'VIGENTE_PROVISORIA'
WITH vr, row MATCH (n:Nutriente {codigo: row.n}) MERGE (n)-[:TIENE_REFERENCIA]->(vr);

// 1.10 Fuentes de conocimiento y preguntas validadas con la experta
UNWIND [
  {id: 'NIH_ODS', nom: 'NIH Office of Dietary Supplements – fichas de hierro; calcio; B12 y vitamina D', t: 'Documento', a: 'Valores de referencia; límites superiores; interacciones'}, {id: 'IOM', nom: 'Institute of Medicine (1998; 2011) – Dietary Reference Intakes', t: 'Documento', a: 'Base de las referencias de B12; calcio y vitamina D'},
  {id: 'CAA', nom: 'Código Alimentario Argentino (Cap. XVII) y Res. Conjuntas 33/2025 y 38/2025', t: 'Normativa', a: 'Fortificación y rotulado'}, {id: 'LEY_25630', nom: 'Ley 25.630', t: 'Normativa', a: 'Fortificación de harinas con hierro (no B12)'},
  {id: 'GUIAS_AR', nom: 'Guías Alimentarias para la Población Argentina (2016)', t: 'Documento', a: 'Porciones de referencia local'}, {id: 'NCI_24H', nom: 'National Cancer Institute – 24-hour Dietary Recall', t: 'Documento', a: 'Variación entre días del registro'},
  {id: 'WATANABE', nom: 'Watanabe et al. (2014)', t: 'Artículo', a: 'Análogos inactivos de B12 en algas y espirulina'}, {id: 'WEBB_HOLICK', nom: 'Webb; Kline y Holick (1988); Holick (2007); Webb y Engelsen (2006)', t: 'Artículo', a: 'Estación; latitud; piel y síntesis cutánea'},
  {id: 'MELINA', nom: 'Melina; Craig y Levin (2016)', t: 'Artículo', a: 'Dietas vegetarianas: B12; hierro; calcio y vitamina D'}, {id: 'TABLAS', nom: 'USDA FoodData Central / ARGENFOODS', t: 'Base de datos', a: 'Contenido de nutrientes por porción'},
  {id: 'OSTERBERG', nom: 'Osterberg y Blaschke (2005)', t: 'Artículo', a: 'Convención de 80 % de adherencia'}, {id: 'CUESTIONARIO', nom: 'Cuestionario para la nutricionista – SENDA (15/10/2026)', t: 'Experto', a: 'Validación de criterios; umbrales y catálogo'},
  {id: 'PG1', nom: 'Grupo 6 – PG1 Integración conceptual', t: 'Documento del proyecto', a: 'Red; frames y 66 reglas consolidadas'}, {id: 'PI3_ZALAZAR', nom: 'Zalazar – PI3 Admisibilidad', t: 'Documento del proyecto', a: 'Modelo difuso de calidad del registro'},
  {id: 'PI3_RAMIREZ', nom: 'Ramirez – PI3 Calcio', t: 'Documento del proyecto', a: 'Modelo difuso de prioridad de revisión de calcio'}, {id: 'PI3_SANTIBANEZ', nom: 'Santibañez – PI3 Hierro', t: 'Documento del proyecto', a: 'Modelo difuso de riesgo de hierro'},
  {id: 'PI3_NUNEZ', nom: 'Nuñez – PI3 Vitamina B12', t: 'Documento del proyecto', a: 'Modelo difuso de riesgo de B12'}, {id: 'PI3_BATALLER', nom: 'Bataller – PI3 Vitamina D', t: 'Documento del proyecto', a: 'Modelo difuso de riesgo de vitamina D e índice UVB'}
] AS row
MERGE (f:FuenteConocimiento:Documento {id: row.id}) SET f.nombre = row.nom, f.tipo = row.t, f.aporta = row.a;
UNWIND [
  {id: 'Q1', s: 'Antes de evaluar', t: 'Días mínimos de registro', x: 'Mínimo 3 días representativos (ideal 3–7) que incluyan días laborales y fin de semana', i: 'PARAM_MIN_DIAS;MD-ADM;ADM-03'},
  {id: 'Q2', s: 'Antes de evaluar', t: 'Comidas a registrar', x: 'Todas las comidas y bebidas (incluye colaciones; infusiones; fortificados y suplementos) con cantidades y marcas', i: 'MD-ADM;ADM-03'},
  {id: 'Q3', s: 'Antes de evaluar', t: 'Registro corto', x: 'Con pocos días evalúa con más incertidumbre; 3 días variados son una primera aproximación; si son atípicos pide 7', i: 'MD-ADM;ADM-03'},
  {id: 'Q4', s: 'Antes de evaluar', t: 'Condiciones de derivación', x: 'Sangrado digestivo; pérdida de peso involuntaria; desmayos o debilidad intensa; síntomas neurológicos; anemia conocida; sospecha de celiaquía sin diagnóstico o tratamiento; cirugía bariátrica; enfermedad malabsortiva', i: 'ADM-02;CATALOGO_DERIVACION'},
  {id: 'Q5', s: 'Antes de evaluar', t: 'Condición de un solo nutriente', x: 'Evalúa los demás nutrientes; la condición aumenta la necesidad de evaluación médica', i: 'G-12'},
  {id: 'Q6', s: 'Antes de evaluar', t: 'Derivar frente a no atender', x: 'No es lo mismo: al derivado se le explica el motivo y qué llevar; al que excede el alcance se le explica el límite', i: 'ADM-01;ADM-02;META-05'},
  {id: 'Q7', s: 'Antes de evaluar', t: 'Vegano que registra huevos', x: 'Pregunta cómo define su alimentación; no reclasifica sin confirmar', i: 'ADM-04'},
  {id: 'Q8', s: 'Cuándo alertar', t: 'Criterio de ingesta baja', x: 'Porcentaje de la referencia como señal de cribado (no diagnóstico); menos de 70–75 % se marca para revisar', i: 'G-07;PARAM_UMBRAL'},
  {id: 'Q9', s: 'Cuándo alertar', t: 'Bandas de alerta', x: 'Menos de 70 % alerta; 70–90 % revisar contexto; más de 90 % no descarta si hay malabsorción o medicación; validar', i: 'MD-B12;MD-CA;MD-VD'},
  {id: 'Q10', s: 'Cuándo alertar', t: 'Referencias', x: 'Prioriza referencias argentinas; NIH como apoyo', i: 'ValorReferencia'},
  {id: 'Q11', s: 'Cuándo alertar', t: 'Dato esencial faltante', x: 'Informa «faltan datos»; si el resto sugiere riesgo agrega «posible ingesta baja; pendiente de confirmar»', i: 'META-01'},
  {id: 'Q12', s: 'Calcio', t: 'Porciones de lácteos', x: 'Registra porciones diarias y tamaño; 2–3 por día pueden contribuir según cantidades', i: 'CA-01'},
  {id: 'Q13', s: 'Calcio', t: 'Sin lácteos', x: 'Pregunta reemplazos; cantidades; fortificados y etiqueta', i: 'CA-01;CA-02'},
  {id: 'Q14', s: 'Calcio', t: 'Bebida vegetal sin dato', x: 'Pide marca o foto de la etiqueta; no usa un valor genérico', i: 'G-04;CA-04'},
  {id: 'Q15', s: 'Calcio', t: 'Calcio de verduras', x: 'La espinaca aporta calcio de baja biodisponibilidad; la acelga con cautela', i: 'APORTA.biodisponibilidad'},
  {id: 'Q16', s: 'Hierro', t: 'Carne y legumbres', x: 'Carne 0–1 vez por semana puede ser señal para revisar; legumbres 3–7 veces por semana con vitamina C', i: 'FE-01;MD-FE'},
  {id: 'Q17', s: 'Hierro', t: 'Mate y café', x: 'Separarlos 1–2 h de las comidas ricas en hierro', i: 'FE-02;PARAM_MARGEN_INHIBIDOR'},
  {id: 'Q18', s: 'Hierro', t: 'Mate con cítrico', x: 'La vitamina C favorece pero no neutraliza el efecto del mate', i: 'FE-05;FE-07'},
  {id: 'Q19', s: 'Hierro', t: 'Vegano con legumbres y cítricos', x: 'Merece revisar el hierro igual; no se concluye suficiencia por esa combinación', i: 'FE-09'},
  {id: 'Q20', s: 'Hierro', t: 'Menstruación y donación', x: 'Se pregunta; no hay un plazo único', i: 'FE-08'},
  {id: 'Q21', s: 'B12', t: 'Frecuencia de alimentos animales', x: 'Ninguna frecuencia semanal garantiza B12 sin conocer porciones', i: 'B12-20'},
  {id: 'Q22', s: 'B12', t: 'Dosis de suplemento', x: 'No indica dosis sin evaluación profesional', i: 'Alcance'},
  {id: 'Q23', s: 'B12', t: 'Edad y absorción', x: 'El riesgo aumenta con la edad; especialmente después de los 50', i: 'B12-12;PARAM_EDAD_ABSORCION'},
  {id: 'Q24', s: 'Vitamina D', t: 'Horas de sol', x: 'No usa horas como garantía: depende de estación; hora; latitud; pigmentación; edad; ropa y protector', i: 'MD-VD'},
  {id: 'Q25', s: 'Vitamina D', t: 'Horario en Mendoza', x: 'Depende de la estación y del índice UV; no recomienda horario ni sol sin protección', i: 'MD-VD;VD-FZ-06'},
  {id: 'Q26', s: 'Vitamina D', t: 'Sol frente a dieta', x: 'Mucho tiempo al aire libre no garantiza vitamina D suficiente', i: 'VD-14;VD-FZ-02'},
  {id: 'Q27', s: 'Vitamina D', t: 'Ropa larga y protector', x: 'Reducen la síntesis; no se infiere suficiencia por trabajar afuera', i: 'MD-VD'},
  {id: 'Q28', s: 'Suplementos', t: 'Suplemento regular', x: 'Seguir la pauta de forma consistente; «cuando me acuerdo» no permite asumir cobertura', i: 'G-03;MD-B12'},
  {id: 'Q29', s: 'Suplementos', t: 'Omeprazol y metformina', x: 'No hay un umbral exacto de meses; se revisa con el médico', i: 'G-11;PARAM_USO_PROLONGADO'},
  {id: 'CASO_A', s: 'Casos rápidos', t: 'Vegana de 29 años en julio', x: 'Alerta posible de B12 y calcio; revisar hierro; pedir etiqueta de la bebida y registro de 3–7 días', i: 'P01'},
  {id: 'CASO_B', s: 'Casos rápidos', t: 'Mujer de 55 con omeprazol y calcio + D', x: 'No se concluye sin dosis y regularidad; revisar B12 y hierro por el omeprazol', i: 'P03'},
  {id: 'CASO_C', s: 'Casos rápidos', t: 'Vegano con B12 «cuando se acuerda»', x: 'Aporte irregular de B12; preguntar producto; dosis y frecuencia real', i: 'P04'},
  {id: 'CASO_D', s: 'Casos rápidos', t: 'Trabaja al aire libre con ropa larga y protector', x: 'Posible baja ingesta de vitamina D; faltan huevos; fortificados y suplementos; no retirar el protector', i: 'P05'}
] AS row
MERGE (q:PreguntaExperta {id: row.id}) SET q.seccion = row.s, q.tema = row.t, q.sintesis = row.x, q.impacta = split(row.i, ';')
WITH q MATCH (c:FuenteConocimiento {id:'CUESTIONARIO'}) MERGE (q)-[:PARTE_DE]->(c);

// 1.11 Criterios candidatos / parámetros de la experta (F-CriterioCandidato)
UNWIND [
  {n: 'PARAM_MIN_DIAS', v: '3', u: 'días', e: 'VALIDADO', c: 'Ancla del término «parcial» de dias_registro; con menos días la calidad es BAJA y G-06 bloquea lo cuantitativo', q: ['Q1', 'Q3']},
  {n: 'PARAM_UMBRAL_CA', v: '70', u: '% referencia', e: 'CANDIDATO', c: 'G-07 no alerta: PENDIENTE_VALIDACION (META-07)', q: ['Q8', 'Q9']},
  {n: 'PARAM_UMBRAL_FE', v: '70', u: '% referencia', e: 'CANDIDATO', c: 'Reemplazado por MD-FE en la zona gris', q: ['Q8', 'Q9']},
  {n: 'PARAM_UMBRAL_B12', v: '70', u: '% referencia', e: 'CANDIDATO', c: 'Reemplazado por MD-B12 (ingesta_relativa_b12)', q: ['Q8', 'Q9']},
  {n: 'PARAM_UMBRAL_VD', v: '70', u: '% referencia', e: 'CANDIDATO', c: 'Reemplazado por MD-VD (aporte_oral_relativo_vd)', q: ['Q8', 'Q9']},
  {n: 'PARAM_REGULARIDAD_SUPL', v: 'PENDIENTE', u: '% pauta', e: 'CANDIDATO', c: 'Reemplazado por adherencia_suplemento_b12; en VD por aporte promedio', q: ['Q28']},
  {n: 'PARAM_USO_PROLONGADO', v: 'PENDIENTE', u: 'meses', e: 'CANDIDATO', c: 'G-11 emite advertencia provisional', q: ['Q29']},
  {n: 'PARAM_EDAD_ABSORCION', v: '50', u: 'años', e: 'CANDIDATO', c: 'B12-12 y VD-17 emiten advertencia', q: ['Q23']},
  {n: 'PARAM_MARGEN_INHIBIDOR', v: '1-2', u: 'horas', e: 'CANDIDATO', c: 'FE-02 cuenta el inhibidor si coincide con la comida', q: ['Q17']},
  {n: 'PARAM_FREC_ANIMAL', v: '—', u: 'porciones/semana', e: 'RECHAZADO', c: 'B12-20 suspendida: se piden cantidades', q: ['Q21']},
  {n: 'PARAM_TIEMPO_SOL', v: '—', u: 'h/semana', e: 'RECHAZADO', c: 'Reemplazado por el índice exposicion_uvb_efectiva', q: ['Q24']},
  {n: 'PARAM_LATITUD', v: '—', u: 'grados', e: 'RECHAZADO', c: 'Reemplazado por el índice UV mensual de la localidad', q: ['Q25']},
  {n: 'CATALOGO_DERIVACION', v: 'lista Q4', u: '—', e: 'VALIDADO', c: 'ADM-02 deriva con cualquier condición PRESENTE del catálogo', q: ['Q4']},
  {n: 'PARAM_CONFIANZA_EXTRACCION', v: '0.7', u: '0–1', e: 'CANDIDATO', c: 'Hechos con confianza menor se revisan antes de razonar (no es variable difusa)', q: []},
  {n: 'PARAM_FZ_ADM', v: 'ver MD-ADM', u: '—', e: 'CANDIDATO', c: 'Calidad informada como provisional', q: ['Q1', 'Q3']},
  {n: 'PARAM_FZ_CA', v: 'ver MD-CA', u: '—', e: 'CANDIDATO', c: 'Prioridad auxiliar; no asigna estado', q: ['Q9']},
  {n: 'PARAM_FZ_FE', v: 'ver MD-FE', u: '—', e: 'CANDIDATO', c: 'PENDIENTE_VALIDACION si la conclusión depende de la capa', q: []},
  {n: 'PARAM_FZ_B12', v: 'ver MD-B12', u: '—', e: 'CANDIDATO', c: 'PENDIENTE_VALIDACION si la conclusión depende de la capa', q: ['Q9', 'Q28']},
  {n: 'PARAM_FZ_VD', v: 'ver MD-VD', u: '—', e: 'CANDIDATO', c: 'PENDIENTE_VALIDACION si la conclusión depende de la capa', q: ['Q9', 'Q24']},
  {n: 'PARAM_INDICE_UVB_VD', v: 'coeficientes f_piel / f_protector / f_fototipo', u: '—', e: 'CANDIDATO', c: 'Se usan para calcular E', q: ['Q24', 'Q27']},
  {n: 'POLITICA_CORTES_SALIDA', v: '33.5 / 66.5', u: 'índice 0–100', e: 'CANDIDATO', c: 'Etiqueta final de riesgo por rango efectivo del centroide', q: []},
  {n: 'POLITICA_ZONA_MODERADA', v: 'PENDIENTE', u: '—', e: 'CANDIDATO', c: 'Zona moderada: PENDIENTE_VALIDACION (no se elige POSIBLE ni SIN_SEÑAL)', q: ['Q11']},
  {n: 'POLITICA_META_01', v: 'FUERA > POSIBLE > INFO > SIN_SEÑAL', u: '—', e: 'CANDIDATO', c: 'Se aplica como en PG1 hasta validar', q: ['Q11']}
] AS row
MERGE (c:CriterioCandidato {nombre: row.n})
SET c.valor = row.v, c.unidad = row.u, c.estado_validacion = row.e, c.comportamiento_pendiente = row.c
WITH c, row UNWIND row.q AS qid
MATCH (q:PreguntaExperta {id: qid}) MERGE (c)-[:VALIDADO_CON]->(q);
MATCH (n:Nutriente), (c:CriterioCandidato) WHERE c.nombre = 'PARAM_UMBRAL_' + n.codigo
MERGE (n)-[:UMBRAL_ALERTA]->(c);

// 1.12 Reglas crisp consolidadas de PG1 (66) con su estado en PG2
UNWIND [
  {id: 'ADM-01', g: 'ADMISIBILIDAD', en: 'SI edad < 18 ∨ edad > 64 ∨ estado_fisiologico ∈ {EMBARAZO, LACTANCIA} ∨ protocolo_especifico = VERDADERO ENTONCES veredicto = FUERA_DE_ALCANCE; no se abre la vía dietaria. Las edades 18 y 64 quedan dentro (nota de borde).', pr: 'No evaluar casos que el proyecto dejó afuera.', o: 'PG0; Zalazar R-A1; Santibañez R01', m: 'ADM', t: 'Determinística / Contextual', e: 'VIGENTE', c: '', q: []},
  {id: 'ADM-02', g: 'ADMISIBILIDAD', en: 'SI ∃ antecedente de seguridad PRESENTE (malabsorción relevante, cirugía bariátrica, celiaquía no controlada, sangrado digestivo) ∨ ∃ síntoma del catálogo de alarma PRESENTE ∨ un submódulo eleva bandera_revision_seguridad ENTONCES veredicto = DERIVAR; se corta la vía dietaria. La celiaquía controlada con dieta no pertenece al conjunto.', pr: 'No evaluar por dieta lo que hay que derivar.', o: 'Nutricionista y médicos; Zalazar R A2; Nuñez (criterio conservador); Santibañez R02', m: 'ADM', t: 'Determinística', e: 'MODIFICADA', c: 'Catálogo general de derivación validado con la lista de la experta; anemia perniciosa pasa a la categoría general «anemia conocida»', q: ['Q4']},
  {id: 'ADM-03', g: 'ADMISIBILIDAD', en: 'SI el registro es un día atípico sin otros días, o «como de todo» sin frecuencias, o una comida aislada (R-A3a) ∨ días/comidas < PARAM_MIN_DIAS / PARAM_MIN_COMIDAS (R-A3b) ENTONCES veredicto = INFORMACION_INSUFICIENTE; acción «completar registro»', pr: 'No tomar un día raro o un relato vacío como alimentación habitual.', o: 'Zalazar R-A3; doc. SENDA R02', m: 'ADM', t: 'Determinística / Empírica', e: 'MODIFICADA', c: 'Solo corta huecos groseros (día atípico único / «como de todo» / comida aislada); con menos de 3 días el caso es admisible con calidad BAJA (ADM-F) y G-06 bloquea lo cuantitativo', q: ['Q1', 'Q3']},
  {id: 'ADM-04', g: 'ADMISIBILIDAD', en: 'SI el patrón declarado contradice los alimentos o suplementos registrados (ej.: VEGANO ∧ carnes o huevos) ENTONCES veredicto = INFORMACION_INSUFICIENTE; acción «pedir aclaración»; no se evalúa ningún nutriente', pr: 'No elegir arbitrariamente cuál dato es el correcto.', o: 'Zalazar R-A5; doc. SENDA R22', m: 'ADM', t: 'Determinística', e: 'CONFIRMADA', c: 'Se pregunta antes de reclasificar', q: ['Q7']},
  {id: 'ADM-05', g: 'ADMISIBILIDAD', en: 'SI ADM-01, ADM-02, ADM-03 y ADM-04 no cortaron el caso ENTONCES veredicto = ADMISIBLE; habilitar SM-CA, SM-FE, SM-B12 y SM-VD', pr: 'Abrir las evaluaciones por nutriente.', o: 'Zalazar R-A6', m: 'ADM', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'ADM-06', g: 'ADMISIBILIDAD', en: 'SI veredicto = ADMISIBLE ENTONCES calidad_registro ∈{ALTA, MEDIA, BAJA}, calculada a partir de días, comidas, día atípico y huecos DESCONOCIDOS (un hueco de fortificación baja la calidad pero no quita la admisibilidad)', pr: 'Graduar la confianza de las conclusiones.', o: 'Zalazar R-A6 y caso D1', m: 'ADM', t: 'Heurística', e: 'MODIFICADA', c: 'Implementada por el modelo difuso MD-ADM (ADM-F01 a ADM-F06) más topes crisp', q: ['Q1', 'Q2', 'Q3']},
  {id: 'ADM-07', g: 'ADMISIBILIDAD', en: 'SI el único síntoma es inespecífico (cansancio aislado) ∧ no hay antecedente de seguridad ENTONCES no se deriva; el síntoma queda asentado para las evaluaciones', pr: 'Evitar derivaciones por síntomas vagos.', o: 'Zalazar R-A8', m: 'ADM', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-01', g: 'GENERICA', en: 'SI Suplemento.contiene(n) = SI ∧ (dosis ∨ frecuencia) = DESCONOCIDA ∧ fuente_verificada(n) ≠ SI ENTONCES estado(n) = INFORMACION_INSUFICIENTE; dato faltante «dosis / frecuencia del suplemento»', pr: 'No confundir «toma algo» con fuente verificada.', o: 'Doc. SENDA R07; NIH ODS', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-02', g: 'GENERICA', en: 'SI Suplemento.tipo ∈ {MULTIVITAMINICO, CALCIO_D} ∧ contiene(n) = DESCONOCIDO ENTONCES estado(n) = INFORMACION_INSUFICIENTE; dato faltante «composición del suplemento»', pr: 'Evitar suponer el aporte.', o: 'Nutricionista; Nuñez B12-10; Bataller VD-06', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-03', g: 'GENERICA', en: 'SI Suplemento.regularidad ∈ {IRREGULAR, DESCONOCIDA} (≠ PARAM_REGULARIDAD_SUPL) ∧ ninguna otra fuente verificada(n) ENTONCES estado(n) = INFORMACION_INSUFICIENTE; dato faltante «frecuencia concreta / fecha de la última dosis»', pr: 'Formalizar la regularidad vaga.', o: 'Bataller VD-28; Nuñez (PARAM_REGULARIDAD_SUPL)', m: 'Todos', t: 'Determinística / Heurística', e: 'CONFIRMADA', c: '«Cuando me acuerdo» no permite asumir cobertura', q: ['Q28']},
  {id: 'G-04', g: 'GENERICA', en: 'SI ∃ DeclaracionRotulo(producto, n).valor = DESCONOCIDO ∧ fuente_verificada(n) ≠ SI ENTONCES estado(n) = INFORMACION_INSUFICIENTE; dato faltante «ver rótulo»; la fuente no se cuenta como cero ni como suficiente', pr: 'Aplicar DESCONOCIDO ≠ NO.', o: 'Rotulado (CAA); doc. SENDA R09/R21', m: 'CA, B12, VD', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-05', g: 'GENERICA', en: 'SI un dato cuantitativo crítico (cantidad o frecuencia de una fuente) = DESCONOCIDO ∧ no existe otra estimación validada ∧ fuente_verificada(n) ≠ SI ENTONCES estado(n) = INFORMACION_INSUFICIENTE; dato faltante con la pregunta concreta. No se imputa «medio».', pr: 'Pedir el dato en vez de suponerlo.', o: 'Doc. SENDA R03; Santibañez R03–R04', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-06', g: 'GENERICA', en: 'SI calidad_registro = BAJA ∨ aptitud_comparacion = NO (valoración documentada) ENTONCES bloquear las conclusiones cuantitativas (G-07, G-14) y emitir INFORMACION_INSUFICIENTE «ampliar registro»; SI aptitud_comparacion = DESCONOCIDA → solicitar la valoración. Las reglas basadas en negaciones explícitas (R06, FE-03) siguen activas.', pr: 'Evitar falsas alertas y falsos «sin señal» por subregistro.', o: 'Nuñez B12-17; Bataller VD-18', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-07', g: 'GENERICA', en: 'SI ingesta_estimada(n) con alcance TOTAL_REGISTRO < PARAM_UMBRAL(n) ∧ PARAM_UMBRAL(n) VALIDADO ∧ calidad_registro ∈ {ALTA, MEDIA} ∧ aptitud_comparacion = SI ∧ fuente_verificada(n) ≠ SI ENTONCES estado(n) = POSIBLE_INGESTA_INSUFICIENTE. Un subtotal PARCIAL nunca se compara. Si el umbral está PENDIENTE → META-07.', pr: 'Emitir la alerta solo con evidencia completa.', o: 'Doc. SENDA R04; experta', m: 'Todos', t: 'Determinística / Empírica', e: 'MODIFICADA', c: 'PARAM_UMBRAL(n)=70 % de la referencia (CANDIDATO); en FE / B12 / VD la alerta cuantitativa pasa a la capa difusa', q: ['Q8', 'Q9']},
  {id: 'G-08', g: 'GENERICA', en: 'SI fuente_verificada(n) = SI ∧ ninguna regla de estado activada ∧ ninguna regla quedó bloqueada por un criterio PENDIENTE ENTONCES estado(n) = SIN_SEÑAL_DETECTADA. Una regla bloqueada o no disponible no cuenta como falsa (CAL-06).', pr: 'Evitar conclusiones tranquilizadoras por omisión.', o: 'Doc. SENDA R20; Bataller VD 20', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-09', g: 'GENERICA', en: 'SI la fuente declarada es no confiable para n (espirulina, algas, tempeh, pan/harinas → B12; sol tras vidrio, producto u hongo sin declaración → VD; rótulo valor = NO → el nutriente del rótulo) ENTONCES no cuenta como fuente de n; agregar nota explicativa', pr: 'Evitar un falso «sin señal».', o: 'Watanabe 2014; Ley 25.630; NIH', m: 'B12, VD, CA', t: 'Documental / Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-10', g: 'GENERICA', en: 'SI existe evidencia de composición del producto concreto (rótulo o tabla) con nutriente, valor, unidad y base ENTONCES composición VERIFICADA; el consumo se cuantifica solo si además se conocen cantidad y frecuencia; si la frecuencia ≥ PARAM_FREC_FORTIFICADO, fuente_verificada(n) = SI', pr: 'Completar la verificación de fuentes.', o: 'Rotulado; CAA; Nuñez B12-15', m: 'CA, B12, VD', t: 'Documental / Contextual', e: 'VIGENTE', c: '', q: []},
  {id: 'G-11', g: 'GENERICA', en: 'SI Medicamento.afecta ∋ n ∧ uso = SI ∧ tiempo_uso ≥ PARAM_USO_PROLONGADO ENTONCES advertencia(n) «uso prolongado de <fármaco>: sugerir consulta médica» (no cambia el estado; provisional mientras el parámetro esté PENDIENTE)', pr: 'Advertir sin exceder el alcance.', o: 'NIH ODS (interacciones)', m: 'B12, FE, VD', t: 'Documental / Heurística', e: 'CONFIRMADA', c: 'Sin umbral de meses: advertencia provisional', q: ['Q29']},
  {id: 'G-12', g: 'GENERICA', en: 'SI ∃ condición ESPECÍFICA de n PRESENTE (gastritis atrófica o anemia perniciosa diagnosticadas → B12; osteomalacia, hipo/hipercalcemia, enfermedad renal o hepática crónica → VD) ENTONCES estado(n) = FUERA_DE_ALCANCE, motivo = DERIVACION; los demás nutrientes siguen', pr: 'Derivar sin bloquear todo el caso.', o: 'Médicos / nutricionista; NIH', m: 'B12, VD', t: 'Determinística', e: 'CONFIRMADA', c: 'La condición específica no bloquea los otros nutrientes', q: ['Q5']},
  {id: 'G-13', g: 'GENERICA', en: 'SI estado(n) = POSIBLE_INGESTA_INSUFICIENTE ENTONCES agregar aclaración «no es un diagnóstico: el estado corporal no es determinable por el sistema»', pr: 'Que ninguna alerta se lea como diagnóstico.', o: 'Doc. SENDA R16 (generalizada, H14); NIH', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'G-14', g: 'GENERICA', en: 'SI ingesta_estimada(n) con alcance TOTAL_REGISTRO ≥ valor_referencia(n) ∧ calidad_registro ∈ {ALTA, MEDIA} ENTONCES fuente_verificada(n) = SI (tipo DIETARIA). Usa la referencia documental, no el umbral pendiente (supuesto: umbral ≤ referencia).', pr: 'Habilitar «sin señal» por la vía dietaria.', o: 'Nuñez B12-19; Bataller VD-23', m: 'Todos', t: 'Determinística / Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'G-15', g: 'GENERICA', en: 'SI se estima la ingesta de n en un período definido ENTONCES sumar una sola vez cada consumo único cuantificable (por id y clave de origen); alcance = TOTAL_REGISTRO si el relevamiento está cerrado y todo es cuantificable, si no PARCIAL; sin aportes calculables el valor queda DESCONOCIDO (nunca cero salvo ausencia total documentada)', pr: 'Que solo un total completo pueda llevar a una conclusión.', o: 'Ramirez CAL-09 (M05, M06); generalizada', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'CA-01', g: 'CALCIO', en: 'SI consumo_lacteos ∈ {NO, BAJO} ENTONCES investigar fuentes alternativas de calcio (bebidas y alimentos fortificados, tofu con sales de calcio, pescados con espinas, verduras, suplementos)', pr: 'Investigar antes de concluir.', o: 'Doc. SENDA R08; Ramirez PI1', m: 'CA', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'CA-02', g: 'CALCIO', en: 'SI consumo_lacteos = NO ∧ fuentes_alternativas_calcio = DESCONOCIDAS ENTONCES estado(CA) = INFORMACION_INSUFICIENTE', pr: 'No alertar con datos desconocidos.', o: 'Doc. SENDA R09', m: 'CA', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'CA-03', g: 'CALCIO', en: 'SI consumo_lacteos = NO ∧ existen fuentes alternativas verificadas ENTONCES estimar la ingesta total (lácteos + alternativas + fortificados + suplemento) y aplicar G-07 / G-14; nunca alertar solo por ausencia de lácteos', pr: 'Regla prioritaria del submódulo.', o: 'Ramirez CAL-03', m: 'CA', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'CA-04', g: 'CALCIO', en: 'SI consume tofu ∧ (rótulo ∨ coagulante) = DESCONOCIDO ENTONCES no asumir un contenido fijo; dato faltante «tipo de tofu / rótulo»', pr: 'Evitar valores inventados.', o: 'NIH ODS; Ramirez PI1 (caso límite) y PI2 (F05b)', m: 'CA', t: 'Documental / Contextual', e: 'CONFIRMADA', c: 'No se asigna valor genérico a productos de composición variable', q: ['Q14']},
  {id: 'CA-05', g: 'CALCIO', en: 'Referencia de calcio por edad y sexo: 18 años → 1300 mg/día (NIH 14–18); 19–50 → 1000 mg; 51–64 → 1200 mg (mujeres) / 1000 mg (varones)', pr: 'Usar la referencia correcta, incluido el borde de 18 años.', o: 'NIH ODS (citado por Ramirez)', m: 'CA', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'CA-06', g: 'CALCIO', en: 'SI Suplemento.tipo = CALCIO_D ENTONCES el mismo suplemento se evalúa en CA y en VD, cada uno con su dosis declarada', pr: 'No pedir el dato dos veces (META-04).', o: 'PG1 (integración); Ramirez PI1 §1.2', m: 'CA ↔ VD', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-01', g: 'HIERRO', en: 'SI consumo_carnes ∈ {NO, BAJO} ENTONCES investigar fuentes no hemo y fortificados', pr: 'Investigar antes de concluir.', o: 'Doc. SENDA R11', m: 'FE', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-02', g: 'HIERRO', en: 'SI hierro predominante = NO_HEMO ENTONCES evaluar potenciadores e inhibidores en las mismas comidas: un inhibidor cuenta solo si coincide_con_comida = SI; si coincide_con_comida = NO no se usa; si es DESCONOCIDO y puede cambiar la salida → dato faltante (G-05)', pr: 'Evitar alertas por consumo aislado.', o: 'Doc. SENDA R13; Santibañez R05– R06', m: 'FE', t: 'Determinística', e: 'MODIFICADA', c: 'Margen temporal del inhibidor 1–2 h como PARAM_MARGEN_INHIBIDOR (CANDIDATO)', q: ['Q17']},
  {id: 'FE-03', g: 'HIERRO', en: 'SI nivel_hemo = BAJO ∧ nivel_no_hemo = BAJO ∧suplementación.presencia = NO (confirmada) ENTONCES estado(FE) = POSIBLE_INGESTA_INSUFICIENTE con ambas fuentes como evidencia', pr: 'Fundamentar la señal en el patrón completo.', o: 'Santibañez R-Fe-03 / R07', m: 'FE', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-04', g: 'HIERRO', en: 'SI patrón ∈ {VEGANO, VEGETARIANO} ∧ nivel_no_hemo = ALTO ∧ potenciadores = FRECUENTES ENTONCES bloquear una alerta basada solo en la ausencia de hierro hemo', pr: 'Evitar falsos positivos en vegetarianos.', o: 'Santibañez R-Fe-04 / R08', m: 'FE', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-05', g: 'HIERRO', en: 'SI inhibidores = FRECUENTES en comidas con fuente de hierro ∧ potenciadores = BAJOS ENTONCES biodisponibilidad = DESFAVORABLE; agregar evidencia y señal de revisión por absorción (sin puntaje)', pr: 'Considerar la absorción sin inventar pesos.', o: 'Santibañez R-Fe-05 / R09', m: 'FE', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-06', g: 'HIERRO', en: 'SI consumo de ambas fuentes = BAJO ∧ suplementación con indicación profesional ∧ adecuacion_confirmada = SI ENTONCES bloquear la alerta basada solo en ese bajo consumo y explicar la excepción', pr: 'No ignorar una compensación documentada.', o: 'Santibañez R10', m: 'FE', t: 'Contextual', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-07', g: 'HIERRO', en: 'SI nivel_no_hemo = ALTO ∧ potenciadores frecuentes en las mismas comidas ∧ sin inhibidores dominantes ENTONCES biodisponibilidad = FAVORABLE (no afirma suficiencia)', pr: 'No ignorar la coexistencia de inhibidores.', o: 'Santibañez R-Fe-02 / R13', m: 'FE', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-08', g: 'HIERRO', en: 'SI menstruación abundante o donación de sangre informadas ENTONCES registrar fechas y cantidad; si una valoración profesional las considera relevantes → advertencia de mayor requerimiento; si falta esa valoración y puede cambiar la salida → solicitarla (G-05). No se aplica ningún corte de meses.', pr: 'No cuantificar el requerimiento sin validación.', o: 'Santibañez R-Fe 06, R-Fe-08 / R12', m: 'FE', t: 'Contextual', e: 'CONFIRMADA', c: 'No hay plazo único para la donación', q: ['Q20']},
  {id: 'FE-09', g: 'HIERRO', en: 'SI se cumple FE-04 ∧ inhibidores bajos o ausentes ∧antecedentes y alarmas descartados explícitamente ∧ datos críticos completos ENTONCES fuente_verificada(FE) = SI (NO_HEMO) → G-08', pr: 'Formalizar el «sin señal» vegano sin volverlo garantía general.', o: 'Santibañez R11', m: 'FE', t: 'Heurística', e: 'MODIFICADA', c: 'Ya no verifica la fuente: solo marca biodisponibilidad FAVORABLE y agrega advertencia de revisión', q: ['Q19']},
  {id: 'FE-10', g: 'HIERRO', en: 'SI nivel_hemo = ALTO ∧ antecedentes y alarmas descartados explícitamente ∧ datos críticos completos ENTONCES fuente_verificada(FE) = SI (HEMO) → G-08', pr: 'Cubrir el caso típico que no tenía regla.', o: 'Santibañez R14', m: 'FE', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-11', g: 'HIERRO', en: 'SI Suplemento.contiene(CA) ∧ momento_toma = CON_COMIDAS ENTONCES el suplemento cuenta como inhibidor en esa comida (entra en FE-02 / FE-05)', pr: 'Conectar SM CA con SM-FE (nueva en PG1, a validar).', o: 'NIH ODS (hierro y calcio); Ramirez PI1 §1.2', m: 'FE ↔ CA', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'FE-12', g: 'HIERRO', en: 'Referencia de hierro por edad y sexo: 18 años → 15 mg (F) / 11 mg (M) (NIH 14–18); 19–50 → 18 mg (F) / 8 mg (M); 51–64 → 8 mg', pr: 'Usar la referencia correcta.', o: 'NIH ODS; Santibañez F01 (sexo)', m: 'FE', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'R05', g: 'B12', en: 'SI patron_alimentario = VEGANO ENTONCES investigar fortificados y suplementos de B12', pr: 'Impedir concluir solo con «no come carne».', o: 'Doc. SENDA R05; NIH', m: 'B12', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'R06', g: 'B12', en: 'SI patron = VEGANO ∧ fortificados_b12 = NO ∧ suplemento_b12 = NO (negaciones explícitas) ENTONCES estado(B12) = POSIBLE_INGESTA_INSUFICIENTE; fundamento = AUSENCIA_FUENTES', pr: 'Alerta principal de B12.', o: 'Doc. SENDA; Academy of Nutrition and Dietetics', m: 'B12', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'B12-03', g: 'B12', en: 'SI patron = VEGANO ∧ suplemento_b12 = DESCONOCIDO ENTONCES estado(B12) = INFORMACION_INSUFICIENTE; «consultar suplementación»', pr: 'Pedir el dato.', o: 'Nutricionista', m: 'B12', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'B12-07', g: 'B12', en: 'SI (suplemento con B12, dosis conocida ∧ frecuencia ≥ PARAM_REGULARIDAD_SUPL) ∨ (INYECTABLE ∧ indicado_por_medico = SI) ENTONCES fuente_verificada(B12) = SI', pr: 'Verificar la fuente.', o: 'NIH; nutricionista', m: 'B12', t: 'Documental', e: 'MODIFICADA', c: 'Rama oral reemplazada por adherencia_suplemento_b12 (B12-FZ); rama inyectable sin cambios', q: ['Q28']},
  {id: 'B12-18', g: 'B12', en: 'SI patron_alimentario ∈ {DESCONOCIDO, OTRO no clasificable} ENTONCES estado(B12) = INFORMACION_INSUFICIENTE; «aclarar patrón»', pr: 'Pedir el dato.', o: 'Nuñez PI2', m: 'B12', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'B12-20', g: 'B12', en: 'SI no hay cantidades ∧ frecuencia semanal de alimentos animales ≥ PARAM_FREC_ANIMAL ENTONCES fuente_verificada(B12) = SI (ANIMAL)', pr: 'Representar su heurística (parámetro PENDIENTE).', o: 'Nuñez PI2', m: 'B12', t: 'Heurística', e: 'SUSPENDIDA', c: 'La frecuencia sin porciones no permite concluir; se convierte en pedido de cantidades', q: ['Q21']},
  {id: 'B12-12', g: 'B12', en: 'SI edad ≥ PARAM_EDAD_ABSORCION (candidato 50) ∧ la B12 proviene solo de alimentos animales ENTONCES advertencia por menor absorción', pr: 'Advertir sin cambiar el estado.', o: 'NIH ODS', m: 'B12', t: 'Heurística / Contextual', e: 'CONFIRMADA', c: 'El riesgo de menor absorción aumenta con la edad (sobre todo > 50)', q: ['Q23']},
  {id: 'VD-03', g: 'VITAMINA_D', en: 'SI (suplemento con dosis conocida ∧ REGULAR ∧aporte_diario ≥ 15 µg) ∨ F-SuplementoIndicado ENTONCES fuente_verificada(VD) = SI', pr: 'Seguir el orden de la experta.', o: 'NIH; Bataller PI2', m: 'VD', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'VD-04', g: 'VITAMINA_D', en: 'SI aporte_diario(VD) > 100 µg ∧ indicado_por_medico ≠ SI ENTONCES advertencia de posible exceso; sugerir consulta médica', pr: 'Advertir.', o: 'NIH ODS', m: 'VD', t: 'Documental', e: 'VIGENTE', c: '', q: []},
  {id: 'R14', g: 'VITAMINA_D', en: 'SI consumo_fuentes_vitd ∈ {BAJO, DESCONOCIDO} ∧fuente_verificada(VD) ≠ SI ENTONCES estimar ingesta y, si es baja, evaluar exposición solar', pr: 'Encadenamiento.', o: 'Doc. SENDA R14; Bataller PI2', m: 'VD', t: 'Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'VD-11', g: 'VITAMINA_D', en: 'SI (INVIERNO ∧ latitud ≥ PARAM_LATITUD) ∨ tiempo < tiempo_minimo(fototipo) ∨ (protector SIEMPRE ∧ cobertura ALTA) ∨ FUERA_UVB ENTONCES exposicion = LIMITADA', pr: 'Evaluar la vía endógena.', o: 'Webb 1988; Holick 2007; experta', m: 'VD', t: 'Heurística / Contextual', e: 'MODIFICADA', c: 'Clasificación de exposición = etiqueta dominante del índice exposicion_uvb_efectiva', q: ['Q24', 'Q25', 'Q27']},
  {id: 'VD-21', g: 'VITAMINA_D', en: 'SI tiempo ≥ mínimo ∧ DENTRO_UVB ∧ protección no alta ∧¬(invierno ∧ latitud alta) ∧ no vidrio ENTONCES exposicion = ADECUADA', pr: 'Completar la clasificación.', o: 'Bataller PI2 (M7)', m: 'VD', t: 'Heurística', e: 'MODIFICADA', c: 'Idem VD-11 (etiqueta «buena» → ADECUADA)', q: ['Q24']},
  {id: 'VD-22', g: 'VITAMINA_D', en: 'SI la exposición no se clasificó ∧ falta un dato decisivo ENTONCES exposicion = DESCONOCIDA', pr: 'No inventar exposición.', o: 'Bataller PI2 (M8)', m: 'VD', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'VD-12', g: 'VITAMINA_D', en: 'SI ingesta(VD) < umbral ∧ exposicion = DESCONOCIDA ENTONCES estado(VD) = INFORMACION_INSUFICIENTE; «horas al aire libre y horario»', pr: 'Pedir el dato.', o: 'Nutricionista; Bataller PI2', m: 'VD', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'VD-13', g: 'VITAMINA_D', en: 'Especialización de G-07: SI ingesta(VD) < umbral ∧ calidad ∈ {ALTA, MEDIA} ∧ exposicion = LIMITADA ∧ fuente_verificada ≠ SI ENTONCES estado(VD) = POSIBLE_INGESTA_INSUFICIENTE', pr: 'Nunca concluir por la dieta sola.', o: 'Doc. SENDA R15 + Bataller PI2 (M16)', m: 'VD', t: 'Heurística / Contextual', e: 'REEMPLAZADA', c: 'Reemplazada por VD-FZ-01 + VD-FZ-05', q: ['Q8', 'Q9']},
  {id: 'VD-14', g: 'VITAMINA_D', en: 'SI ingesta(VD) < umbral ∧ exposicion = ADECUADA ENTONCES estado(VD) = SIN_SEÑAL_DETECTADA; fundamento = EXPOSICION_ADECUADA', pr: 'Pregunta abierta P5.', o: 'Bataller PI1', m: 'VD', t: 'Heurística (a validar)', e: 'REEMPLAZADA', c: 'Reemplazada por VD-FZ-02: con dieta baja el sol no lleva a SIN_SEÑAL', q: ['Q26']},
  {id: 'VD-25', g: 'VITAMINA_D', en: 'SI se asignó estado(VD) ENTONCES componente_limitante = AMBOS / vía del dato faltante / NINGUNO', pr: 'Explicabilidad.', o: 'Bataller PI2 (M12)', m: 'VD', t: 'Determinística', e: 'MODIFICADA', c: 'Componente limitante tomado de la regla difusa con mayor α', q: []},
  {id: 'VD-15/17', g: 'VITAMINA_D', en: 'SI imc ≥ 30 (VD-15) / edad ≥ 50 (VD-17) ENTONCES advertencia por menor disponibilidad / síntesis (no cambia el estado)', pr: 'Advertir.', o: 'NIH ODS', m: 'VD', t: 'Documental / Heurística', e: 'VIGENTE', c: '', q: []},
  {id: 'VD-27', g: 'VITAMINA_D', en: 'SI exposicion = ADECUADA ∧ estación ∈ {PRIMAVERA, VERANO} ENTONCES advertencia «reevaluar en otoño invierno»', pr: 'No generalizar el verano.', o: 'Bataller PI2 (M15)', m: 'VD', t: 'Contextual', e: 'REEMPLAZADA', c: 'Reemplazada por VD-FZ-06 (proyección invernal)', q: ['Q25']},
  {id: 'META-01', g: 'CONTROL', en: 'SI hay más de una regla de estado activa para n ENTONCES estado(n) = el de mayor prioridad: FUERA_DE_ALCANCE > POSIBLE_INGESTA_INSUFICIENTE > INFORMACION_INSUFICIENTE > SIN_SEÑAL_DETECTADA; se conservan todos los datos faltantes. Las reglas de fuente verificada se evalúan antes que las de alerta.', pr: 'Un único estado consistente.', o: 'Bataller VD-26; Nuñez §7.2; Santibañez g.2; Zalazar (prioridad)', m: 'Todos', t: 'Determinística', e: 'CANDIDATA', c: 'Precedencia POSIBLE > INFORMACION marcada como política a validar', q: ['Q11']},
  {id: 'META-02', g: 'CONTROL', en: 'SI se modifica o agrega un F-Hecho del que depende una conclusión ENTONCES invalidar esa conclusión, conservar el historial y reejecutar el ciclo', pr: 'Consistencia ante correcciones.', o: 'Doc. SENDA; PI2', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'META-03', g: 'CONTROL', en: 'SI se asigna un estado ENTONCES registrar PasoTraza (regla, hechos, evidencia) y generar la explicación solo con lo activado', pr: 'Auditar cada conclusión.', o: 'Doc. SENDA R19', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'META-04', g: 'CONTROL', en: 'SI dos o más submódulos generan el mismo dato faltante (mismo producto o suplemento) ENTONCES unificarlo en un solo pedido con la lista de nutrientes', pr: 'No preguntar lo mismo tres veces.', o: 'PG1 (H6); Santibañez (sin solicitudes duplicadas)', m: 'SM-INT', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'META-05', g: 'CONTROL', en: 'SI veredicto_admisibilidad ≠ ADMISIBLE ENTONCES los 4 nutrientes reciben ese resultado y no emiten posible insuficiencia', pr: 'Seguridad e interfaz entre módulos.', o: 'Zalazar R-A7', m: 'SM-INT', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'META-06', g: 'CONTROL', en: 'SI un hecho requerido por una regla vale DESCONOCIDO ENTONCES la regla no se activa ni para alertar ni para descartar; el hecho pasa a datos faltantes. DESCONOCIDO nunca se guarda como NO, 0 ni «medio».', pr: 'Evitar falsas alertas y falsos descartes.', o: 'Nuñez B12-16; Zalazar R-A4; Santibañez R03', m: 'Todos', t: 'Determinística', e: 'VIGENTE', c: '', q: []},
  {id: 'META-07', g: 'CONTROL', en: 'SI no hay faltantes de datos ni cortes, pero la decisión depende de un criterio CANDIDATO (umbral, aptitud del registro) ENTONCES situacion_interna = PENDIENTE_VALIDACION, estado(n) sin asignar, alerta = NO_EVALUADA y se solicita el criterio; SI todos los criterios están validados y ninguna regla cubre el caso ENTONCES INFORMACION_INSUFICIENTE (SIN_REGLA_APLICABLE) con revisión profesional', pr: 'Nunca SIN_SEÑAL por defecto.', o: 'Ramirez CAL-11 (M03); Nuñez (comportamiento pendiente); Santibañez g.2', m: 'Todos', t: 'Determinística', e: 'MODIFICADA', c: 'Se extiende a los parámetros difusos y a la política de la zona moderada', q: []},
  {id: 'ADM-F07', g: 'ADMISIBILIDAD', en: 'SI MD-ADM entrega z* ENTONCES calidad_registro = etiqueta dominante; no ALTA si falta día hábil o de fin de semana o hay un DESCONOCIDO esencial', pr: 'Puente entre el índice difuso y la calidad crisp', o: 'Zalazar PI3', m: 'ADM', t: 'Determinística', e: 'NUEVA', c: 'Nueva en PG2 (topes crisp de PI3)', q: ['Q1']},
  {id: 'CA-07', g: 'CALCIO', en: 'SI se registra un vegetal con calcio de baja biodisponibilidad (espinaca) ENTONCES advertencia: no equivale a lácteos ni a bebidas fortificadas', pr: 'Evitar sobrestimar el calcio aprovechable', o: 'Cuestionario Q15', m: 'CA', t: 'Documental', e: 'NUEVA', c: 'Nueva en PG2', q: ['Q15']},
  {id: 'CA-D05', g: 'CALCIO', en: 'SI MD-CA entrega p* ENTONCES prioridad_revision_ca = etiqueta dominante (auxiliar; no asigna estado)', pr: 'Ordenar la revisión sin crear un quinto estado', o: 'Ramirez PI3', m: 'CA', t: 'Determinística', e: 'NUEVA', c: 'Nueva en PG2', q: []},
  {id: 'FE-F07', g: 'HIERRO', en: 'SI MD-FE entrega z* ENTONCES etiqueta de riesgo por cortes 33,5 / 66,5; ALTO con modelo VALIDADO → POSIBLE_INGESTA_INSUFICIENTE; nunca SIN_SEÑAL por sí solo', pr: 'Puente difuso → estado de hierro', o: 'Santibañez PI3 d.4', m: 'FE', t: 'Determinística', e: 'NUEVA', c: 'Nueva en PG2', q: []},
  {id: 'B12-FZ-05', g: 'B12', en: 'SI MD-B12 entrega z* ENTONCES BAJO → fuente verificada; ALTO → POSIBLE_INGESTA_INSUFICIENTE; MODERADO → política pendiente (solo con modelo VALIDADO)', pr: 'Puente difuso → estado de B12', o: 'Nuñez PI3 d.3', m: 'B12', t: 'Determinística', e: 'NUEVA', c: 'Nueva en PG2', q: ['Q9', 'Q11']},
  {id: 'VD-FZ-05', g: 'VITAMINA_D', en: 'SI MD-VD entrega z* ENTONCES estado y componente limitante según la regla de mayor α (FZ-01 AMBOS; FZ-02 DIETA; FZ-03 EXPOSICION)', pr: 'Puente difuso → estado de vitamina D', o: 'Bataller PI3 d.3', m: 'VD', t: 'Determinística', e: 'NUEVA', c: 'Nueva en PG2', q: ['Q26']},
  {id: 'VD-FZ-06', g: 'VITAMINA_D', en: 'SI el riesgo actual es BAJO o MODERADO Y con el índice UV de julio y ropa de invierno sería ALTO ENTONCES advertencia de reevaluar en invierno', pr: 'Validez estacional sin advertir a todos', o: 'Bataller PI3 d.3', m: 'VD', t: 'Contextual', e: 'NUEVA', c: 'Reemplaza a VD-27', q: ['Q25']}
] AS row
MERGE (r:Regla {id: row.id})
SET r.grupo = row.g, r.enunciado = row.en, r.proposito = row.pr, r.origen = row.o, r.modulo = row.m, r.tipo = row.t,
    r.estado_pg2 = row.e, r.cambio_pg2 = row.c, r.version = 'PG2-1.0'
WITH r, row UNWIND row.q AS qid
MATCH (q:PreguntaExperta {id: qid}) MERGE (r)-[:VALIDADA_CON]->(q);
// Regla → submódulo (por prefijo)
MATCH (r:Regla), (s:Submodulo)
WHERE (s.id = 'SM-ADM' AND r.grupo = 'ADMISIBILIDAD') OR (s.id = 'SM-CA' AND r.grupo = 'CALCIO')
   OR (s.id = 'SM-FE' AND r.grupo = 'HIERRO') OR (s.id = 'SM-B12' AND r.grupo = 'B12')
   OR (s.id = 'SM-VD' AND r.grupo = 'VITAMINA_D') OR (s.id = 'SM-INT' AND r.grupo IN ['CONTROL', 'GENERICA'])
MERGE (r)-[:PERTENECE_A]->(s);
// Regla → documento que la respalda (palabras clave del campo origen)
UNWIND [['NIH', 'NIH_ODS'], ['Watanabe', 'WATANABE'], ['Ley 25.630', 'LEY_25630'], ['CAA', 'CAA'], ['Rotulado', 'CAA'],
        ['Webb', 'WEBB_HOLICK'], ['Holick', 'WEBB_HOLICK'], ['Nutricionista', 'CUESTIONARIO'], ['experta', 'CUESTIONARIO'],
        ['Cuestionario', 'CUESTIONARIO'], ['Zalazar PI3', 'PI3_ZALAZAR'], ['Ramirez PI3', 'PI3_RAMIREZ'],
        ['Santibañez PI3', 'PI3_SANTIBANEZ'], ['Nuñez PI3', 'PI3_NUNEZ'], ['Bataller PI3', 'PI3_BATALLER'],
        ['Doc. SENDA', 'PG1'], ['PG1', 'PG1']] AS kw
MATCH (r:Regla), (f:FuenteConocimiento {id: kw[1]}) WHERE r.origen CONTAINS kw[0]
MERGE (r)-[:RESPALDADA_POR]->(f);

// 1.13 Trazabilidad: regla original (PI1 / PI2 / SENDA) → regla consolidada (Anexo A de PG1)
UNWIND [
  {o: 'SENDA', i: 'R01', c: 'ADM-01', t: 'Unificada'}, {o: 'SENDA', i: 'R02', c: 'ADM-03', t: 'Unificada'}, {o: 'SENDA', i: 'R03', c: 'G-05', t: 'Unificada'},
  {o: 'SENDA', i: 'R04', c: 'G-07', t: 'Unificada'}, {o: 'SENDA', i: 'R05', c: 'R05', t: 'Se conserva'}, {o: 'SENDA', i: 'R06', c: 'R06', t: 'Se conserva'},
  {o: 'SENDA', i: 'R07', c: 'G-01', t: 'Unificada'}, {o: 'SENDA', i: 'R08', c: 'CA-01', t: 'Unificada'}, {o: 'SENDA', i: 'R09', c: 'CA-02', t: 'Unificada'},
  {o: 'SENDA', i: 'R10', c: 'G-07', t: 'Unificada'}, {o: 'SENDA', i: 'R11', c: 'FE-01', t: 'Renumerada / generalizada'}, {o: 'SENDA', i: 'R12', c: 'G-07', t: 'Unificada'},
  {o: 'SENDA', i: 'R13', c: 'FE-02', t: 'Unificada'}, {o: 'SENDA', i: 'R14', c: 'R14', t: 'Se conserva'}, {o: 'SENDA', i: 'R15', c: 'G-07', t: 'Unificada'},
  {o: 'SENDA', i: 'R16', c: 'G-13', t: 'Renumerada / generalizada'}, {o: 'SENDA', i: 'R17', c: 'ADM-02', t: 'Unificada'}, {o: 'SENDA', i: 'R18', c: 'ADM-02', t: 'Unificada'},
  {o: 'SENDA', i: 'R19', c: 'META-03', t: 'Renumerada / generalizada'}, {o: 'SENDA', i: 'R20', c: 'G-08', t: 'Unificada'}, {o: 'SENDA', i: 'R21', c: 'G-04', t: 'Unificada'},
  {o: 'SENDA', i: 'R22', c: 'ADM-04', t: 'Unificada'}, {o: 'Zalazar PI2', i: 'R-A1', c: 'ADM-01', t: 'Unificada'}, {o: 'Zalazar PI2', i: 'R-A2', c: 'ADM-02', t: 'Unificada'},
  {o: 'Zalazar PI2', i: 'R-A3', c: 'ADM-03', t: 'Unificada'}, {o: 'Zalazar PI2', i: 'R-A4', c: 'META-06', t: 'Unificada'}, {o: 'Zalazar PI2', i: 'R-A5', c: 'ADM-04', t: 'Unificada'},
  {o: 'Zalazar PI2', i: 'R-A6', c: 'ADM-05', t: 'Renumerada / generalizada'}, {o: 'Zalazar PI2', i: 'R-A6', c: 'ADM-06', t: 'Renumerada / generalizada'}, {o: 'Zalazar PI2', i: 'R-A7', c: 'META-05', t: 'Unificada'},
  {o: 'Zalazar PI2', i: 'R-A8', c: 'ADM-07', t: 'Renumerada / generalizada'}, {o: 'Ramirez PI2', i: 'CAL-01', c: 'G-04', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'CAL-02', c: 'G-01', t: 'Unificada'},
  {o: 'Ramirez PI2', i: 'CAL-03', c: 'CA-03', t: 'Renumerada / generalizada'}, {o: 'Ramirez PI2', i: 'CAL-04', c: 'G-05', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'CAL-05', c: 'META-02', t: 'Unificada'},
  {o: 'Ramirez PI2', i: 'CAL-06', c: 'G-08', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'CAL-07', c: 'ADM-02', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'CAL-08', c: 'G-10', t: 'Unificada'},
  {o: 'Ramirez PI2', i: 'CAL-09', c: 'G-15', t: 'Renumerada / generalizada'}, {o: 'Ramirez PI2', i: 'CAL-10', c: 'META-05', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'CAL-11', c: 'META-07', t: 'Renumerada / generalizada'},
  {o: 'Ramirez PI2', i: 'CAL-12', c: 'G-06', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'R08', c: 'CA-01', t: 'Unificada'}, {o: 'Ramirez PI2', i: 'R09', c: 'CA-02', t: 'Unificada'},
  {o: 'Ramirez PI2', i: 'R10', c: 'G-07', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-01', c: 'ADM-02', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-02', c: 'FE-07', t: 'Unificada'},
  {o: 'Santibañez PI1', i: 'R-Fe-03', c: 'FE-03', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-04', c: 'FE-04', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-05', c: 'FE-05', t: 'Unificada'},
  {o: 'Santibañez PI1', i: 'R-Fe-06', c: 'FE-08', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-07', c: 'FE-02', t: 'Unificada'}, {o: 'Santibañez PI1', i: 'R-Fe-08', c: 'FE-08', t: 'Unificada'},
  {o: 'Santibañez PI1', i: 'R-Fe-09', c: 'G-05', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R01', c: 'ADM-01', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R02', c: 'ADM-02', t: 'Unificada'},
  {o: 'Santibañez PI2', i: 'R03', c: 'META-06', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R04', c: 'G-05', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R05', c: 'FE-02', t: 'Unificada'},
  {o: 'Santibañez PI2', i: 'R06', c: 'FE-02', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R07', c: 'FE-03', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R08', c: 'FE-04', t: 'Unificada'},
  {o: 'Santibañez PI2', i: 'R09', c: 'FE-05', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R10', c: 'FE-06', t: 'Renumerada / generalizada'}, {o: 'Santibañez PI2', i: 'R11', c: 'FE-09', t: 'Renumerada / generalizada'},
  {o: 'Santibañez PI2', i: 'R12', c: 'FE-08', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R13', c: 'FE-07', t: 'Unificada'}, {o: 'Santibañez PI2', i: 'R14', c: 'FE-10', t: 'Renumerada / generalizada'},
  {o: 'Nuñez PI2', i: 'B12-01', c: 'G-12', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-02', c: 'G-12', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-03', c: 'B12-03', t: 'Se conserva'},
  {o: 'Nuñez PI2', i: 'B12-04', c: 'G-04', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-05', c: 'G-07', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-06', c: 'G-05', t: 'Unificada'},
  {o: 'Nuñez PI2', i: 'B12-07', c: 'B12-07', t: 'Se conserva'}, {o: 'Nuñez PI2', i: 'B12-08', c: 'G-09', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-09', c: 'G-09', t: 'Unificada'},
  {o: 'Nuñez PI2', i: 'B12-10', c: 'G-02', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-11', c: 'G-11', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-12', c: 'B12-12', t: 'Se conserva'},
  {o: 'Nuñez PI2', i: 'B12-13', c: 'META-02', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-14', c: 'G-08', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-15', c: 'G-10', t: 'Unificada'},
  {o: 'Nuñez PI2', i: 'B12-16', c: 'META-06', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-17', c: 'G-06', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-18', c: 'B12-18', t: 'Se conserva'},
  {o: 'Nuñez PI2', i: 'B12-19', c: 'G-14', t: 'Unificada'}, {o: 'Nuñez PI2', i: 'B12-20', c: 'B12-20', t: 'Se conserva'}, {o: 'Nuñez PI2', i: 'R05', c: 'R05', t: 'Se conserva'},
  {o: 'Nuñez PI2', i: 'R06', c: 'R06', t: 'Se conserva'}, {o: 'Nuñez PI2', i: 'R07', c: 'G-01', t: 'Unificada'}, {o: 'Bataller PI2', i: 'R14', c: 'R14', t: 'Se conserva'},
  {o: 'Bataller PI2', i: 'R15', c: 'VD-13', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-01', c: 'G-12', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-02', c: 'G-12', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-03', c: 'VD-03', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-04', c: 'VD-04', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-05', c: 'G-01', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-06', c: 'G-02', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-07', c: 'G-04', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-08', c: 'G-09', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-09', c: 'G-05', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-10', c: 'G-09', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-11', c: 'VD-11', t: 'Se conserva'},
  {o: 'Bataller PI2', i: 'VD-12', c: 'VD-12', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-13', c: 'VD-13', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-14', c: 'VD-14', t: 'Se conserva'},
  {o: 'Bataller PI2', i: 'VD-15', c: 'VD-15/17', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-16', c: 'G-11', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-17', c: 'VD-15/17', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-18', c: 'G-06', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-19', c: 'META-02', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-20', c: 'G-08', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-21', c: 'VD-21', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-22', c: 'VD-22', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-23', c: 'G-14', t: 'Unificada'},
  {o: 'Bataller PI2', i: 'VD-24', c: 'G-10', t: 'Unificada'}, {o: 'Bataller PI2', i: 'VD-25', c: 'VD-25', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-26', c: 'META-01', t: 'Renumerada / generalizada'},
  {o: 'Bataller PI2', i: 'VD-27', c: 'VD-27', t: 'Se conserva'}, {o: 'Bataller PI2', i: 'VD-28', c: 'G-03', t: 'Renumerada / generalizada'}
] AS row
MERGE (ro:ReglaOriginal {clave: row.o + ' · ' + row.i}) SET ro.trabajo = row.o, ro.id_original = row.i
WITH ro, row MATCH (r:Regla {id: row.c}) MERGE (ro)-[x:CONSOLIDADA_EN]->(r) SET x.tratamiento = row.t;

// 1.14 Frames y slots (F-xxx de PG1 f.2 + extensiones PI3/PG2)
UNWIND [
  {f: 'F-Paciente', e: 'Paciente', d: 'Adulto cuyo caso se evalúa', o: 'Todos'}, {f: 'F-Hecho', e: 'Hecho', d: 'Dato atómico del caso con fuente y confianza de extracción', o: 'SENDA; Nuñez; Bataller'},
  {f: 'F-RegistroAlimentario', e: 'RegistroAlimentario', d: 'Registro de alimentos; días y comidas', o: 'Zalazar'}, {f: 'F-PatronAlimentario', e: 'PatronAlimentario', d: 'Modo habitual de alimentación', o: 'Nuñez'},
  {f: 'F-Omnivoro', e: 'PatronAlimentario', d: 'Sin grupos excluidos', o: 'Nuñez'}, {f: 'F-Pescetariano', e: 'PatronAlimentario', d: 'Excluye carnes', o: 'Nuñez'},
  {f: 'F-Vegetariano', e: 'PatronAlimentario', d: 'Excluye carnes y pescados', o: 'Nuñez'}, {f: 'F-Ovolactovegetariano', e: 'PatronAlimentario', d: 'Hereda exclusiones de Vegetariano', o: 'Nuñez'},
  {f: 'F-Vegano', e: 'PatronAlimentario', d: 'Excluye además huevos y lácteos', o: 'Nuñez'}, {f: 'F-CondicionDerivacion', e: 'CondicionDerivacion', d: 'Condición del catálogo que obliga a derivar', o: 'ADM; B12; VD; FE'},
  {f: 'F-CriterioAlcance', e: 'CriterioAlcance', d: 'Motivo por el que el caso no pertenece al alcance', o: 'Zalazar; PI3'}, {f: 'F-Nutriente', e: 'Nutriente', d: 'Nutriente evaluado (CA / FE / B12 / VD)', o: 'Todos'},
  {f: 'F-ValorReferencia', e: 'ValorReferencia', d: 'Referencia por nutriente; edad y sexo', o: 'NIH ODS'}, {f: 'F-CriterioCandidato', e: 'CriterioCandidato', d: 'Criterio o parámetro con estado de validación', o: 'Nuñez; Ramirez'},
  {f: 'F-Fuente', e: 'Fuente', d: 'Superclase abstracta de alimentos y suplementos', o: 'PG1'}, {f: 'F-Alimento', e: 'Alimento', d: 'Alimento del registro', o: 'Todos'},
  {f: 'F-AlimentoFortificado', e: 'Fortificado', d: 'Rol solapable (segunda etiqueta) del alimento con rótulo', o: 'Ramirez (H6)'}, {f: 'F-Suplemento', e: 'Suplemento', d: 'Producto con dosis', o: 'Todos'},
  {f: 'F-FuenteNoConfiable', e: 'FuenteNoConfiable', d: 'Lo que se cree fuente pero no aporta (no hereda de F-Fuente)', o: 'Nuñez; Bataller'}, {f: 'F-Consumo', e: 'Consumo', d: 'Consumo registrado de un alimento', o: 'Santibañez; Ramirez'},
  {f: 'F-Comida', e: 'Comida', d: 'Episodio de comida del paciente', o: 'Santibañez'}, {f: 'F-ExposicionSolar', e: 'ExposicionSolar', d: 'Hábito de exposición solar', o: 'Bataller'},
  {f: 'F-Localidad', e: 'Localidad', d: 'Lugar de residencia con índice UV mensual', o: 'Bataller'}, {f: 'F-FactorModificador', e: 'FactorModificador', d: 'Medicamento / inhibidor / potenciador', o: 'B12; FE; VD'},
  {f: 'F-EvaluacionAdmisibilidad', e: 'EvaluacionAdmisibilidad', d: 'Veredicto previo de SM-ADM', o: 'Zalazar'}, {f: 'F-EvaluacionNutriente', e: 'EvaluacionNutriente', d: 'Resultado de un submódulo de nutriente', o: 'Todos'},
  {f: 'F-ElementoResultado', e: 'ElementoResultado', d: 'Superclase de PasoTraza / DatoFaltante / Advertencia', o: 'SENDA'}, {f: 'F-ResultadoConsolidado', e: 'ResultadoConsolidado', d: 'Une las cuatro evaluaciones', o: 'SM-INT'},
  {f: 'F-ModeloDifuso', e: 'ModeloDifuso', d: 'Sistema Mamdani de un submódulo (PI3)', o: 'PI3'}, {f: 'F-VariableDifusa', e: 'VariableDifusa', d: 'Variable lingüística', o: 'PI3'},
  {f: 'F-TerminoDifuso', e: 'TerminoDifuso', d: 'Etiqueta con función de pertenencia', o: 'PI3'}, {f: 'F-ReglaDifusa', e: 'ReglaDifusa', d: 'Regla borrosa SI…ENTONCES', o: 'PI3'},
  {f: 'F-Regla', e: 'Regla', d: 'Regla crisp consolidada de PG1', o: 'PG1'}, {f: 'F-Usuario', e: 'Usuario', d: 'Nutricionista o médico', o: 'PG1'}
] AS row
MERGE (f:Frame {nombre: row.f}) SET f.etiqueta_neo4j = row.e, f.descripcion = row.d, f.origen = row.o;
UNWIND [
  {f: 'F-Omnivoro', p: 'F-PatronAlimentario'}, {f: 'F-Pescetariano', p: 'F-PatronAlimentario'}, {f: 'F-Vegetariano', p: 'F-PatronAlimentario'}, {f: 'F-Ovolactovegetariano', p: 'F-Vegetariano'},
  {f: 'F-Vegano', p: 'F-Vegetariano'}, {f: 'F-Alimento', p: 'F-Fuente'}, {f: 'F-AlimentoFortificado', p: 'F-Alimento'}, {f: 'F-Suplemento', p: 'F-Fuente'}
] AS row
MATCH (f:Frame {nombre: row.f}), (p:Frame {nombre: row.p}) MERGE (f)-[:ES_UN]->(p);
UNWIND [
  {f: 'F-Paciente', s: 'id', t: 'texto', d: 'único', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Restricción de unicidad'},
  {f: 'F-Paciente', s: 'edad', t: 'entero', d: '18..64 (fuera → ADM-01)', c: '1', df: '—', r: 'PROPIEDAD', fa: '18 y 64 incluidos con nota de borde'},
  {f: 'F-Paciente', s: 'sexo', t: 'F / M / DESCONOCIDO', d: '—', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'Elige la referencia de CA y FE'},
  {f: 'F-Paciente', s: 'estado_fisiologico', t: 'NINGUNO / EMBARAZO / LACTANCIA / NO_DECLARADO', d: '—', c: '1', df: 'NO_DECLARADO', r: 'PROPIEDAD', fa: 'EMBARAZO o LACTANCIA → ADM-01'},
  {f: 'F-Paciente', s: 'suplementos', t: 'SI / NO / DESCONOCIDO', d: '—', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'NO solo si es explícito (META-06)'},
  {f: 'F-Paciente', s: 'sigue', t: '→ F-PatronAlimentario', d: '—', c: '1', df: '—', r: 'RELACION:SIGUE', fa: 'Compartido por los 4 nutrientes'},
  {f: 'F-Paciente', s: 'registra', t: '→ F-Consumo', d: '—', c: '0..n', df: '∅', r: 'RELACION:REGISTRA', fa: 'Lista vacía no demuestra ausencia'},
  {f: 'F-Paciente', s: 'toma', t: '→ F-Suplemento', d: '—', c: '0..n', df: '∅', r: 'RELACION:TOMA {pauta_tomas_28d; tomas_realizadas_28d; regularidad; momento_toma; frecuencia_conocida}', fa: 'Regularidad en la relación (es del paciente)'},
  {f: 'F-Paciente', s: 'presenta', t: '→ F-CondicionDerivacion', d: '—', c: '0..n', df: '∅', r: 'RELACION:PRESENTA {estado}', fa: 'if-added PRESENTE → ADM-02 o G-12'},
  {f: 'F-Paciente', s: 'usa', t: '→ F-Medicamento', d: '—', c: '0..n', df: '∅', r: 'RELACION:USA {tiempo_uso_meses}', fa: 'if-added → G-11'},
  {f: 'F-Paciente', s: 'reside_en', t: '→ F-Localidad', d: '—', c: '0..1', df: '—', r: 'RELACION:RESIDE_EN', fa: 'Solo SM-VD'},
  {f: 'F-Paciente', s: 'tiene_habito_de', t: '→ F-ExposicionSolar', d: '—', c: '0..1', df: '—', r: 'RELACION:TIENE_HABITO_DE', fa: 'Solo SM-VD'},
  {f: 'F-Paciente', s: 'declara_fuente', t: '→ F-FuenteNoConfiable', d: '—', c: '0..n', df: '∅', r: 'RELACION:DECLARA_FUENTE', fa: 'if-added → G-09'},
  {f: 'F-Hecho', s: 'atributo / valor / fuente', t: 'texto', d: 'DESCONOCIDO ≠ NO ≠ 0', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'if-changed → META-02'},
  {f: 'F-Hecho', s: 'confianza_extraccion', t: 'real', d: '0..1', c: '1', df: '—', r: 'PROPIEDAD', fa: '< PARAM_CONFIANZA_EXTRACCION → revisar (no es grado difuso)'},
  {f: 'F-RegistroAlimentario', s: 'dias_registro', t: 'real', d: '0..7', c: '1', df: '—', r: 'PROPIEDAD + estado_dias', fa: 'Entrada de MD-ADM'},
  {f: 'F-RegistroAlimentario', s: 'comidas_principales', t: 'real', d: '0..4', c: '1', df: '—', r: 'PROPIEDAD + estado_comidas', fa: 'Entrada de MD-ADM'},
  {f: 'F-RegistroAlimentario', s: 'incluye_habil / incluye_finde', t: 'booleano', d: '—', c: '1', df: 'false', r: 'PROPIEDAD', fa: 'Tope crisp de calidad (Q1)'},
  {f: 'F-RegistroAlimentario', s: 'relevamiento_cerrado', t: 'SI / NO / DESCONOCIDO', d: '—', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'Condiciona TOTAL_REGISTRO (G-15)'},
  {f: 'F-RegistroAlimentario', s: 'dia_atipico_unico / sin_frecuencias / comida_aislada', t: 'booleano', d: '—', c: '1', df: 'false', r: 'PROPIEDAD', fa: '→ ADM-03'},
  {f: 'F-RegistroAlimentario', s: 'totales_diarios_ca', t: 'lista de reales', d: 'mg/día', c: '0..1', df: '—', r: 'PROPIEDAD', fa: 'Entrada de MD-CA (variabilidad)'},
  {f: 'F-RegistroAlimentario', s: 'calidad_registro', t: 'ALTA / MEDIA / BAJA', d: '—', c: '1', df: '—', r: 'PROPIEDAD (derivada)', fa: 'La asigna el puente ADM-06'},
  {f: 'F-PatronAlimentario', s: 'codigo', t: 'OMNIVORO / PESCETARIANO / VEGETARIANO / OVOLACTOVEGETARIANO / VEGANO', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Nodo de clase compartido'},
  {f: 'F-PatronAlimentario', s: 'excluye', t: '→ GrupoAlimento', d: '—', c: '0..n', df: 'heredado', r: 'RELACION:EXCLUYE', fa: 'Se hereda por ES_UN*'},
  {f: 'F-PatronAlimentario', s: 'requiere_fuente_alternativa', t: '→ F-Nutriente', d: '—', c: '0..n', df: 'heredado', r: 'RELACION:REQUIERE_FUENTE_ALTERNATIVA', fa: 'Activa R05 / CA-01 / FE-01'},
  {f: 'F-CondicionDerivacion', s: 'alcance', t: 'GENERAL / ESPECIFICA', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'GENERAL → ADM-02; ESPECIFICA → G-12'},
  {f: 'F-CondicionDerivacion', s: 'estado_validacion', t: 'CANDIDATA / VALIDADA', d: '—', c: '1', df: 'CANDIDATA', r: 'PROPIEDAD', fa: 'Catálogo general VALIDADO (Q4)'},
  {f: 'F-Nutriente', s: 'codigo', t: 'CA / FE / B12 / VD', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Clave del parámetro n'},
  {f: 'F-ValorReferencia', s: 'valor / limite_superior', t: 'real', d: 'mg o µg', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Una fila por edad y sexo'},
  {f: 'F-CriterioCandidato', s: 'valor', t: 'número / texto', d: 'PENDIENTE si no hay valor', c: '1', df: 'PENDIENTE', r: 'PROPIEDAD', fa: 'Nunca se rellena con un número inventado'},
  {f: 'F-CriterioCandidato', s: 'estado_validacion', t: 'CANDIDATO / VALIDADO / RECHAZADO', d: '—', c: '1', df: 'CANDIDATO', r: 'PROPIEDAD', fa: 'if-changed → META-02'},
  {f: 'F-Alimento', s: 'grupo', t: '→ GrupoAlimento', d: '—', c: '1', df: '—', r: 'RELACION:PERTENECE_A', fa: 'Permite heredar fuentes por grupo'},
  {f: 'F-Alimento', s: 'aporta', t: '→ F-Nutriente', d: '{cantidad; unidad; forma; biodisponibilidad}', c: '0..n', df: '∅', r: 'RELACION:APORTA', fa: 'Contenido por porción'},
  {f: 'F-AlimentoFortificado', s: 'declara', t: '→ F-Nutriente', d: '{valor SI/NO/DESCONOCIDO; contenido}', c: '1..n', df: 'DESCONOCIDO', r: 'RELACION:DECLARA', fa: 'Reemplaza F-DeclaracionRotulo; G-04 / G-09 / G-10'},
  {f: 'F-Suplemento', s: 'contiene', t: '→ F-Nutriente', d: '{dosis; unidad}', c: '1..n', df: '—', r: 'RELACION:CONTIENE', fa: 'G-01 / G-02'},
  {f: 'F-FuenteNoConfiable', s: 'no_aporta', t: '→ F-Nutriente', d: '{motivo}', c: '1..n', df: '—', r: 'RELACION:NO_APORTA', fa: 'G-09'},
  {f: 'F-Consumo', s: 'frecuencia_semanal', t: 'real', d: 'porciones/semana', c: '1', df: '—', r: 'PROPIEDAD + estado_frecuencia', fa: 'No convertir «seguido» en número'},
  {f: 'F-Consumo', s: 'de', t: '→ F-Alimento', d: '—', c: '1', df: '—', r: 'RELACION:DE', fa: '—'},
  {f: 'F-Consumo', s: 'ocurre_en', t: '→ F-Comida', d: '{veces_semana; coincide_con_comida}', c: '0..n', df: '∅', r: 'RELACION:OCURRE_EN', fa: 'FE-02'},
  {f: 'F-ExposicionSolar', s: 'tiempo_aire_libre_h', t: 'real', d: 'h/semana en franja UVB', c: '1', df: '—', r: 'PROPIEDAD + estado_tiempo', fa: 'f_tiempo'},
  {f: 'F-ExposicionSolar', s: 'cobertura_vestimenta / protector_solar / fototipo', t: 'categórico', d: 'BAJA-MEDIA-ALTA / NUNCA-A_VECES-SIEMPRE / I-VI', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'Coeficientes en FactorExposicion'},
  {f: 'F-ExposicionSolar', s: 'a_traves_de_vidrio', t: 'SI / NO / DESCONOCIDO', d: '—', c: '1', df: 'DESCONOCIDO', r: 'PROPIEDAD', fa: 'SI → horas valen 0 (G-09)'},
  {f: 'F-EvaluacionAdmisibilidad', s: 'veredicto', t: 'ADMISIBLE / INFORMACION_INSUFICIENTE / DERIVAR / FUERA_DE_ALCANCE', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: '≠ ADMISIBLE → META-05'},
  {f: 'F-EvaluacionAdmisibilidad', s: 'calidad_registro / indice_calidad', t: 'ALTA-MEDIA-BAJA / real', d: '—', c: '0..1', df: '—', r: 'PROPIEDAD', fa: 'Puente de MD-ADM'},
  {f: 'F-EvaluacionNutriente', s: 'estado', t: '4 estados de PG0', d: '—', c: '0..1', df: 'sin asignar', r: 'PROPIEDAD + RELACION:TIENE_ESTADO', fa: 'Lo resuelve META-01'},
  {f: 'F-EvaluacionNutriente', s: 'situacion_interna', t: 'EN_PROCESO / PENDIENTE_VALIDACION / CONCLUIDA', d: '—', c: '1', df: 'EN_PROCESO', r: 'PROPIEDAD', fa: 'PENDIENTE_VALIDACION deja el estado sin asignar'},
  {f: 'F-EvaluacionNutriente', s: 'ingesta_estimada / ingesta_relativa / ingesta_alcance', t: 'real / real / PARCIAL-TOTAL_REGISTRO', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'G-15'},
  {f: 'F-EvaluacionNutriente', s: 'fuente_verificada', t: 'SI / NO / DESCONOCIDO', d: '—', c: '1', df: 'NO', r: 'PROPIEDAD', fa: 'SIN_SEÑAL exige SI (G-08)'},
  {f: 'F-EvaluacionNutriente', s: 'capa_difusa_estado', t: 'HABILITADA / EJECUTADA / NO_APLICA_*', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Guardas de la capa difusa'},
  {f: 'F-EvaluacionNutriente', s: 'riesgo_difuso / etiqueta_riesgo', t: 'real / BAJO-MODERADO-ALTO', d: '—', c: '0..1', df: '—', r: 'PROPIEDAD', fa: 'Puente FZ-05 (provisional mientras CANDIDATO)'},
  {f: 'F-ElementoResultado', s: 'regla / texto / nutrientes', t: 'texto', d: '—', c: '1', df: '—', r: 'NODOS PasoTraza / DatoFaltante / Advertencia', fa: 'Solo lo activado se explica'},
  {f: 'F-ModeloDifuso', s: 'operadores', t: 'MIN / MAX / 1-MU / MIN / MAX / CENTROIDE', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Mamdani'},
  {f: 'F-VariableDifusa', s: 'universo_min / universo_max / unidad', t: 'real', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Escala común por familia'},
  {f: 'F-TerminoDifuso', s: 'tipo_funcion / centro / sigma', t: 'GAUSSIANA / HOMBRO_IZQ / HOMBRO_DER; real; real', d: '—', c: '1', df: '—', r: 'PROPIEDAD', fa: 'Parámetros en el grafo (no en el código)'},
  {f: 'F-ReglaDifusa', s: 'antecedente', t: '→ F-TerminoDifuso', d: '{grupo; negado}', c: '1..n', df: '—', r: 'RELACION:ANTECEDENTE', fa: 'Forma normal conjuntiva'},
  {f: 'F-ReglaDifusa', s: 'consecuente', t: '→ F-TerminoDifuso', d: '—', c: '1', df: '—', r: 'RELACION:CONSECUENTE', fa: '—'}
] AS row
MATCH (f:Frame {nombre: row.f})
MERGE (s:Slot {id: row.f + '.' + row.s})
SET s.nombre = row.s, s.tipo = row.t, s.dominio = row.d, s.cardinalidad = row.c, s.default = row.df,
    s.representacion = row.r, s.faceta = row.fa
MERGE (f)-[:TIENE_SLOT]->(s);

// 1.15 Localidad e índice UV mensual (Bataller PI3; reemplazar por climatología SMN)
MERGE (l:Localidad {nombre:'Mendoza'}) SET l.latitud = -32.9;
UNWIND [
  {m: 1, i: 12}, {m: 2, i: 11}, {m: 3, i: 9}, {m: 4, i: 6}, {m: 5, i: 4}, {m: 6, i: 3},
  {m: 7, i: 3}, {m: 8, i: 4}, {m: 9, i: 6}, {m: 10, i: 9}, {m: 11, i: 11}, {m: 12, i: 12}
] AS row
MATCH (l:Localidad {nombre:'Mendoza'})
MERGE (u:IndiceUVMensual {id: 'Mendoza-' + toString(row.m)}) SET u.mes = row.m, u.iuv = row.i, u.fuente = 'Aproximado (cielo despejado); reemplazar por SMN'
MERGE (l)-[:TIENE_IUV]->(u);
