USE ADUASIS;
GO
SET SHOWPLAN_XML ON;
GO
EXEC dbo.csp_Ad_SugerenciaPedimentos_v2
    @idCliente = '9174',
    @idAdDocumento = 35081,
    @operacionBusqueda = '',
    @PageNumber = 1,
    @PageSize = 10;
GO
SET SHOWPLAN_XML OFF;
GO
