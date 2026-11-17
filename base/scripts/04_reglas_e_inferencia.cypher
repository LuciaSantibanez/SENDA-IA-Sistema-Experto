
// =============================================================================
// 04 · REGLAS E INFERENCIA (agenda de PG1 + capa difusa de PI3)
// =============================================================================
// Cada regla crisp es una consulta que crea o actualiza la evaluación y deja un
// :PasoTraza unido a la :Regla aplicada (APLICA_REGLA) y a la evidencia usada
// (SE_APOYA_EN). Las reglas NO escriben el estado final: lo proponen
// (estado_propuesto) y META-01 resuelve la prioridad al final.
// El bloque completo es re-ejecutable: 4.0 borra lo derivado (META-02).

// ---------------------------------------------------------------- 4.0 META-02
MATCH (x) WHERE x:EvaluacionAdmisibilidad OR x:EvaluacionNutriente OR x:PasoTraza OR x:DatoFaltante
             OR x:Advertencia OR x:ResultadoConsolidado OR x:ProyeccionInvernal
DETACH DELETE x;
MATCH (r:RegistroAlimentario) SET r.calidad_registro = null;

// ---------------------------------------------------------------- 4.1 Evaluaciones
MATCH (p:Paciente)-[:TIENE_CONSULTA]->(c:Consulta)
MERGE (p)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad {id: p.id + '-ADM'})
SET ea.situacion_interna = 'EN_PROCESO', ea.mes_consulta = c.mes;
MATCH (p:Paciente)-[:TIENE_CONSULTA]->(c:Consulta), (n:Nutriente)
MERGE (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {id: p.id + '-' + n.codigo})
SET e.nutriente = n.codigo, e.situacion_interna = 'EN_PROCESO', e.fuente_verificada = 'NO',
    e.alerta = 'NO_EVALUADA', e.mes_consulta = c.mes, e.habilitada = false, e.bloqueada = false
MERGE (e)-[:EVALUA]->(n);

// ====================================================== GRUPO 1 · SM-ADM
// ADM-01 · Alcance (D1)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
WHERE p.edad < 18 OR p.edad > 64 OR p.estado_fisiologico IN ['EMBARAZO', 'LACTANCIA'] OR p.protocolo_especifico = true
WITH p, ea, CASE WHEN p.estado_fisiologico IN ['EMBARAZO', 'LACTANCIA'] THEN p.estado_fisiologico
                 WHEN p.protocolo_especifico = true THEN 'PROTOCOLO_ESPECIFICO' ELSE 'EDAD_FUERA_DE_RANGO' END AS motivo
