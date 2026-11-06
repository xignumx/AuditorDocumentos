Documentacion - MotorConfig Service

Ubicacion:
- src/services/motorConfigService.js

Resumen:
Servicio con metodos POST para consumir endpoints de MotorConfig. Todos usan
Bearer token desde el header, tomado por el httpClient (token en la URL).

Modelos base:
- PaginatedRequest: { filter, page, size }
- MotorConfigRequestBase: { idCliente, idTipoDocumentoVucem, data? }
- ApiResponse (paginado): { success, message, data: { data, page, size, ... } }
- ApiResponseData: { success, message, data }
- ApiResponseBase: { success, message, data? }

Metodos:
- obtenerDocumentosVucem(payload, token)
  POST /api/MotorConfig/ObtenerDocumentosVucem
  Request: PaginatedRequest
  Response: ApiResponse<DocumentoVucem>

- obtenerClientes(payload, token)
  POST /api/MotorConfig/ObtenerClientes
  Request: PaginatedRequest
  Response: ApiResponse<Cliente>

- obtenerAduanas(payload, token)
  POST /api/MotorConfig/ObtenerAduanas
  Request: PaginatedRequest
  Response: ApiResponse<Aduana>

- obtenerProveedores(payload, token)
  POST /api/MotorConfig/ObtenerProveedores
  Request: MotorConfigRequestBase<PaginatedRequest>
  Response: ApiResponse<Proveedor>

- obtenerMotorConfig(payload, token)
  POST /api/MotorConfig/ObtenerMotorConfig
  Request: MotorConfigRequestBase
  Response: ApiResponseData<MotorConfigHeader>
  Nota: MotorConfigHeader incluye idClasificacion

- guardarMotorConfig(payload, token)
  POST /api/MotorConfig/GuardarMotorConfig
  Request: MotorConfigRequestBase<MotorConfigHeader>
  Response: ApiResponseData<MotorConfigHeader>
  Nota: MotorConfigHeader incluye idClasificacion

- validaFraccion(payload, token)
  POST /api/MotorConfig/ValidaFraccion
  Request: MotorConfigRequestBase<string>
  Response: ApiResponseBase

- validaUnidadMedida(payload, token)
  POST /api/MotorConfig/ValidaUnidadMedida
  Request: MotorConfigRequestBase<string>
  Response: ApiResponseData<string>

- validaPais(payload, token)
  POST /api/MotorConfig/ValidaPais
  Request: MotorConfigRequestBase<string>
  Response: ApiResponseData<string>

- validaExistenciaMotorConfig(payload, token)
  POST /api/MotorConfig/ValidaExistenciaMotorConfig
  Request: MotorConfigRequestBase
  Response: ApiResponseData<boolean>

- obtenerSugerenciaPedimentos(payload, token)
  POST /api/MotorConfig/ObtenerSugerenciaPedimentos
  Request:
    MotorConfigRequestBase<{
      data: { pedimento, clavePedimento, tipoOperacion, tipoPedimento, fraccion, pais },
      page, size
    }>
  Response: ApiResponse<SugerenciaPedimentoItem>

Documentacion - Documentos Service

Ubicacion:
- src/services/documentosService.js

Resumen:
Servicio con metodos POST para consumir endpoints de Documentos. Todos usan
Bearer token desde el header, tomado por el httpClient (token en la URL).

Modelos base:
- MotorConfigRequestBase: { idCliente, idTipoDocumentoVucem, data? }
- ApiResponseData: { success, message, data }

Metodos:
- extraDatosDocumentoIa(payload, token)
  POST /api/Documentos/ExtraDatosDocumentoIa
  Request: MotorConfigRequestBase<DocumentoRequest>
  Response: ApiResponseData<DocumentoExtraDatosItem[]>

- preguardaDocumento(payload, token)
  POST /api/Documentos/PreguardaDocumento
  Request: MotorConfigRequestBase<AdDocumentos>
  Response: ApiResponseData<number>

- guardaDocumentoPendienteAprobacion(payload, token)
  POST /api/Documentos/GuardaDocumentoPendienteAprobacion
  Request: MotorConfigRequestBase<AdDocumentos>
  Response: ApiResponseData<AdDocumentos>

- autorizaDocumento(payload, token)
  POST /api/Documentos/AutorizaDocumento
  Request: MotorConfigRequestBase<number>
  Response: ApiResponseData<AdDocumentos>

- rechazarDocumento(payload, token)
  POST /api/Documentos/RechazarDocumento
  Request: MotorConfigRequestBase<RechazarDocumentoRequest>
  Response: ApiResponseData<AdDocumentos>

- eliminarDocumento(payload, token)
  POST /api/Documentos/EliminarDocumento
  Request: MotorConfigRequestBase<number>
  Response: ApiResponseData<AdDocumentos>

- obtenerDocumentos(payload, token)
  POST /api/Documentos/ObtenerDocumentos
  Request: MotorConfigRequestBase<number>
  Response: ApiResponseData<CspAdDocumentosPorEstatus[]>
  Nota: Incluye fechaCreacion, creadoPor, estatus (string), estatusEnum,
  idClasificacion, clasificacion, comentarioRechazo.

- obtenerDocumentoPorId(payload, token)
  POST /api/Documentos/ObtenerDocumentoPorId
  Request: MotorConfigRequestBase<number>
  Response: ApiResponseData<AdDocumentos>

- validarDocumentoVigenteAprobado(payload, token)
  POST /api/Documentos/ValidarDocumentoVigenteAprobado
  Request: MotorConfigRequestBase
  Response: ApiResponseData<boolean>

- altaAsociacionOperacion(payload, token)
  POST /api/Documentos/AltaAsociacionOperacion
  Request: MotorConfigRequestBase<AsociacionOperacionRequest>
  Response: ApiResponseData<boolean>

Documentacion - NotificacionConfig Service

Ubicacion:
- src/services/notificacionesService.js

Resumen:
Servicio con metodos POST para consumir endpoints de NotificacionConfig. Todos usan
Bearer token desde el header, tomado por el httpClient (token en la URL).

Modelos base:
- MotorConfigRequestBase: { idCliente, idTipoDocumentoVucem, data? }
- ApiResponseData: { success, message, data }

Metodos:
- obtenerNotifConfig(payload, token)
  POST /api/NotificacionConfig/ObtenerNotifConfig
  Request: MotorConfigRequestBase<number>
  Response: ApiResponseData<AdNotifConfig>
  Nota: data lleva idMotorConfigHeader.

- guardarNotifConfig(payload, token)
  POST /api/NotificacionConfig/GuardarNotifConfig
  Request: MotorConfigRequestBase<AdNotifConfig>
  Response: ApiResponseData<AdNotifConfig>
  Nota: correos y diasAntesVencimiento se envian separados por coma.