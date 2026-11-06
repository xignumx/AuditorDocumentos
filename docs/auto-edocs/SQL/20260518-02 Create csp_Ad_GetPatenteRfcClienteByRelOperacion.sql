USE DesarrolloDB
GO


CREATE PROCEDURE csp_Ad_GetPatenteRfcClienteByRelOperacion
	@idReferencia VARCHAR(10),
	@idRectificacion DECIMAL(1, 0) = NULL
AS BEGIN
	DECLARE 
		@rfcCliente VARCHAR(20),
		@patente VARCHAR(4),
		@rfcPatente VARCHAR(20);

	IF @idRectificacion IS NULL 
	BEGIN
		SELECT
			@rfcCliente = fcli.rfc,
			@patente = fgt.id_patente,
			@rfcPatente = pat.rfc
		FROM ADUASIS.dbo.fgtrafico fgt WITH(NOLOCK)
		INNER JOIN ADUASIS.dbo.FCLIENTE fcli WITH(NOLOCK)
			ON fcli.ID_CLIENTE = fgt.id_cliente
		LEFT JOIN ADUASIS.dbo.fag_ad_mex pat WITH(NOLOCK)
			ON pat.id_patente = fgt.id_patente
		WHERE fgt.id_trafico = @idReferencia;
    END;
	ELSE 
	BEGIN
		SELECT
			@rfcCliente = fped.rfc_cliente,
			@patente = fped.id_patente,
			@rfcPatente = pat.rfc
		FROM ADUASIS.dbo.fpedimento fped WITH(NOLOCK)
		LEFT JOIN ADUASIS.dbo.fag_ad_mex pat WITH(NOLOCK)
			ON pat.id_patente = fped.id_patente
		WHERE fped.id_referencia = @idReferencia
			AND fped.id_rectificacion = @idRectificacion;
    END;

	SELECT @rfcCliente RfcCliente, @patente Patente, @rfcPatente RfcPatente
END