MATCH (ca:CriterioAlcance {codigo: motivo}), (rg:Regla {id:'ADM-01'})
SET ea.veredicto = 'FUERA_DE_ALCANCE', ea.accion = 'EXPLICAR_LIMITE'
MERGE (ea)-[:EXCLUIDA_POR {regla:'ADM-01'}]->(ca)
CREATE (ea)-[:REGISTRA]->(t:PasoTraza {regla:'ADM-01', orden:10, efecto:'VEREDICTO', valor:'FUERA_DE_ALCANCE',
        texto:'El caso no pertenece al alcance de SENDA 1.0 (' + motivo + '): se explica el límite (Q6)'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(p);

// ADM-02 · Condición general del catálogo validado (D2, Q4)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad), (p)-[pr:PRESENTA]->(c:CondicionDerivacion {alcance:'GENERAL'})
WHERE ea.veredicto IS NULL AND pr.estado = 'PRESENTE'
MATCH (rg:Regla {id:'ADM-02'}), (med:Usuario {id:'MED-01'})
SET ea.veredicto = 'DERIVAR', ea.accion = 'DERIVAR'
MERGE (ea)-[:INTERRUMPIDA_POR {regla:'ADM-02'}]->(c)
MERGE (ea)-[:SE_DERIVA_A]->(med)
CREATE (ea)-[:REGISTRA]->(t:PasoTraza {regla:'ADM-02', orden:20, efecto:'VEREDICTO', valor:'DERIVAR',
        texto:'Condición del catálogo de derivación presente: ' + c.nombre + '. Se interrumpe la vía dietaria y se deriva al médico'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(c);

// ADM-04 · Contradicción patrón ↔ registro (D4, Q7). Recorre la herencia ES_UN* de las exclusiones.
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad),
      (p)-[:SIGUE]->(pa:PatronAlimentario)-[:ES_UN*0..3]->(:PatronAlimentario)-[:EXCLUYE]->(g:GrupoAlimento)
      <-[:PERTENECE_A]-(a:Alimento)<-[:DE]-(cn:Consumo)<-[:REGISTRA]-(p)
WHERE ea.veredicto IS NULL
WITH p, ea, pa, collect(DISTINCT a.nombre) AS alimentos, collect(DISTINCT cn) AS consumos
MATCH (rg:Regla {id:'ADM-04'})
SET ea.veredicto = 'INFORMACION_INSUFICIENTE', ea.accion = 'PEDIR_ACLARACION'
MERGE (df:DatoFaltante {clave: p.id + '|PATRON'})
SET df.texto = 'Aclarar cómo define su alimentación: declara ' + pa.codigo + ' y registra ' + reduce(s = '', x IN alimentos | s + x + ' '),
    df.regla = 'ADM-04', df.pregunta = 'Q7'
MERGE (ea)-[:GENERA]->(df)
CREATE (ea)-[:REGISTRA]->(t:PasoTraza {regla:'ADM-04', orden:30, efecto:'VEREDICTO', valor:'INFORMACION_INSUFICIENTE',
        texto:'El patrón declarado contradice el registro: no se elige arbitrariamente cuál dato es correcto'})
CREATE (t)-[:APLICA_REGLA]->(rg)
FOREACH (c IN consumos | CREATE (t)-[:SE_APOYA_EN]->(c));

// ADM-03 · Huecos groseros del registro (D3). Con pocos días NO corta: lo gradúa MD-ADM (Q1/Q3).
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
WHERE ea.veredicto IS NULL AND (r.dia_atipico_unico = true OR r.sin_frecuencias = true OR r.comida_aislada = true
      OR r.estado_dias = 'DESCONOCIDO' OR r.estado_comidas = 'DESCONOCIDO')
MATCH (rg:Regla {id:'ADM-03'})
SET ea.veredicto = 'INFORMACION_INSUFICIENTE', ea.accion = 'COMPLETAR_REGISTRO'
MERGE (df:DatoFaltante {clave: p.id + '|REGISTRO'}) SET df.texto = 'Completar el registro con días habituales (3 a 7, con fin de semana)', df.regla = 'ADM-03', df.pregunta = 'Q1'
MERGE (ea)-[:GENERA]->(df)
CREATE (ea)-[:REGISTRA]->(t:PasoTraza {regla:'ADM-03', orden:35, efecto:'VEREDICTO', valor:'INFORMACION_INSUFICIENTE', texto:'Registro no representativo de la alimentación habitual'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(r);

// ADM-05 · Admisible: habilita los cuatro submódulos
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
WHERE ea.veredicto IS NULL
MATCH (rg:Regla {id:'ADM-05'})
SET ea.veredicto = 'ADMISIBLE', ea.accion = 'NINGUNA',
    ea.nota_de_borde = CASE WHEN p.edad IN [18, 64] THEN 'Edad en el borde del alcance de SENDA 1.0' ELSE null END
CREATE (ea)-[:REGISTRA]->(t:PasoTraza {regla:'ADM-05', orden:40, efecto:'VEREDICTO', valor:'ADMISIBLE', texto:'D1 a D4 superados: se habilitan CA, FE, B12 y VD'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(p)
WITH p, ea
MATCH (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
SET e.habilitada = true
MERGE (ea)-[:HABILITA]->(e);

// ADM-06 / MD-ADM · Entradas de la calidad difusa del registro (solo si es ADMISIBLE y los datos son conocidos)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad {veredicto:'ADMISIBLE'}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
WHERE r.estado_dias = 'CONOCIDO' AND r.estado_comidas = 'CONOCIDO'
MATCH (m:ModeloDifuso {id:'MD-ADM'}), (vd:VariableDifusa {id:'V-ADM-DIAS'}), (vc:VariableDifusa {id:'V-ADM-COM'})
SET ea.capa_difusa_estado = 'HABILITADA'
MERGE (ea)-[:USA_MODELO]->(m)
MERGE (ea)-[i1:ENTRADA]->(vd) SET i1.valor = toFloat(r.dias_registro)
MERGE (ea)-[i2:ENTRADA]->(vc) SET i2.valor = toFloat(r.comidas_principales);

// ----------------------------------------------- MOTOR DIFUSO GENÉRICO (pasada A: admisibilidad)
// F1 · Fuzzificación gaussiana con hombros: μ(x) = exp(−(x − c)² / 2σ²)
MATCH (suj:EvaluacionAdmisibilidad)-[:USA_MODELO]->(:ModeloDifuso)-[:DEFINE_VARIABLE]->(v:VariableDifusa)-[:TIENE_TERMINO]->(t:TerminoDifuso)
MATCH (suj)-[en:ENTRADA]->(v)
WITH suj, t, CASE WHEN en.valor < v.universo_min THEN toFloat(v.universo_min)
                  WHEN en.valor > v.universo_max THEN toFloat(v.universo_max) ELSE toFloat(en.valor) END AS x
MERGE (suj)-[pe:PERTENECE]->(t)
SET pe.x = x,
    pe.mu = CASE WHEN t.tipo_funcion = 'HOMBRO_IZQ' AND x <= t.centro THEN 1.0
                 WHEN t.tipo_funcion = 'HOMBRO_DER' AND x >= t.centro THEN 1.0
                 ELSE exp(-1.0 * (x - t.centro)^2 / (2.0 * t.sigma^2)) END;
// F2 · Activación: OR = MAX dentro de cada grupo del antecedente, AND = MIN entre grupos, NO = 1 − μ
MATCH (suj:EvaluacionAdmisibilidad)-[:USA_MODELO]->(:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[an:ANTECEDENTE]->(t:TerminoDifuso)<-[pe:PERTENECE]-(suj)
WITH suj, r, an.grupo AS g, max(CASE WHEN an.negado THEN 1.0 - pe.mu ELSE pe.mu END) AS g_or
WITH suj, r, min(g_or) AS alfa
MERGE (suj)-[ac:ACTIVA]->(r) SET ac.alfa = alfa;
// F3 · Implicación MIN, agregación MAX y centroide discreto (1001 puntos del universo de salida)
MATCH (suj:EvaluacionAdmisibilidad)-[:USA_MODELO]->(m:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[:CONSECUENTE]->(t:TerminoDifuso)<-[:TIENE_TERMINO]-(vo:VariableDifusa),
      (suj)-[ac:ACTIVA]->(r)
WITH suj, m, vo, t, max(ac.alfa) AS alfa
WITH suj, m, vo, collect({c: t.centro, s: t.sigma, f: t.tipo_funcion, a: alfa}) AS cons
UNWIND range(0, m.puntos - 1) AS i
WITH suj, vo, cons, vo.universo_min + i * (vo.universo_max - vo.universo_min) / toFloat(m.puntos - 1) AS z
WITH suj, vo, z, [k IN cons |
       CASE WHEN k.a < (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END)
            THEN k.a
            ELSE (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END) END] AS cortes
WITH suj, vo, z, reduce(mx = 0.0, x IN cortes | CASE WHEN x > mx THEN x ELSE mx END) AS mu
WITH suj, vo, sum(z * mu) AS num, sum(mu) AS den
MERGE (suj)-[d:DEFUZZIFICA]->(vo) SET d.z = CASE WHEN den > 0 THEN num / den ELSE null END;

// ADM-F07 · Puente: calidad = etiqueta dominante en z*; topes crisp (día hábil + fin de semana; DESCONOCIDO esencial)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)-[d:DEFUZZIFICA]->(vo:VariableDifusa {id:'V-ADM-CAL'})-[:TIENE_TERMINO]->(t:TerminoDifuso)
WITH p, ea, d.z AS z, t, exp(-1.0 * (d.z - t.centro)^2 / (2.0 * t.sigma^2)) AS m
ORDER BY m DESC
WITH p, ea, z, collect(t.etiqueta)[0] AS dominante
MATCH (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario), (rg:Regla {id:'ADM-F07'})
WITH p, ea, r, rg, z, dominante, (r.incluye_habil = true AND r.incluye_finde = true) AS tipos_dia,
     size([(p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[dd:DECLARA]->(:Nutriente) WHERE dd.valor = 'DESCONOCIDO' | 1]) > 0 AS desconocido_esencial
WITH p, ea, r, rg, z, dominante, tipos_dia, desconocido_esencial,
     CASE WHEN dominante = 'alta' AND (NOT tipos_dia OR desconocido_esencial) THEN 'MEDIA'
          WHEN dominante = 'alta' THEN 'ALTA' WHEN dominante = 'media' THEN 'MEDIA' ELSE 'BAJA' END AS calidad
SET ea.indice_calidad = round(z * 100) / 100.0, ea.etiqueta_difusa = dominante, ea.calidad_registro = calidad,
    ea.tope_aplicado = CASE WHEN calidad <> toUpper(dominante) THEN (CASE WHEN desconocido_esencial THEN 'DESCONOCIDO_ESENCIAL' ELSE 'FALTA_TIPO_DE_DIA' END) ELSE 'NINGUNO' END,
    ea.capa_difusa_estado = 'EJECUTADA', ea.resultado_provisional = true, r.calidad_registro = calidad
CREATE (ea)-[:REGISTRA]->(tz:PasoTraza {regla:'ADM-F07', orden:45, efecto:'CALIDAD', valor:calidad,
        texto:'Índice de calidad ' + toString(round(z * 10) / 10.0) + ' (dominante: ' + dominante + '); calidad informada: ' + calidad})
CREATE (tz)-[:APLICA_REGLA]->(rg)
CREATE (tz)-[:SE_APOYA_EN]->(r);

// META-05 · Propagación del veredicto no admisible a los 4 nutrientes (DERIVAR ≠ FUERA_DE_ALCANCE)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad), (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
WHERE ea.veredicto <> 'ADMISIBLE'
MATCH (rg:Regla {id:'META-05'})
WITH ea, e, rg,
     CASE ea.veredicto WHEN 'DERIVAR' THEN 'FUERA_DE_ALCANCE' WHEN 'FUERA_DE_ALCANCE' THEN 'FUERA_DE_ALCANCE' ELSE 'INFORMACION_INSUFICIENTE' END AS est
SET e.motivo_fuera_alcance = CASE ea.veredicto WHEN 'DERIVAR' THEN 'DERIVACION' WHEN 'FUERA_DE_ALCANCE' THEN 'CRITERIO_ALCANCE' ELSE null END,
    e.capa_difusa_estado = CASE ea.veredicto WHEN 'DERIVAR' THEN 'NO_APLICA_DERIVACION'
                                             WHEN 'FUERA_DE_ALCANCE' THEN 'NO_APLICA_FUERA_DE_ALCANCE' ELSE 'NO_APLICA_DATOS' END
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'META-05', orden:15, efecto:'ESTADO', estado_propuesto:est,
        texto:'Se replica el veredicto de admisibilidad (' + ea.veredicto + ')'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(ea);
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(:EvaluacionAdmisibilidad)-[:INTERRUMPIDA_POR]->(c), (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
MERGE (e)-[:INTERRUMPIDA_POR {regla:'META-05'}]->(c);
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(:EvaluacionAdmisibilidad)-[:EXCLUIDA_POR]->(c), (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
MERGE (e)-[:EXCLUIDA_POR {regla:'META-05'}]->(c);

// ====================================================== GRUPO 2 · Genéricas por nutriente
// G-12 · Condición ESPECÍFICA de un nutriente: solo ese nutriente queda FUERA_DE_ALCANCE (Q5)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true})-[:EVALUA]->(n:Nutriente),
      (p)-[pr:PRESENTA]->(c:CondicionDerivacion {alcance:'ESPECIFICA'})-[:AFECTA_A]->(n)
WHERE pr.estado = 'PRESENTE'
MATCH (rg:Regla {id:'G-12'}), (med:Usuario {id:'MED-01'})
SET e.bloqueada = true, e.motivo_fuera_alcance = 'DERIVACION', e.capa_difusa_estado = 'NO_APLICA_DERIVACION'
MERGE (e)-[:INTERRUMPIDA_POR {regla:'G-12'}]->(c)
MERGE (e)-[:SE_DERIVA_A]->(med)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-12', orden:18, efecto:'ESTADO', estado_propuesto:'FUERA_DE_ALCANCE',
        texto:c.nombre + ': se deriva solo para ' + n.nombre + '; los demás nutrientes siguen'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(c);

// G-15 · Ingesta estimada sin doble conteo (alimentos + rótulos + suplementos)
MATCH (e:EvaluacionNutriente {habilitada:true, bloqueada:false})
SET e.ingesta_dietaria = 0.0, e.aporte_suplementos = 0.0, e.ingesta_alcance = 'TOTAL_REGISTRO',
    e.declaracion_desconocida = false, e.suplemento_frecuencia_desconocida = false;
//   (a) contenido natural (si el alimento tiene rótulo para ese nutriente, manda el rótulo)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[ap:APORTA]->(n)
WITH e, cn, ap, size([(a)-[:DECLARA]->(n) | 1]) AS tiene_rotulo
WHERE cn.estado_frecuencia = 'CONOCIDO' AND tiene_rotulo = 0
WITH e, sum(cn.frecuencia_semanal / 7.0 * ap.cantidad) AS s
SET e.ingesta_dietaria = e.ingesta_dietaria + s;
//   (b) rótulo que declara el nutriente (G-10)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[d:DECLARA {valor:'SI'}]->(n)
WHERE cn.estado_frecuencia = 'CONOCIDO'
WITH e, sum(cn.frecuencia_semanal / 7.0 * d.contenido) AS s
SET e.ingesta_dietaria = e.ingesta_dietaria + s;
//   (c) rótulo DESCONOCIDO: el subtotal queda PARCIAL (nunca cero ni suficiente)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[:DECLARA {valor:'DESCONOCIDO'}]->(n)
SET e.declaracion_desconocida = true, e.ingesta_alcance = 'PARCIAL';
//   (d) suplementos con frecuencia real conocida: dosis × tomas realizadas / 28 días
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[tm:TOMA]->(:Suplemento)-[ct:CONTIENE]->(n)
WHERE tm.frecuencia_conocida = 'SI'
WITH e, sum(ct.dosis * tm.tomas_realizadas_28d / 28.0) AS s
SET e.aporte_suplementos = e.aporte_suplementos + s;
//   (e) suplemento con frecuencia desconocida o consumo sin frecuencia: PARCIAL
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[tm:TOMA]->(:Suplemento)-[:CONTIENE]->(n)
WHERE tm.frecuencia_conocida <> 'SI'
SET e.suplemento_frecuencia_desconocida = true, e.ingesta_alcance = 'PARCIAL';
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
WITH e, r, size([(p)-[:REGISTRA]->(c:Consumo) WHERE c.estado_frecuencia <> 'CONOCIDO' | 1]) AS sin_frecuencia
WHERE r.relevamiento_cerrado <> 'SI' OR sin_frecuencia > 0
SET e.ingesta_alcance = 'PARCIAL';
//   (f) referencia por edad y sexo (CA-05, FE-12) e ingesta relativa
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente)-[:TIENE_REFERENCIA]->(vr:ValorReferencia)
WHERE p.edad >= vr.edad_min AND p.edad <= vr.edad_max AND (vr.sexo = 'AMBOS' OR vr.sexo = p.sexo)
SET e.valor_referencia = vr.valor, e.unidad = vr.unidad,
    e.ingesta_estimada = round((e.ingesta_dietaria + e.aporte_suplementos) * 1000) / 1000.0,
    e.ingesta_relativa = round(1000 * 100.0 * (e.ingesta_dietaria + e.aporte_suplementos) / vr.valor) / 1000.0,
    e.ingesta_relativa_dietaria = round(1000 * 100.0 * e.ingesta_dietaria / vr.valor) / 1000.0
MERGE (e)-[:COMPARA_CON]->(vr);

// ---- Fuentes verificadas (se evalúan antes que las alertas: META-01)
// G-14 · Ingesta total ≥ referencia con calidad ALTA o MEDIA
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false, ingesta_alcance:'TOTAL_REGISTRO'}),
      (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario), (e)-[:COMPARA_CON]->(vr:ValorReferencia)
WHERE r.calidad_registro IN ['ALTA', 'MEDIA'] AND e.ingesta_estimada >= vr.valor
MATCH (rg:Regla {id:'G-14'})
SET e.fuente_verificada = 'SI', e.tipo_fuente_verificada = CASE WHEN e.aporte_suplementos > 0 THEN 'DIETA_Y_SUPLEMENTO' ELSE 'DIETARIA' END
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-14', orden:50, efecto:'FUENTE_VERIFICADA',
        texto:'Ingesta total ' + toString(e.ingesta_estimada) + ' ' + vr.unidad + '/día ≥ referencia ' + toString(vr.valor)})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(vr);
// FE-10 · Hierro hemo ALTO con alarmas y antecedentes descartados (valoración de la nutricionista)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}),
      (p)-[:TIENE_HECHO]->(h1:Hecho {atributo:'nivel_hemo', valor:'ALTO'}),
      (p)-[:TIENE_HECHO]->(h2:Hecho {atributo:'alarmas', valor:'DESCARTADAS'}),
      (p)-[:TIENE_HECHO]->(h3:Hecho {atributo:'antecedentes_perdida', valor:'DESCARTADOS'})
MATCH (rg:Regla {id:'FE-10'})
SET e.fuente_verificada = 'SI', e.tipo_fuente_verificada = 'HEMO'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'FE-10', orden:51, efecto:'FUENTE_VERIFICADA', texto:'Consumo regular de hierro hemo con alarmas y antecedentes descartados'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(h1)
CREATE (t)-[:SE_APOYA_EN]->(h2)
CREATE (t)-[:SE_APOYA_EN]->(h3);
// VD-03 · Suplemento regular ≥ 15 µg/día o indicado por el médico
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'VD', habilitada:true, bloqueada:false}),
      (p)-[tm:TOMA]->(s:Suplemento)-[ct:CONTIENE]->(:Nutriente {codigo:'VD'})
WHERE tm.indicado_por_medico = 'SI'
   OR (tm.frecuencia_conocida = 'SI' AND tm.regularidad = 'REGULAR' AND ct.dosis * tm.tomas_realizadas_28d / 28.0 >= 15)
MATCH (rg:Regla {id:'VD-03'})
SET e.fuente_verificada = 'SI', e.tipo_fuente_verificada = 'SUPLEMENTO'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'VD-03', orden:52, efecto:'FUENTE_VERIFICADA', texto:'Suplemento de vitamina D verificado'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);
// B12-07 (rama crisp) · B12 inyectable indicada por el médico
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12', habilitada:true, bloqueada:false}),
      (p)-[tm:TOMA]->(s:Suplemento {tipo:'INYECTABLE'})-[:CONTIENE]->(:Nutriente {codigo:'B12'})
WHERE tm.indicado_por_medico = 'SI'
MATCH (rg:Regla {id:'B12-07'})
SET e.fuente_verificada = 'SI', e.tipo_fuente_verificada = 'SUPLEMENTO_INDICADO'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'B12-07', orden:53, efecto:'FUENTE_VERIFICADA', texto:'B12 inyectable indicada por el médico'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);

// ---- Investigación de fuentes alternativas (reglas de encadenamiento: no asignan estado)
// R05 / CA-01 / FE-01 / R14 · el patrón (con herencia ES_UN*) exige investigar fuentes alternativas
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:SIGUE]->(pa:PatronAlimentario)-[:ES_UN*0..3]->(:PatronAlimentario)-[ra:REQUIERE_FUENTE_ALTERNATIVA]->(n)
MATCH (rg:Regla {id: ra.regla})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla: ra.regla, orden:55, efecto:'INVESTIGAR',
        texto:'Patrón ' + pa.codigo + ': investigar fuentes alternativas de ' + n.nombre + ' (fortificados y suplementos)'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(pa);
// CA-01 por ausencia de lácteos registrada (aunque el patrón no los excluya)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', habilitada:true, bloqueada:false})
WITH e, size([(p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[:PERTENECE_A]->(:GrupoAlimento {codigo:'LACTEOS'}) | 1]) AS lacteos,
     size([(e)-[:REGISTRA]->(x:PasoTraza {regla:'CA-01'}) | 1]) AS ya_investigado
WHERE lacteos = 0 AND ya_investigado = 0
MATCH (rg:Regla {id:'CA-01'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'CA-01', orden:55, efecto:'INVESTIGAR', texto:'Sin lácteos registrados: investigar fuentes alternativas de calcio'})
CREATE (t)-[:APLICA_REGLA]->(rg);

// ---- Datos desconocidos (META-06: DESCONOCIDO no activa ni alerta ni descarte)
// G-04 + META-04 · Rótulo desconocido: un único DatoFaltante por producto aunque sirva a varios nutrientes
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[:DECLARA {valor:'DESCONOCIDO'}]->(n)
WHERE e.fuente_verificada <> 'SI'
WITH p, e, n, cn, a
MATCH (rg:Regla {id:'G-04'})
MERGE (df:DatoFaltante {clave: p.id + '|' + a.id})
SET df.texto = 'Ver en el envase de «' + a.nombre + '» si declara cada nutriente y cuánto por porción',
    df.regla = 'G-04', df.pregunta = 'Q14', df.tipo = 'ROTULO'
MERGE (e)-[:GENERA]->(df)
MERGE (df)-[:SIRVE_A]->(n)
MERGE (df)-[:SOBRE]->(a)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-04', orden:60, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE',
        texto:'Rótulo desconocido de ' + a.nombre + ' para ' + n.nombre + ': no se cuenta como cero ni como suficiente'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(cn);
// CA-02 · Sin lácteos y la alternativa tiene contenido desconocido
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', habilitada:true, bloqueada:false}),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[:DECLARA {valor:'DESCONOCIDO'}]->(:Nutriente {codigo:'CA'})
WITH e, cn, size([(p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[:PERTENECE_A]->(:GrupoAlimento {codigo:'LACTEOS'}) | 1]) AS lacteos
WHERE e.fuente_verificada <> 'SI' AND lacteos = 0
MATCH (rg:Regla {id:'CA-02'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'CA-02', orden:61, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE',
        texto:'Sin lácteos y con fuentes alternativas de contenido desconocido'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(cn);
// G-03 · Suplemento con regularidad vaga («cuando me acuerdo», Q28)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[tm:TOMA]->(s:Suplemento)-[:CONTIENE]->(n)
WHERE tm.frecuencia_conocida <> 'SI' AND e.fuente_verificada <> 'SI'
MATCH (rg:Regla {id:'G-03'})
MERGE (df:DatoFaltante {clave: p.id + '|' + s.id})
SET df.texto = 'Frecuencia real de «' + s.nombre + '»: tomas en las últimas 4 semanas y fecha de la última dosis',
    df.regla = 'G-03', df.pregunta = 'Q28', df.tipo = 'FRECUENCIA_SUPLEMENTO'
MERGE (e)-[:GENERA]->(df)
MERGE (df)-[:SIRVE_A]->(n)
MERGE (df)-[:SOBRE]->(s)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-03', orden:62, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE',
        texto:'«Cuando me acuerdo» no permite asumir cobertura de ' + n.nombre})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);
// G-01 · Suplemento sin dosis conocida
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:TOMA]->(s:Suplemento)-[ct:CONTIENE]->(n)
WHERE ct.estado_dosis = 'DESCONOCIDA' AND e.fuente_verificada <> 'SI'
MATCH (rg:Regla {id:'G-01'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-01', orden:63, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE', texto:'Suplemento sin dosis conocida'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);
// B12-03 · Vegano con suplementación DESCONOCIDA
MATCH (p:Paciente {suplementos:'DESCONOCIDO'})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12', habilitada:true, bloqueada:false}),
      (p)-[:SIGUE]->(:PatronAlimentario {codigo:'VEGANO'})
MATCH (rg:Regla {id:'B12-03'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'B12-03', orden:64, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE', texto:'Vegano: falta saber si toma suplemento de B12'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(p);
// G-06 · Calidad BAJA: bloquea las conclusiones cuantitativas y pide ampliar el registro
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario {calidad_registro:'BAJA'})
MATCH (rg:Regla {id:'G-06'}), (n:Nutriente {codigo: e.nutriente})
MERGE (df:DatoFaltante {clave: p.id + '|AMPLIAR_REGISTRO'})
SET df.texto = 'Ampliar el registro a 3–7 días que incluyan días hábiles y fin de semana', df.regla = 'G-06', df.pregunta = 'Q1', df.tipo = 'REGISTRO'
MERGE (e)-[:GENERA]->(df)
MERGE (df)-[:SIRVE_A]->(n)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-06', orden:65, efecto:'ESTADO', estado_propuesto:'INFORMACION_INSUFICIENTE', texto:'Calidad del registro BAJA: no se sostienen conclusiones cuantitativas'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(r);

// ---- Reglas específicas con negaciones explícitas
// R06 · Vegano sin fortificados ni suplementos de B12 (NO explícitos)
MATCH (p:Paciente {suplementos:'NO'})-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12', habilitada:true, bloqueada:false}),
      (p)-[:SIGUE]->(pa:PatronAlimentario {codigo:'VEGANO'})
WITH e, pa, size([(p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[d:DECLARA]->(:Nutriente {codigo:'B12'}) WHERE d.valor IN ['SI', 'DESCONOCIDO'] | 1]) AS fortificados_b12,
     size([(p)-[:REGISTRA]->(:Consumo)-[:DE]->(:Alimento)-[:APORTA]->(:Nutriente {codigo:'B12'}) | 1]) AS animales_b12
WHERE fortificados_b12 = 0 AND animales_b12 = 0
MATCH (rg:Regla {id:'R06'})
SET e.fundamento = 'AUSENCIA_FUENTES'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'R06', orden:70, efecto:'ESTADO', estado_propuesto:'POSIBLE_INGESTA_INSUFICIENTE',
        texto:'Vegano sin fortificados con B12 ni suplemento (negaciones explícitas)'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(pa);
// FE-02 · Inhibidores: solo cuentan si coinciden con una comida principal (el café de media mañana no inhibe)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[:CONTIENE_FACTOR]->(:Inhibidor)-[:REDUCE_ABSORCION]->(:Nutriente {codigo:'FE'}),
      (cn)-[o:OCURRE_EN]->(cm:Comida)
WITH e, a, cm, o
MATCH (rg:Regla {id:'FE-02'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'FE-02', orden:72, efecto: CASE WHEN o.coincide_con_comida = 'SI' AND cm.principal THEN 'EVIDENCIA' ELSE 'DESCARTADO' END,
        texto: a.nombre + ' en ' + cm.momento + ' (' + toString(o.veces_semana) + '/sem): ' +
               CASE WHEN o.coincide_con_comida = 'SI' AND cm.principal THEN 'cuenta como inhibidor' ELSE 'no coincide con la comida, no se cuenta' END})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(cm);
// FE-03 · Hemo y no hemo bajos sin suplemento confirmado
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}),
      (p)-[:TIENE_HECHO]->(h1:Hecho {atributo:'nivel_hemo'}), (p)-[:TIENE_HECHO]->(h2:Hecho {atributo:'nivel_no_hemo', valor:'BAJO'}),
      (p)-[:TIENE_HECHO]->(h3:Hecho {atributo:'suplemento_hierro', valor:'NO'})
WHERE h1.valor IN ['NULO', 'BAJO'] AND e.fuente_verificada <> 'SI'
MATCH (rg:Regla {id:'FE-03'})
SET e.fundamento = 'AUSENCIA_FUENTES'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'FE-03', orden:73, efecto:'ESTADO', estado_propuesto:'POSIBLE_INGESTA_INSUFICIENTE',
        texto:'Hierro hemo ' + h1.valor + ' y no hemo BAJO, sin suplemento confirmado'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(h1)
CREATE (t)-[:SE_APOYA_EN]->(h2)
CREATE (t)-[:SE_APOYA_EN]->(h3);
// FE-04 + FE-09 (modificada por Q19) · Vegetariano con mucho no hemo y potenciadores: no alertar por ausencia de hemo, pero revisar
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}),
      (p)-[:SIGUE]->(:PatronAlimentario)-[:ES_UN*0..3]->(:PatronAlimentario {codigo:'VEGETARIANO'}),
      (p)-[:TIENE_HECHO]->(h1:Hecho {atributo:'nivel_no_hemo', valor:'ALTO'}), (p)-[:TIENE_HECHO]->(h2:Hecho {atributo:'potenciadores', valor:'FRECUENTES'})
MATCH (r4:Regla {id:'FE-04'}), (r9:Regla {id:'FE-09'}), (q:PreguntaExperta {id:'Q19'})
SET e.biodisponibilidad = 'FAVORABLE'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'FE-04', orden:74, efecto:'BLOQUEA_ALERTA', texto:'No se alerta por la sola ausencia de hierro hemo'})
CREATE (t)-[:APLICA_REGLA]->(r4)
CREATE (t)-[:SE_APOYA_EN]->(h1)
CREATE (t)-[:SE_APOYA_EN]->(h2)
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'FE-09', tipo:'REVISION', destinatario:'NUTRICIONISTA',
        texto:'Legumbres con cítricos no alcanzan para concluir suficiencia de hierro: revisar cantidades, fortificados y antecedentes'})
