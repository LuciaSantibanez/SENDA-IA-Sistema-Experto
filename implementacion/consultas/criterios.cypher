MATCH (c:CriterioCandidato)
WHERE c.nombre IN ['PARAM_UMBRAL_CA','PARAM_FZ_CA','POLITICA_META_01']
RETURN c.nombre AS criterio,c.estado_validacion AS estado,c.valor AS valor,
 c.comportamiento_pendiente AS comportamiento
ORDER BY criterio