CREATE (adv)-[:SE_APOYA_EN]->(q);
// FE-11 · Calcio tomado con las comidas = inhibidor del hierro no hemo (interacción SM-CA → SM-FE)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}),
      (p)-[tm:TOMA]->(s:Suplemento)-[:CONTIENE]->(ca:Nutriente {codigo:'CA'})-[:INHIBE_ABSORCION]->(:Nutriente {codigo:'FE'})
WHERE tm.momento_toma = 'CON_COMIDAS'
MATCH (rg:Regla {id:'FE-11'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'FE-11', tipo:'ABSORCION', destinatario:'NUTRICIONISTA',
        texto:'El suplemento «' + s.nombre + '» se toma con las comidas: el calcio reduce la absorción del hierro no hemo'})
CREATE (adv)-[:SE_APOYA_EN]->(s)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'FE-11', orden:75, efecto:'ADVERTENCIA', texto:'Interacción calcio → hierro no hemo'})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);
// CA-06 · El suplemento calcio + D es un hecho compartido por SM-CA y SM-VD (cada uno lee su dosis)
MATCH (p:Paciente)-[:TOMA]->(s:Suplemento {tipo:'CALCIO_D'})-[ct:CONTIENE]->(n:Nutriente),
      (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n)
MATCH (rg:Regla {id:'CA-06'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'CA-06', orden:76, efecto:'DATO_COMPARTIDO', texto:'Suplemento compartido CA/VD: aporta ' + toString(ct.dosis) + ' ' + ct.unidad + ' de ' + n.nombre})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(s);
// CA-07 (nueva, Q15) · Calcio de vegetales con baja biodisponibilidad
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', habilitada:true, bloqueada:false}),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[ap:APORTA {biodisponibilidad:'BAJA'}]->(:Nutriente {codigo:'CA'})
WITH p, e, cn, a
MATCH (q:PreguntaExperta {id:'Q15'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'CA-07', tipo:'BIODISPONIBILIDAD', destinatario:'NUTRICIONISTA',
        texto:'El calcio de ' + a.nombre + ' tiene baja biodisponibilidad (oxalatos): no equivale a lácteos ni a bebidas fortificadas'})
CREATE (adv)-[:SE_APOYA_EN]->(cn)
CREATE (adv)-[:SE_APOYA_EN]->(q);
// G-09 · Fuentes no confiables declaradas por el paciente o rótulo que dice NO
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:DECLARA_FUENTE]->(f:FuenteNoConfiable)-[na:NO_APORTA]->(n)
MATCH (rg:Regla {id:'G-09'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'G-09', tipo:'NOTA', destinatario:'NUTRICIONISTA', texto: f.nombre + ' no aporta ' + n.nombre + ' utilizable (' + na.motivo + ')'})
CREATE (adv)-[:SE_APOYA_EN]->(f)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-09', orden:56, efecto:'DESCARTA_FUENTE', texto: f.nombre + ' no cuenta como fuente'})
CREATE (t)-[:APLICA_REGLA]->(rg);
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(a:Alimento)-[:DECLARA {valor:'NO'}]->(n)
WITH p, e, n, cn, a
MATCH (rg:Regla {id:'G-09'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-09', orden:56, efecto:'DESCARTA_FUENTE', texto:'El rótulo de ' + a.nombre + ' no declara ' + n.nombre})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:SE_APOYA_EN]->(cn);
// G-11 · Medicamentos que reducen la absorción: advertencia provisional (PARAM_USO_PROLONGADO pendiente, Q29)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {habilitada:true, bloqueada:false})-[:EVALUA]->(n:Nutriente),
      (p)-[u:USA]->(f:Medicamento)-[:REDUCE_ABSORCION]->(n)
MATCH (rg:Regla {id:'G-11'}), (med:Usuario {id:'MED-01'}), (cc:CriterioCandidato {nombre:'PARAM_USO_PROLONGADO'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'G-11', tipo:'MEDICACION', destinatario:'MEDICO', provisional:true,
        texto:'Uso de ' + f.nombre + ' hace ' + toString(u.tiempo_uso_meses) + ' meses: puede reducir la absorción de ' + n.nombre + '; sugerir consulta médica'})
CREATE (adv)-[:RECOMIENDA_CONSULTA]->(med)
CREATE (adv)-[:SE_APOYA_EN]->(f)
CREATE (adv)-[:USA_CRITERIO]->(cc)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-11', orden:80, efecto:'ADVERTENCIA', texto:'Advertencia por medicación (no cambia el estado)'})
CREATE (t)-[:APLICA_REGLA]->(rg);
// B12-12 · Edad ≥ PARAM_EDAD_ABSORCION con B12 solo de origen animal (Q23)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12', habilitada:true, bloqueada:false}),
      (cc:CriterioCandidato {nombre:'PARAM_EDAD_ABSORCION'})
WITH p, e, cc, size([(p)-[:TOMA]->(:Suplemento)-[:CONTIENE]->(:Nutriente {codigo:'B12'}) | 1]) AS supl_b12
WHERE p.edad >= toInteger(cc.valor) AND supl_b12 = 0
MATCH (rg:Regla {id:'B12-12'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'B12-12', tipo:'EDAD', destinatario:'NUTRICIONISTA',
        texto:'Edad ' + toString(p.edad) + ' años con B12 solo de alimentos: la absorción puede ser menor'})
CREATE (adv)-[:USA_CRITERIO]->(cc)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'B12-12', orden:81, efecto:'ADVERTENCIA', texto:'Advertencia por edad'})
CREATE (t)-[:APLICA_REGLA]->(rg);
// G-07 (CA) · Alerta cuantitativa: el umbral (70 % de la referencia, Q9) sigue CANDIDATO → META-07
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', habilitada:true, bloqueada:false, ingesta_alcance:'TOTAL_REGISTRO'}),
      (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario), (:Nutriente {codigo:'CA'})-[:UMBRAL_ALERTA]->(cc:CriterioCandidato)
WHERE r.calidad_registro IN ['ALTA', 'MEDIA'] AND e.fuente_verificada <> 'SI'
MATCH (rg:Regla {id:'G-07'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-07', orden:85,
        efecto: CASE WHEN cc.estado_validacion = 'VALIDADO' THEN 'ESTADO' ELSE 'PENDIENTE' END,
        estado_propuesto: CASE WHEN cc.estado_validacion = 'VALIDADO' AND e.ingesta_relativa < toFloat(cc.valor) THEN 'POSIBLE_INGESTA_INSUFICIENTE' ELSE null END,
        criterio: cc.nombre,
        texto:'Ingesta ' + toString(e.ingesta_relativa) + ' % de la referencia; umbral ' + cc.valor + ' % en estado ' + cc.estado_validacion})
CREATE (t)-[:APLICA_REGLA]->(rg)
CREATE (t)-[:USA_CRITERIO]->(cc);

// ====================================================== CAPA DIFUSA POR NUTRIENTE (PI3)
// Índice de exposición UVB efectiva (Bataller): E = 100 · f_tiempo · f_UV · f_piel · f_protector · f_fototipo
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'VD', habilitada:true, bloqueada:false}),
      (p)-[:TIENE_HABITO_DE]->(x:ExposicionSolar {estado_tiempo:'CONOCIDO'}),
      (p)-[:RESIDE_EN]->(:Localidad)-[:TIENE_IUV]->(u:IndiceUVMensual)
WHERE u.mes = e.mes_consulta
MATCH (fp:FactorExposicion {codigo:'PIEL', valor_entrada: x.cobertura_vestimenta}),
      (fr:FactorExposicion {codigo:'PROTECTOR', valor_entrada: x.protector_solar}),
      (ff:FactorExposicion {codigo:'FOTOTIPO', valor_entrada: x.fototipo})
WITH e, x, u, fp, fr, ff,
     CASE WHEN x.a_traves_de_vidrio = 'SI' THEN 0.0 WHEN x.tiempo_aire_libre_h / 7.0 > 1 THEN 1.0 ELSE x.tiempo_aire_libre_h / 7.0 END AS ft,
     CASE WHEN u.iuv / 10.0 > 1 THEN 1.0 ELSE u.iuv / 10.0 END AS fuv
SET e.exposicion_uvb = round(1000 * 100 * ft * fuv * fp.coeficiente * fr.coeficiente * ff.coeficiente) / 1000.0,
    e.factores_exposicion = [ft, fuv, fp.coeficiente, fr.coeficiente, ff.coeficiente];
// VD-11/21 (modificadas) · clasificación = etiqueta dominante del índice (buena → ADECUADA; si no → LIMITADA)
MATCH (e:EvaluacionNutriente {nutriente:'VD'})-[:EVALUA]->(:Nutriente), (v:VariableDifusa {id:'V-VD-EXP'})-[:TIENE_TERMINO]->(t:TerminoDifuso)
WHERE e.exposicion_uvb IS NOT NULL
WITH e, t, CASE WHEN t.tipo_funcion = 'HOMBRO_IZQ' AND e.exposicion_uvb <= t.centro THEN 1.0
                WHEN t.tipo_funcion = 'HOMBRO_DER' AND e.exposicion_uvb >= t.centro THEN 1.0
                ELSE exp(-1.0 * (e.exposicion_uvb - t.centro)^2 / (2.0 * t.sigma^2)) END AS m
ORDER BY m DESC
WITH e, collect(t.etiqueta)[0] AS dom
SET e.exposicion_dominante = dom, e.clasificacion_exposicion = CASE dom WHEN 'buena' THEN 'ADECUADA' ELSE 'LIMITADA' END;

// Guardas de cada modelo → capa_difusa_estado (DERIVAR / FUERA ya quedaron marcados en META-05 y G-12)
// MD-B12 · G1–G6 de Nuñez: TOTAL, calidad ALTA/MEDIA, fuente crisp no verificada, suplemento NO explícito o con pauta conocida
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'B12', habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
WITH p, e, r, [(p)-[tm:TOMA]->(:Suplemento)-[:CONTIENE]->(:Nutriente {codigo:'B12'}) | tm] AS tomas
SET e.capa_difusa_estado = CASE
      WHEN e.fuente_verificada = 'SI' THEN 'NO_APLICA_FUENTE_CRISP'
      WHEN e.ingesta_alcance <> 'TOTAL_REGISTRO' OR NOT r.calidad_registro IN ['ALTA', 'MEDIA'] THEN 'NO_APLICA_DATOS'
      WHEN size(tomas) = 0 AND p.suplementos IN ['NO', 'SI'] THEN 'HABILITADA'
      WHEN size(tomas) > 0 AND all(t IN tomas WHERE t.frecuencia_conocida = 'SI') THEN 'HABILITADA'
      ELSE 'NO_APLICA_DATOS' END,
    e.adherencia_suplemento = CASE WHEN size(tomas) = 0 THEN 0.0
      WHEN all(t IN tomas WHERE t.frecuencia_conocida = 'SI') THEN 100.0 * tomas[0].tomas_realizadas_28d / tomas[0].pauta_tomas_28d ELSE null END;
MATCH (e:EvaluacionNutriente {nutriente:'B12', capa_difusa_estado:'HABILITADA'})
MATCH (m:ModeloDifuso {id:'MD-B12'}), (vi:VariableDifusa {id:'V-B12-ING'}), (va:VariableDifusa {id:'V-B12-ADH'})
MERGE (e)-[:USA_MODELO]->(m)
MERGE (e)-[i1:ENTRADA]->(vi) SET i1.valor = e.ingesta_relativa_dietaria
MERGE (e)-[i2:ENTRADA]->(va) SET i2.valor = e.adherencia_suplemento;
// MD-FE · compuerta de Santibañez: hemo NULO/BAJO, potenciadores bajos, antecedentes descartados, sin suplemento
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
WITH p, e, r,
     [(p)-[:TIENE_HECHO]->(h1:Hecho {atributo:'nivel_hemo'}) | h1.valor][0] AS hemo,
     [(p)-[:TIENE_HECHO]->(h2:Hecho {atributo:'potenciadores'}) | h2.valor][0] AS pot,
     [(p)-[:TIENE_HECHO]->(h3:Hecho {atributo:'antecedentes_perdida'}) | h3.valor][0] AS ant,
     [(p)-[:TIENE_HECHO]->(h4:Hecho {atributo:'suplemento_hierro'}) | h4.valor][0] AS sup
SET e.capa_difusa_estado = CASE
      WHEN e.fuente_verificada = 'SI' THEN 'NO_APLICA_FUENTE_CRISP'
      WHEN NOT r.calidad_registro IN ['ALTA', 'MEDIA'] OR e.ingesta_alcance <> 'TOTAL_REGISTRO' THEN 'NO_APLICA_DATOS'
      WHEN hemo IN ['NULO', 'BAJO'] AND pot IN ['AUSENTES', 'BAJOS'] AND ant = 'DESCARTADOS' AND sup = 'NO' THEN 'HABILITADA'
      ELSE 'NO_APLICA_COMPUERTA' END;
// Entrada 1: porciones/semana de alimentos cuyos grupos son FUENTE_DE hierro no hemo
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', capa_difusa_estado:'HABILITADA'})
OPTIONAL MATCH (p)-[:REGISTRA]->(cn:Consumo)-[:DE]->(:Alimento)-[:PERTENECE_A]->(:GrupoAlimento)-[:FUENTE_DE {forma:'NO_HEMO'}]->(:Nutriente {codigo:'FE'})
WITH e, sum(coalesce(cn.frecuencia_semanal, 0.0)) AS noh
SET e.consumo_hierro_no_hemo = noh;
// Entrada 2: comidas/semana con inhibidor coincidente (FE-02)…
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', capa_difusa_estado:'HABILITADA'})
OPTIONAL MATCH (p)-[:REGISTRA]->(ci:Consumo)-[:DE]->(:Alimento)-[:CONTIENE_FACTOR]->(:Inhibidor)-[:REDUCE_ABSORCION]->(:Nutriente {codigo:'FE'}),
               (ci)-[o:OCURRE_EN]->(cm:Comida)
WHERE o.coincide_con_comida = 'SI' AND cm.principal = true
WITH e, sum(coalesce(o.veces_semana, 0.0)) AS inh
SET e.inhibidores_en_comidas = inh;
// …más tomas semanales de calcio con las comidas (FE-11: interacción SM-CA → SM-FE)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'FE', capa_difusa_estado:'HABILITADA'}),
      (p)-[tm:TOMA]->(:Suplemento)-[:CONTIENE]->(:Nutriente {codigo:'CA'})
WHERE tm.momento_toma = 'CON_COMIDAS' AND tm.frecuencia_conocida = 'SI'
WITH e, sum(tm.tomas_realizadas_28d / 4.0) AS inh_supl
SET e.inhibidores_en_comidas = e.inhibidores_en_comidas + inh_supl;
MATCH (e:EvaluacionNutriente {nutriente:'FE', capa_difusa_estado:'HABILITADA'})
MATCH (m:ModeloDifuso {id:'MD-FE'}), (vn:VariableDifusa {id:'V-FE-NOH'}), (vi:VariableDifusa {id:'V-FE-INH'})
MERGE (e)-[:USA_MODELO]->(m)
MERGE (e)-[i1:ENTRADA]->(vn) SET i1.valor = e.consumo_hierro_no_hemo
MERGE (e)-[i2:ENTRADA]->(vi) SET i2.valor = e.inhibidores_en_comidas;
// MD-VD · GV1–GV6 de Bataller: aporte oral calculable y E calculable; fuente crisp no verificada
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'VD', habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
SET e.capa_difusa_estado = CASE
      WHEN e.fuente_verificada = 'SI' THEN 'NO_APLICA_FUENTE_CRISP'
      WHEN e.ingesta_alcance <> 'TOTAL_REGISTRO' OR NOT r.calidad_registro IN ['ALTA', 'MEDIA'] OR e.exposicion_uvb IS NULL THEN 'NO_APLICA_DATOS'
      ELSE 'HABILITADA' END;
MATCH (e:EvaluacionNutriente {nutriente:'VD', capa_difusa_estado:'HABILITADA'})
MATCH (m:ModeloDifuso {id:'MD-VD'}), (va:VariableDifusa {id:'V-VD-APO'}), (vx:VariableDifusa {id:'V-VD-EXP'})
MERGE (e)-[:USA_MODELO]->(m)
MERGE (e)-[i1:ENTRADA]->(va) SET i1.valor = e.ingesta_relativa
MERGE (e)-[i2:ENTRADA]->(vx) SET i2.valor = e.exposicion_uvb;
// MD-CA · auxiliar de Ramirez: TOTAL, calidad ALTA/MEDIA, al menos 2 totales diarios con media > 0
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', habilitada:true, bloqueada:false}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
SET e.capa_difusa_estado = CASE
      WHEN e.ingesta_alcance <> 'TOTAL_REGISTRO' OR NOT r.calidad_registro IN ['ALTA', 'MEDIA'] THEN 'NO_APLICA_DATOS'
      WHEN r.totales_diarios_ca IS NULL OR size(r.totales_diarios_ca) < 2 THEN 'NO_APLICA_DATOS'
      ELSE 'HABILITADA' END;
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'CA', capa_difusa_estado:'HABILITADA'}), (p)-[:APORTA_REGISTRO]->(r:RegistroAlimentario)
UNWIND r.totales_diarios_ca AS tot
WITH e, avg(tot) AS media, stDev(tot) AS desvio
MATCH (m:ModeloDifuso {id:'MD-CA'}), (vi:VariableDifusa {id:'V-CA-ING'}), (vv:VariableDifusa {id:'V-CA-VAR'})
SET e.variabilidad_diaria = round(1000 * 100.0 * desvio / media) / 1000.0
MERGE (e)-[:USA_MODELO]->(m)
MERGE (e)-[i1:ENTRADA]->(vi) SET i1.valor = e.ingesta_relativa
MERGE (e)-[i2:ENTRADA]->(vv) SET i2.valor = 100.0 * desvio / media;

// ----------------------------------------------- MOTOR DIFUSO GENÉRICO (pasada B: nutrientes) — mismas F1–F3
MATCH (suj:EvaluacionNutriente)-[:USA_MODELO]->(:ModeloDifuso)-[:DEFINE_VARIABLE]->(v:VariableDifusa)-[:TIENE_TERMINO]->(t:TerminoDifuso)
MATCH (suj)-[en:ENTRADA]->(v)
WITH suj, t, CASE WHEN en.valor < v.universo_min THEN toFloat(v.universo_min)
                  WHEN en.valor > v.universo_max THEN toFloat(v.universo_max) ELSE toFloat(en.valor) END AS x
MERGE (suj)-[pe:PERTENECE]->(t)
SET pe.x = x,
    pe.mu = CASE WHEN t.tipo_funcion = 'HOMBRO_IZQ' AND x <= t.centro THEN 1.0
                 WHEN t.tipo_funcion = 'HOMBRO_DER' AND x >= t.centro THEN 1.0
                 ELSE exp(-1.0 * (x - t.centro)^2 / (2.0 * t.sigma^2)) END;
MATCH (suj:EvaluacionNutriente)-[:USA_MODELO]->(:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[an:ANTECEDENTE]->(t:TerminoDifuso)<-[pe:PERTENECE]-(suj)
WITH suj, r, an.grupo AS g, max(CASE WHEN an.negado THEN 1.0 - pe.mu ELSE pe.mu END) AS g_or
WITH suj, r, min(g_or) AS alfa
MERGE (suj)-[ac:ACTIVA]->(r) SET ac.alfa = alfa;
MATCH (suj:EvaluacionNutriente)-[:USA_MODELO]->(m:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[:CONSECUENTE]->(t:TerminoDifuso)<-[:TIENE_TERMINO]-(vo:VariableDifusa),
      (suj)-[ac:ACTIVA]->(r)
WITH suj, m, vo, t, max(ac.alfa) AS alfa
WITH suj, m, vo, collect({c: t.centro, s: t.sigma, f: t.tipo_funcion, a: alfa}) AS cons
UNWIND range(0, m.puntos - 1) AS i
WITH suj, vo, cons, vo.universo_min + i * (vo.universo_max - vo.universo_min) / toFloat(m.puntos - 1) AS z
WITH suj, vo, z, [k IN cons |
       CASE WHEN k.a < (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END)
            THEN k.a
            ELSE (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END) END] AS cortes
WITH suj, vo, z, reduce(mx = 0.0, x IN cortes | CASE WHEN x > mx THEN x ELSE mx END) AS mu
WITH suj, vo, sum(z * mu) AS num, sum(mu) AS den
MERGE (suj)-[d:DEFUZZIFICA]->(vo) SET d.z = CASE WHEN den > 0 THEN num / den ELSE null END;

// ---- Puentes: del grado difuso a las conclusiones de SENDA (sin quinto estado)
// B12-FZ-05 / FE-F07 / VD-FZ-05 · etiqueta de riesgo con los cortes 33,5 / 66,5 (POLITICA_CORTES_SALIDA)
MATCH (e:EvaluacionNutriente)-[d:DEFUZZIFICA]->(:VariableDifusa {id:'V-RIESGO'}), (e)-[:USA_MODELO]->(m:ModeloDifuso)
WITH e, m, d.z AS z, CASE WHEN d.z < m.corte_bajo THEN 'BAJO' WHEN d.z > m.corte_alto THEN 'ALTO' ELSE 'MODERADO' END AS et
MATCH (rg:Regla {id: CASE e.nutriente WHEN 'B12' THEN 'B12-FZ-05' WHEN 'FE' THEN 'FE-F07' ELSE 'VD-FZ-05' END})
SET e.riesgo_difuso = round(z * 100) / 100.0, e.etiqueta_riesgo = et, e.capa_difusa_estado = 'EJECUTADA',
    e.resultado_provisional = (m.estado_validacion <> 'VALIDADO'),
    e.estado_propuesto_difuso = CASE et WHEN 'ALTO' THEN 'POSIBLE_INGESTA_INSUFICIENTE'
                                         WHEN 'BAJO' THEN (CASE WHEN e.nutriente = 'FE' THEN 'NINGUNO' ELSE 'SIN_SEÑAL_DETECTADA' END)
                                         ELSE 'POLITICA_ZONA_MODERADA' END
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla: rg.id, orden:90,
        efecto: CASE WHEN m.estado_validacion = 'VALIDADO' AND et = 'ALTO' THEN 'ESTADO'
                     WHEN m.estado_validacion = 'VALIDADO' AND et = 'BAJO' AND e.nutriente <> 'FE' THEN 'FUENTE_VERIFICADA'
                     WHEN m.estado_validacion = 'VALIDADO' AND et = 'BAJO' THEN 'INFORMATIVO'
                     ELSE 'PENDIENTE' END,
        estado_propuesto: CASE WHEN m.estado_validacion = 'VALIDADO' AND et = 'ALTO' THEN 'POSIBLE_INGESTA_INSUFICIENTE' ELSE null END,
        criterio: CASE WHEN m.estado_validacion <> 'VALIDADO' THEN 'PARAM_FZ_' + e.nutriente WHEN et = 'MODERADO' THEN 'POLITICA_ZONA_MODERADA' ELSE null END,
        grado: round(z * 100) / 100.0,
        texto:'Riesgo difuso ' + toString(round(z * 10) / 10.0) + ' → ' + et + CASE WHEN m.estado_validacion <> 'VALIDADO' THEN ' (provisional: parámetros CANDIDATOS)' ELSE '' END})
CREATE (t)-[:APLICA_REGLA]->(rg);
// Con modelo VALIDADO y riesgo BAJO, B12 y VD verifican la fuente por la vía difusa
MATCH (e:EvaluacionNutriente)-[:REGISTRA]->(:PasoTraza {efecto:'FUENTE_VERIFICADA', orden:90})
SET e.fuente_verificada = 'SI', e.tipo_fuente_verificada = 'DIFUSA';
// Traza de las reglas difusas activadas (α > 0,01) para la explicación
MATCH (e)-[ac:ACTIVA]->(r:ReglaDifusa)
WHERE (e:EvaluacionNutriente OR e:EvaluacionAdmisibilidad) AND ac.alfa > 0.01
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla: r.id, orden: CASE WHEN e:EvaluacionAdmisibilidad THEN 44 ELSE 89 END, efecto:'ACTIVACION_DIFUSA', grado: round(ac.alfa * 1000) / 1000.0,
        texto: r.texto + ' · α = ' + toString(round(ac.alfa * 1000) / 1000.0)})
CREATE (t)-[:APLICA_REGLA]->(r);
// VD-FZ-05 · componente limitante = regla de riesgo con mayor α (FZ-01 AMBOS, FZ-02 DIETA, FZ-03 EXPOSICION)
MATCH (e:EvaluacionNutriente {nutriente:'VD', capa_difusa_estado:'EJECUTADA'})-[ac:ACTIVA]->(r:ReglaDifusa)
WHERE r.id IN ['VD-FZ-01', 'VD-FZ-02', 'VD-FZ-03']
WITH e, r, ac ORDER BY ac.alfa DESC
WITH e, collect(r.id)[0] AS top
SET e.componente_limitante = CASE WHEN e.etiqueta_riesgo = 'BAJO' THEN 'NINGUNO'
                                  WHEN top = 'VD-FZ-01' THEN 'AMBOS' WHEN top = 'VD-FZ-02' THEN 'DIETA' ELSE 'EXPOSICION' END;
MATCH (e:EvaluacionNutriente {nutriente:'VD'}) WHERE e.capa_difusa_estado = 'NO_APLICA_DATOS' AND e.declaracion_desconocida = true
SET e.componente_limitante = 'DATO_DIETARIO_FALTANTE';
// CA-D05 · prioridad auxiliar de revisión de calcio (etiqueta dominante; no asigna estado)
MATCH (e:EvaluacionNutriente {nutriente:'CA'})-[d:DEFUZZIFICA]->(vo:VariableDifusa {id:'V-CA-PRI'})-[:TIENE_TERMINO]->(t:TerminoDifuso)
WITH e, d.z AS z, t, exp(-1.0 * (d.z - t.centro)^2 / (2.0 * t.sigma^2)) AS m
ORDER BY m DESC
WITH e, z, collect(t.etiqueta)[0] AS dom
MATCH (rg:Regla {id:'CA-D05'})
SET e.prioridad_revision_ca = round(z * 100) / 100.0, e.etiqueta_prioridad = toUpper(dom), e.capa_difusa_estado = 'EJECUTADA', e.resultado_provisional = true
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'CA-D05', orden:90, efecto:'INFORMATIVO', grado: round(z * 100) / 100.0,
        texto:'Prioridad auxiliar de revisión de calcio ' + toString(round(z * 10) / 10.0) + ' (' + toUpper(dom) + ')'})
CREATE (t)-[:APLICA_REGLA]->(rg);

// VD-FZ-06 · Proyección invernal: mismo hábito con el índice UV de julio y ropa de invierno (cobertura ALTA)
MATCH (p:Paciente)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente {nutriente:'VD', capa_difusa_estado:'EJECUTADA'}),
      (p)-[:RESIDE_EN]->(:Localidad)-[:TIENE_IUV]->(u:IndiceUVMensual {mes:7}),
      (fp:FactorExposicion {codigo:'PIEL', valor_entrada:'ALTA'})
MATCH (m:ModeloDifuso {id:'MD-VD'}), (va:VariableDifusa {id:'V-VD-APO'}), (vx:VariableDifusa {id:'V-VD-EXP'})
WITH e, m, va, vx, e.factores_exposicion AS f, u, fp
CREATE (e)-[:PROYECTA]->(pi:ProyeccionInvernal {id: e.id + '-JUL', mes:7})
CREATE (pi)-[:USA_MODELO]->(m)
CREATE (pi)-[:ENTRADA {valor: e.ingesta_relativa}]->(va)
CREATE (pi)-[:ENTRADA {valor: 100 * f[0] * (CASE WHEN u.iuv / 10.0 > 1 THEN 1.0 ELSE u.iuv / 10.0 END) * fp.coeficiente * f[3] * f[4]}]->(vx);
// ----------------------------------------------- MOTOR DIFUSO GENÉRICO (pasada C: proyecciones invernales)
MATCH (suj:ProyeccionInvernal)-[:USA_MODELO]->(:ModeloDifuso)-[:DEFINE_VARIABLE]->(v:VariableDifusa)-[:TIENE_TERMINO]->(t:TerminoDifuso)
MATCH (suj)-[en:ENTRADA]->(v)
WITH suj, t, CASE WHEN en.valor < v.universo_min THEN toFloat(v.universo_min)
                  WHEN en.valor > v.universo_max THEN toFloat(v.universo_max) ELSE toFloat(en.valor) END AS x
MERGE (suj)-[pe:PERTENECE]->(t)
SET pe.x = x,
    pe.mu = CASE WHEN t.tipo_funcion = 'HOMBRO_IZQ' AND x <= t.centro THEN 1.0
                 WHEN t.tipo_funcion = 'HOMBRO_DER' AND x >= t.centro THEN 1.0
                 ELSE exp(-1.0 * (x - t.centro)^2 / (2.0 * t.sigma^2)) END;
MATCH (suj:ProyeccionInvernal)-[:USA_MODELO]->(:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[an:ANTECEDENTE]->(t:TerminoDifuso)<-[pe:PERTENECE]-(suj)
WITH suj, r, an.grupo AS g, max(CASE WHEN an.negado THEN 1.0 - pe.mu ELSE pe.mu END) AS g_or
WITH suj, r, min(g_or) AS alfa
MERGE (suj)-[ac:ACTIVA]->(r) SET ac.alfa = alfa;
MATCH (suj:ProyeccionInvernal)-[:USA_MODELO]->(m:ModeloDifuso)-[:CONTIENE_REGLA]->(r:ReglaDifusa)-[:CONSECUENTE]->(t:TerminoDifuso)<-[:TIENE_TERMINO]-(vo:VariableDifusa),
      (suj)-[ac:ACTIVA]->(r)
WITH suj, m, vo, t, max(ac.alfa) AS alfa
WITH suj, m, vo, collect({c: t.centro, s: t.sigma, f: t.tipo_funcion, a: alfa}) AS cons
UNWIND range(0, m.puntos - 1) AS i
WITH suj, vo, cons, vo.universo_min + i * (vo.universo_max - vo.universo_min) / toFloat(m.puntos - 1) AS z
WITH suj, vo, z, [k IN cons |
       CASE WHEN k.a < (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END)
            THEN k.a
            ELSE (CASE WHEN k.f = 'HOMBRO_IZQ' AND z <= k.c THEN 1.0 WHEN k.f = 'HOMBRO_DER' AND z >= k.c THEN 1.0 ELSE exp(-1.0 * (z - k.c)^2 / (2.0 * k.s^2)) END) END] AS cortes
WITH suj, vo, z, reduce(mx = 0.0, x IN cortes | CASE WHEN x > mx THEN x ELSE mx END) AS mu
WITH suj, vo, sum(z * mu) AS num, sum(mu) AS den
MERGE (suj)-[d:DEFUZZIFICA]->(vo) SET d.z = CASE WHEN den > 0 THEN num / den ELSE null END;
MATCH (e:EvaluacionNutriente)-[:PROYECTA]->(pi:ProyeccionInvernal)-[d:DEFUZZIFICA]->(:VariableDifusa {id:'V-RIESGO'}), (pi)-[:USA_MODELO]->(m:ModeloDifuso)
WITH e, pi, d.z AS z, CASE WHEN d.z < m.corte_bajo THEN 'BAJO' WHEN d.z > m.corte_alto THEN 'ALTO' ELSE 'MODERADO' END AS et
SET pi.riesgo = round(z * 100) / 100.0, pi.etiqueta = et, e.riesgo_invierno = round(z * 100) / 100.0
WITH e, pi, et
WHERE et = 'ALTO' AND e.etiqueta_riesgo IN ['BAJO', 'MODERADO']
MATCH (rg:Regla {id:'VD-FZ-06'}), (q:PreguntaExperta {id:'Q25'})
CREATE (e)-[:GENERA]->(adv:Advertencia {regla:'VD-FZ-06', tipo:'ESTACIONAL', destinatario:'NUTRICIONISTA',
        texto:'Con el mismo hábito, en invierno el riesgo de vitamina D sería ALTO (' + toString(pi.riesgo) + '): reevaluar entre junio y agosto. No se recomienda más sol ni retirar el protector'})
CREATE (adv)-[:SE_APOYA_EN]->(pi)
CREATE (adv)-[:SE_APOYA_EN]->(q)
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'VD-FZ-06', orden:91, efecto:'ADVERTENCIA', texto:'Proyección invernal ALTA'})
CREATE (t)-[:APLICA_REGLA]->(rg);

// ====================================================== GRUPO 7 · Control
// META-01 + G-08 + META-07 · resolución del estado por prioridad
MATCH (e:EvaluacionNutriente)
OPTIONAL MATCH (e)-[:REGISTRA]->(t:PasoTraza) WHERE t.estado_propuesto IS NOT NULL
WITH e, collect(t.estado_propuesto) AS props
OPTIONAL MATCH (e)-[:REGISTRA]->(tp:PasoTraza {efecto:'PENDIENTE'})
WITH e, props, count(tp) AS pend
WITH e, props, pend,
     CASE WHEN 'FUERA_DE_ALCANCE' IN props THEN 'FUERA_DE_ALCANCE'
          WHEN 'POSIBLE_INGESTA_INSUFICIENTE' IN props THEN 'POSIBLE_INGESTA_INSUFICIENTE'
          WHEN 'INFORMACION_INSUFICIENTE' IN props THEN 'INFORMACION_INSUFICIENTE'
          WHEN e.fuente_verificada = 'SI' AND pend = 0 THEN 'SIN_SEÑAL_DETECTADA'
          WHEN pend > 0 THEN null
          ELSE 'INFORMACION_INSUFICIENTE' END AS est
SET e.estado = est,
    e.regla_estado = CASE WHEN size(props) > 0 THEN 'META-01' WHEN est = 'SIN_SEÑAL_DETECTADA' THEN 'G-08' ELSE 'META-07' END,
    e.situacion_interna = CASE WHEN est IS NULL THEN 'PENDIENTE_VALIDACION' ELSE 'CONCLUIDA' END,
    e.alerta = CASE WHEN est IS NULL THEN 'NO_EVALUADA' WHEN est = 'POSIBLE_INGESTA_INSUFICIENTE' THEN 'SI' ELSE 'NO' END,
    e.sin_regla_aplicable = (size(props) = 0 AND pend = 0 AND NOT e.fuente_verificada = 'SI');
MATCH (e:EvaluacionNutriente {regla_estado:'G-08'}), (rg:Regla {id:'G-08'})
SET e.fundamento = 'FUENTE_VERIFICADA'
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-08', orden:95, efecto:'ESTADO', estado_final:'SIN_SEÑAL_DETECTADA',
        texto:'Fuente verificada (' + e.tipo_fuente_verificada + ') y ninguna regla de estado ni criterio pendiente: sin señal (no significa estado normal)'})
CREATE (t)-[:APLICA_REGLA]->(rg);
MATCH (e:EvaluacionNutriente {regla_estado:'META-07'}), (rg:Regla {id:'META-07'})
SET e.fundamento = CASE WHEN e.estado IS NULL THEN 'CRITERIO_PENDIENTE' ELSE 'SIN_REGLA_APLICABLE' END
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'META-07', orden:95, efecto:'ESTADO',
        texto: CASE WHEN e.estado IS NULL THEN 'Datos completos pero la conclusión depende de un criterio CANDIDATO: PENDIENTE_VALIDACION (no se culpa al paciente con «información insuficiente»)'
                    ELSE 'Ninguna regla cubre el caso: INFORMACION_INSUFICIENTE con revisión profesional (nunca SIN_SEÑAL por defecto)' END})
CREATE (t)-[:APLICA_REGLA]->(rg);
MATCH (e:EvaluacionNutriente) WHERE e.estado IS NOT NULL
MATCH (s:Estado {codigo: e.estado})
MERGE (e)-[:TIENE_ESTADO]->(s);
// G-13 · Aclaración diagnóstica para toda POSIBLE_INGESTA_INSUFICIENTE
MATCH (e:EvaluacionNutriente {estado:'POSIBLE_INGESTA_INSUFICIENTE'}), (rg:Regla {id:'G-13'})
CREATE (e)-[:GENERA]->(:Advertencia {regla:'G-13', tipo:'ACLARACION_DIAGNOSTICA', destinatario:'NUTRICIONISTA',
        texto:'No es un diagnóstico: el estado corporal del nutriente no es determinable por el sistema'})
CREATE (e)-[:REGISTRA]->(t:PasoTraza {regla:'G-13', orden:96, efecto:'ACLARACION', texto:'Aclaración diagnóstica agregada'})
CREATE (t)-[:APLICA_REGLA]->(rg);

// SM-INT · Resultado consolidado + META-04 (lista única de datos faltantes) + META-03 (traza)
MATCH (p:Paciente)
MERGE (p)-[:TIENE_RESULTADO]->(res:ResultadoConsolidado {id: p.id + '-RES'})
SET res.validado_por_nutricionista = false, res.aclaracion = 'Resultado de apoyo; no es diagnóstico ni prescripción'
WITH p, res
MATCH (p)-[:TIENE_EVALUACION]->(x)
MERGE (res)-[:INTEGRA]->(x);
MATCH (res:ResultadoConsolidado)-[:INTEGRA]->()-[:GENERA]->(df:DatoFaltante)
MERGE (res)-[:PIDE]->(df);
MATCH (res:ResultadoConsolidado)-[:PIDE]->(df:DatoFaltante)-[:SIRVE_A]->(n:Nutriente)
WITH res, df, collect(n.codigo) AS nutr
SET df.nutrientes = nutr, df.unificado = size(nutr) > 1;
MATCH (p:Paciente)-[:TIENE_RESULTADO]->(res:ResultadoConsolidado), (p)-[:TIENE_EVALUACION]->(ea:EvaluacionAdmisibilidad)
OPTIONAL MATCH (p)-[:TIENE_EVALUACION]->(e:EvaluacionNutriente)
WITH res, ea, e ORDER BY e.nutriente
WITH res, ea, collect(e.nutriente + ': ' + coalesce(e.estado, e.situacion_interna)) AS resumen
SET res.veredicto_admisibilidad = ea.veredicto, res.calidad_registro = coalesce(ea.calidad_registro, '—'), res.resumen = resumen;
MATCH (n:Usuario {id:'NUT-01'}), (res:ResultadoConsolidado)
MERGE (n)-[:DEBE_VALIDAR]->(res);
