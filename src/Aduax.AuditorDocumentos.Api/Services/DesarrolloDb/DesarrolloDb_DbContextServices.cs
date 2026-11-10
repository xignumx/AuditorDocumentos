using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using Aduax.AuditorDocumentos.Api.Data;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.DesarrolloDb
{
    public class DesarrolloDb_DbContextServices : IDesarrolloDb_DbContextServices
    {
        private readonly DesarrolloDB_DBContext _context;

        public DesarrolloDb_DbContextServices(DesarrolloDB_DBContext context)
        {
            _context = context;
        }

        public async Task<AdMotorConfigHeader> GetMotorConfigHeaderConDetalleAsync(string idCliente, int idTipoDocumentoVucem)
        {
            // Buscar configuración existente
            var configHeader = await _context.AdMotorConfigHeaders
                .Include(h => h.Detalles)
                .AsNoTracking() // No rastrear las entidades para evitar problemas de relaciones cortadas
                .AsSplitQuery() // Evita cargar navegaciones innecesarias
                .FirstOrDefaultAsync(h => h.IdCliente == idCliente && h.IdTipoDocumentoVucem == idTipoDocumentoVucem);

            // Si no existe, crear uno nuevo con todos los detalles (sin guardar)
            if (configHeader == null)
            {
                configHeader = new AdMotorConfigHeader
                {
                    IdCliente = idCliente,
                    IdTipoDocumentoVucem = idTipoDocumentoVucem,
                    IdClasificacion = (int)AdDocumentoClasificacion.IdentificadorGeneral,
                    AccionPedimento = "P",
                    PerfilCarga = AdPerfilCargaMotor.AccesoGeneral,
                    Activo = true,
                    FechaCreacion = DateTime.Now,
                    CreadoPor = "Sistema",
                    Detalles = new List<AdMotorConfigDetalle>()
                };

                // Crear detalle para cada campo del enum AdCampos
                foreach (AdCampos campo in Enum.GetValues(typeof(AdCampos)))
                {
                    configHeader.Detalles.Add(MotorConfigReglas.CrearDetalleDefault(campo));
                }
            }
            
            return configHeader;
        }

        public async Task<AdMotorConfigHeader> SaveMotorConfigHeaderConDetalleAsync(
            AdMotorConfigHeader motorConfigHeader,
            string origenBitacora = AdMotorConfigBitacoraOrigen.Manual)
        {
            motorConfigHeader.PerfilCarga = AdPerfilCargaMotor.Normalizar(motorConfigHeader.PerfilCarga);

            // Validar detalles antes de guardar
            MotorConfigReglas.ValidarDetalles(motorConfigHeader.Detalles);

            // Usar transacción para agrupar todas las operaciones y evitar problemas con triggers
            using var transaction = await _context.Database.BeginTransactionAsync();
            try
            {
                if (motorConfigHeader.Id == 0)
                {
                    // Nuevo registro
                    motorConfigHeader.FechaCreacion = DateTime.Now;
                    if (string.IsNullOrWhiteSpace(motorConfigHeader.CreadoPor))
                    {
                        motorConfigHeader.CreadoPor = "Sistema";
                    }

                    // Guardar el header primero para obtener el Id
                    // Con UseSqlOutputClause(false) configurado en el DbContext, EF Core usará SCOPE_IDENTITY() en lugar de OUTPUT
                    _context.AdMotorConfigHeaders.Add(motorConfigHeader);
                    await _context.SaveChangesAsync();

                    // Bitácora de auditoría: alta del motor (todos los parámetros sin valor anterior)
                    await RegistrarBitacoraMotorConfigAsync(
                        motorConfigHeader,
                        new Dictionary<string, string>(),
                        motorConfigHeader.CreadoPor,
                        origenBitacora);
                }
                else
                {
                    // Actualización
                    var existingHeader = await _context.AdMotorConfigHeaders
                        .Include(h => h.Detalles)
                        .FirstOrDefaultAsync(h => h.Id == motorConfigHeader.Id);

                    if (existingHeader == null)
                    {
                        throw new InvalidOperationException($"No se encontró el registro con Id {motorConfigHeader.Id}");
                    }

                    // Estado previo para la bitácora de auditoría (antes de mutar la entidad rastreada)
                    var parametrosAnteriores = MotorConfigReglas.ConstruirParametros(existingHeader);

                    // Actualizar propiedades del header
                    existingHeader.IdCliente = motorConfigHeader.IdCliente;
                    existingHeader.IdTipoDocumentoVucem = motorConfigHeader.IdTipoDocumentoVucem;
                    existingHeader.IdClasificacion = motorConfigHeader.IdClasificacion;
                    existingHeader.AccionPedimento = motorConfigHeader.AccionPedimento;
                    existingHeader.PerfilCarga = motorConfigHeader.PerfilCarga;
                    existingHeader.Activo = motorConfigHeader.Activo;
                    existingHeader.FechaActualizacion = DateTime.Now;
                    existingHeader.ActualizadoPor = motorConfigHeader.ActualizadoPor ?? "Sistema";
                    existingHeader.MotivoCambio = motorConfigHeader.MotivoCambio;

                    // Validación de detalle existente
                    if (existingHeader.Detalles != null && existingHeader.Detalles.Any())
                    {
                        // Manejo de detalle duplicado
                        foreach (var d in motorConfigHeader.Detalles)
                        {
                            var up = existingHeader.Detalles.FirstOrDefault(x => x.IdCampo == d.IdCampo);
                            if (up == null)
                            {
                                up = new AdMotorConfigDetalle
                                {
                                    IdMotorConfigHeader = existingHeader.Id,
                                    IdCampo = d.IdCampo
                                };
                            }
                            up.NombreCampo = d.NombreCampo;
                            up.Visible = d.Visible;
                            up.Obligatorio = d.Obligatorio;

                            if (up.Id == 0)
                                _context.Add(up);
                        }

                        if (existingHeader.Detalles.Count > motorConfigHeader.Detalles.Count)
                        {
                            // Eliminar detalles que ya no existen
                            var detallesAEliminar = existingHeader.Detalles
                                .Where(ed => !motorConfigHeader.Detalles.Any(md => md.IdCampo == ed.IdCampo))
                                .ToList();
                            _context.AdMotorConfigDetalles.RemoveRange(detallesAEliminar);
                        }
                    }

                    await _context.SaveChangesAsync();

                    await RegistrarBitacoraMotorConfigAsync(
                        existingHeader,
                        parametrosAnteriores,
                        existingHeader.ActualizadoPor ?? "Sistema",
                        origenBitacora);

                    // Recargar para obtener los detalles actualizados
                    await _context.Entry(existingHeader).ReloadAsync();
                    await _context.Entry(existingHeader).Collection(h => h.Detalles!).LoadAsync();

                    motorConfigHeader = existingHeader;
                }

                // Confirmar la transacción
                await transaction.CommitAsync();
            }
            catch
            {
                // Revertir la transacción en caso de error
                await transaction.RollbackAsync();
                throw;
            }

            return motorConfigHeader;
        }

        /// <summary>
        /// Registra una fila por parámetro cuyo valor cambió. Forma parte de la transacción del guardado.
        /// </summary>
        private async Task RegistrarBitacoraMotorConfigAsync(
            AdMotorConfigHeader headerActual,
            Dictionary<string, string> parametrosAnteriores,
            string usuario,
            string origen)
        {
            var parametrosNuevos = MotorConfigReglas.ConstruirParametros(headerActual);
            var ahora = DateTime.Now;
            var usuarioBitacora = string.IsNullOrWhiteSpace(usuario) ? "Sistema" : usuario;
            var filas = new List<AdMotorConfigBitacora>();

            foreach (var parametro in parametrosAnteriores.Keys.Union(parametrosNuevos.Keys))
            {
                parametrosAnteriores.TryGetValue(parametro, out var anterior);
                parametrosNuevos.TryGetValue(parametro, out var nuevo);

                if (string.Equals(anterior, nuevo, StringComparison.Ordinal))
                {
                    continue;
                }

                filas.Add(new AdMotorConfigBitacora
                {
                    IdMotorConfigHeader = headerActual.Id,
                    IdCliente = headerActual.IdCliente,
                    IdTipoDocumentoVucem = headerActual.IdTipoDocumentoVucem,
                    Parametro = parametro,
                    ValorAnterior = anterior,
                    ValorNuevo = nuevo,
                    Origen = origen,
                    MotivoCambio = headerActual.MotivoCambio,
                    UsuarioCambio = usuarioBitacora,
                    FechaCambio = ahora
                });
            }

            if (filas.Count == 0)
            {
                return;
            }

            _context.AdMotorConfigBitacora.AddRange(filas);
            await _context.SaveChangesAsync();
        }

        public void LimpiarSeguimientoCambios()
        {
            _context.ChangeTracker.Clear();
        }

        public async Task<bool> ExistsMotorConfigHeaderAsync(string idCliente, int idTipoDocumentoVucem)
        {
            return await _context.AdMotorConfigHeaders
                .AnyAsync(h => h.IdCliente == idCliente && h.IdTipoDocumentoVucem == idTipoDocumentoVucem);
        }

        public async Task<string?> GetPerfilCargaPersistidoAsync(string idCliente, int idTipoDocumentoVucem)
        {
            return await _context.AdMotorConfigHeaders
                .AsNoTracking()
                .Where(h => h.IdCliente == idCliente && h.IdTipoDocumentoVucem == idTipoDocumentoVucem)
                .Select(h => h.PerfilCarga)
                .FirstOrDefaultAsync();
        }

        public async Task<Dictionary<int, string>> GetPerfilesCargaPorClienteAsync(
            string idCliente,
            IReadOnlyCollection<int> idTiposDocumentoVucem)
        {
            if (idTiposDocumentoVucem == null || idTiposDocumentoVucem.Count == 0)
            {
                return new Dictionary<int, string>();
            }

            return await _context.AdMotorConfigHeaders
                .AsNoTracking()
                .Where(h => h.IdCliente == idCliente && idTiposDocumentoVucem.Contains(h.IdTipoDocumentoVucem))
                .Select(h => new { h.IdTipoDocumentoVucem, h.PerfilCarga })
                .ToDictionaryAsync(x => x.IdTipoDocumentoVucem, x => x.PerfilCarga);
        }

        public async Task<(AdIaPromptDocumento? PromptDocumento, List<AdIaPromptCampo> PromptCampos)> GetIaPromptDocumentoConCamposAsync(long idTipoDocumentoVucem)
        {
            // Recuperar el prompt del documento
            var promptDocumento = await _context.AdIaPromptDocumento
                .FirstOrDefaultAsync(p => p.IdTipoDocumentoVucem == idTipoDocumentoVucem);

            // Recuperar los prompts de campos relacionados (solo activos)
            var promptCampos = await _context.AdIaPromptCampo
                .Where(p => p.IdTipoDocumentoVucem == idTipoDocumentoVucem && p.Activo)
                .OrderBy(p => p.IdCampo)
                .ToListAsync();

            return (promptDocumento, promptCampos);
        }

        public async Task<AdConfiguracionIa?> GetConfiguracionIaAsync(string ia)
        {
            return await _context.AdConfiguracionIa
                .FirstOrDefaultAsync(c => c.Ia == ia && c.Activo);
        }

        public async Task<AdBitacoraEventos> SaveBitacoraEventoAsync(long idDocumento, AdEventos tipoEvento, string descripcionEvento, string? datosAdicionales, string usuarioEvento)
        {
            var bitacoraEvento = new AdBitacoraEventos
            {
                IdDocumento = idDocumento,
                IdTipoEvento = (int)tipoEvento,
                DescripcionEvento = descripcionEvento,
                DatosAdicionales = datosAdicionales,
                FechaEvento = DateTime.Now,
                UsuarioEvento = usuarioEvento
            };

            _context.AdBitacoraEventos.Add(bitacoraEvento);
            await _context.SaveChangesAsync();

            return bitacoraEvento;
        }

        public async Task<AdIaEjecucion> SaveIaEjecucionAsync(long idDocumento, string? proveedorIA, string modeloIA, string promptEntrada, string? jsonResultado)
        {
            var iaEjecucion = new AdIaEjecucion
            {
                IdDocumento = idDocumento,
                ProveedorIA = proveedorIA,
                ModeloIA = modeloIA,
                PromptEntrada = promptEntrada,
                JsonResultado = jsonResultado
            };

            _context.AdIaEjecucion.Add(iaEjecucion);
            await _context.SaveChangesAsync();

            return iaEjecucion;
        }

        public async Task<AdDocumentos> SaveDocumentoAsync(AdDocumentos documento, bool validarClasificacion = true)
        {
            // Obtener el MotorConfigHeader para validar la clasificación
            var motorConfigHeader = await _context.AdMotorConfigHeaders
                .AsNoTracking()
                .FirstOrDefaultAsync(m => m.Id == documento.IdMotorConfigHeader);

            if (motorConfigHeader == null)
            {
                throw new InvalidOperationException($"No se encontró la configuración del motor con Id {documento.IdMotorConfigHeader}");
            }

            // Validar que solo venga la entidad correspondiente a la clasificación SOLO si validarClasificacion es true
            if (validarClasificacion)
            {
                ValidateDocumentoClasificacion(documento, motorConfigHeader.IdClasificacion);
            }

            // Guardar ID del documento para recuperarlo después
            long documentoId;

            // Guardar el documento principal
            if (documento.Id == 0)
            {
                // Nuevo registro
                documento.FechaCreacion = DateTime.Now;
                _context.AdDocumentos.Add(documento);
                await _context.SaveChangesAsync();
                documentoId = documento.Id;
            }
            else
            {
                documentoId = documento.Id;
                
                // Actualización - Verificar si ya está siendo rastreado
                var trackedEntity = _context.ChangeTracker.Entries<AdDocumentos>()
                    .FirstOrDefault(e => e.Entity.Id == documento.Id);

                if (trackedEntity != null)
                {
                    // Ya está siendo rastreado, actualizar propiedades
                    var entry = trackedEntity;
                    entry.CurrentValues.SetValues(documento);
                    
                    // Solo asignar FechaActualizacion si no está ya establecida
                    if (!documento.FechaActualizacion.HasValue)
                    {
                        entry.Entity.FechaActualizacion = DateTime.Now;
                    }
                }
                else
                {
                    // No está siendo rastreado, adjuntar y marcar como modificado
                    _context.AdDocumentos.Attach(documento);
                    _context.Entry(documento).State = EntityState.Modified;
                    
                    // Solo asignar FechaActualizacion si no está ya establecida
                    if (!documento.FechaActualizacion.HasValue)
                    {
                        documento.FechaActualizacion = DateTime.Now;
                    }
                }

                await _context.SaveChangesAsync();
            }

            // Guardar el archivo si existe (relación 1 a 1)
            if (documento.Archivo != null)
            {
                documento.Archivo.IdDocumento = documentoId;
                
                // Verificar si ya existe un archivo para este documento
                var archivoExistente = await _context.AdDocumentosArchivos
                    .FirstOrDefaultAsync(a => a.IdDocumento == documentoId);

                if (archivoExistente != null)
                {
                    // Actualizar archivo existente
                    archivoExistente.NombreArchivo = documento.Archivo.NombreArchivo;
                    archivoExistente.NombreEdocs = documento.Archivo.NombreEdocs;
                    archivoExistente.Extension = documento.Archivo.Extension;
                    archivoExistente.TamanoBytes = documento.Archivo.TamanoBytes;
                    archivoExistente.AwsRuta = documento.Archivo.AwsRuta;
                    _context.AdDocumentosArchivos.Update(archivoExistente);
                }
                else
                {
                    // Nuevo archivo
                    _context.AdDocumentosArchivos.Add(documento.Archivo);
                }

                await _context.SaveChangesAsync();
            }

            // Guardar los campos si existen (relación 1 a muchos)
            if (documento.Campos != null && documento.Campos.Any())
            {
                // Asignar el IdDocumento a cada campo
                foreach (var campo in documento.Campos)
                {
                    campo.IdDocumento = documentoId;
                }

                // Verificar campos existentes para este documento
                var camposExistentes = await _context.AdDocumentosCampos
                    .Where(c => c.IdDocumento == documentoId)
                    .ToListAsync();

                if (camposExistentes.Any())
                {
                    // Eliminar campos existentes que no están en la nueva lista
                    var camposAEliminar = camposExistentes
                        .Where(ce => !documento.Campos.Any(c => c.IdCampo == ce.IdCampo))
                        .ToList();

                    if (camposAEliminar.Any())
                    {
                        _context.AdDocumentosCampos.RemoveRange(camposAEliminar);
                    }

                    // Actualizar o agregar campos
                    foreach (var campo in documento.Campos)
                    {
                        var campoExistente = camposExistentes.FirstOrDefault(c => c.IdCampo == campo.IdCampo);
                        
                        if (campoExistente != null)
                        {
                            // Actualizar campo existente
                            campoExistente.Valor = campo.Valor;
                            _context.AdDocumentosCampos.Update(campoExistente);
                        }
                        else
                        {
                            // Nuevo campo
                            _context.AdDocumentosCampos.Add(campo);
                        }
                    }
                }
                else
                {
                    // No hay campos existentes, agregar todos
                    _context.AdDocumentosCampos.AddRange(documento.Campos);
                }

                await _context.SaveChangesAsync();
            }

            // Limpiar registros existentes de otras clasificaciones antes de guardar SOLO si validarClasificacion es true
            if (validarClasificacion)
            {
                await LimpiarClasificacionesAnterioresAsync(documentoId, motorConfigHeader.IdClasificacion);
            }

            // Guardar la entidad según la clasificación SOLO si validarClasificacion es true
            if (validarClasificacion)
            {
                switch ((AdDocumentoClasificacion)motorConfigHeader.IdClasificacion)
                {
                    case AdDocumentoClasificacion.IdentificadorGeneral:
                        await SaveIdentificadorGeneralAsync(documento);
                        break;

                    case AdDocumentoClasificacion.IdentificadorPartida:
                        await SaveIdentificadorPartidaAsync(documento);
                        break;

                    case AdDocumentoClasificacion.Permisos:
                        await SavePermisoAsync(documento);
                        break;

                    default:
                        throw new InvalidOperationException($"Clasificación de documento no válida: {motorConfigHeader.IdClasificacion}");
                }
            }

            // Desconectar todas las entidades rastreadas para evitar conflictos
            _context.ChangeTracker.Clear();

            // Recargar el documento completo desde la base de datos con todas sus relaciones
            var documentoRecargado = await _context.AdDocumentos
                .Include(d => d.Archivo)
                .Include(d => d.Campos)
                .AsSplitQuery()
                .FirstOrDefaultAsync(d => d.Id == documentoId);

            if (documentoRecargado == null)
            {
                throw new InvalidOperationException($"No se pudo recargar el documento con Id {documentoId}");
            }

            // Cargar relaciones de clasificación SOLO si validarClasificacion es true
            if (validarClasificacion)
            {
                await _context.Entry(documentoRecargado).Reference(d => d.IdentificadorGeneral).LoadAsync();
                await _context.Entry(documentoRecargado).Reference(d => d.IdentificadorPartida).LoadAsync();
                await _context.Entry(documentoRecargado).Reference(d => d.Permiso).LoadAsync();
            }

            return documentoRecargado;
        }

        private void ValidateDocumentoClasificacion(AdDocumentos documento, int idClasificacion)
        {
            var clasificacion = (AdDocumentoClasificacion)idClasificacion;
            int entidadesEnviadas = 0;
            string entidadesIncorrectas = string.Empty;

            if (documento.IdentificadorGeneral != null)
            {
                entidadesEnviadas++;
                if (clasificacion != AdDocumentoClasificacion.IdentificadorGeneral)
                {
                    entidadesIncorrectas += "IdentificadorGeneral, ";
                }
            }

            if (documento.IdentificadorPartida != null)
            {
                entidadesEnviadas++;
                if (clasificacion != AdDocumentoClasificacion.IdentificadorPartida)
                {
                    entidadesIncorrectas += "IdentificadorPartida, ";
                }
            }

            if (documento.Permiso != null)
            {
                entidadesEnviadas++;
                if (clasificacion != AdDocumentoClasificacion.Permisos)
                {
                    entidadesIncorrectas += "Permiso, ";
                }
            }

            if (entidadesEnviadas == 0)
            {
                throw new InvalidOperationException($"Debe proporcionar la entidad correspondiente a la clasificación {clasificacion}");
            }

            if (entidadesEnviadas > 1)
            {
                throw new InvalidOperationException($"Solo se permite una entidad de clasificación a la vez. Se enviaron {entidadesEnviadas} entidades");
            }

            if (!string.IsNullOrEmpty(entidadesIncorrectas))
            {
                entidadesIncorrectas = entidadesIncorrectas.TrimEnd(',', ' ');
                throw new InvalidOperationException($"La clasificación del documento es {clasificacion}, pero se envió: {entidadesIncorrectas}");
            }
        }

        private async Task LimpiarClasificacionesAnterioresAsync(long idDocumento, int idClasificacionActual)
        {
            // Solo limpiar si es una actualización (Id > 0)
            if (idDocumento == 0) return;

            var clasificacion = (AdDocumentoClasificacion)idClasificacionActual;

            // Eliminar IdentificadorGeneral si la clasificación NO es IdentificadorGeneral
            if (clasificacion != AdDocumentoClasificacion.IdentificadorGeneral)
            {
                var existente = await _context.AdDocumentosIdentificadorGeneral
                    .FirstOrDefaultAsync(i => i.IdDocumento == idDocumento);
                if (existente != null)
                {
                    _context.AdDocumentosIdentificadorGeneral.Remove(existente);
                }
            }

            // Eliminar IdentificadorPartida si la clasificación NO es IdentificadorPartida
            if (clasificacion != AdDocumentoClasificacion.IdentificadorPartida)
            {
                var existente = await _context.AdDocumentosIdentificadorPartida
                    .FirstOrDefaultAsync(i => i.IdDocumento == idDocumento);
                if (existente != null)
                {
                    _context.AdDocumentosIdentificadorPartida.Remove(existente);
                }
            }

            // Eliminar Permiso si la clasificación NO es Permisos
            if (clasificacion != AdDocumentoClasificacion.Permisos)
            {
                var existente = await _context.AdDocumentosPermiso
                    .FirstOrDefaultAsync(p => p.IdDocumento == idDocumento);
                if (existente != null)
                {
                    _context.AdDocumentosPermiso.Remove(existente);
                }
            }

            await _context.SaveChangesAsync();
        }

        private async Task SaveIdentificadorGeneralAsync(AdDocumentos documento)
        {
            if (documento.IdentificadorGeneral == null) return;

            documento.IdentificadorGeneral.IdDocumento = documento.Id;

            var existente = await _context.AdDocumentosIdentificadorGeneral
                .FirstOrDefaultAsync(i => i.IdDocumento == documento.Id);

            if (existente != null)
            {
                existente.Identificador = documento.IdentificadorGeneral.Identificador;
                existente.Complemento = documento.IdentificadorGeneral.Complemento;
                existente.Complemento2 = documento.IdentificadorGeneral.Complemento2;
                existente.Complemento3 = documento.IdentificadorGeneral.Complemento3;
                _context.AdDocumentosIdentificadorGeneral.Update(existente);
            }
            else
            {
                _context.AdDocumentosIdentificadorGeneral.Add(documento.IdentificadorGeneral);
            }

            await _context.SaveChangesAsync();
        }

        private async Task SaveIdentificadorPartidaAsync(AdDocumentos documento)
        {
            if (documento.IdentificadorPartida == null) return;

            documento.IdentificadorPartida.IdDocumento = documento.Id;

            var existente = await _context.AdDocumentosIdentificadorPartida
                .FirstOrDefaultAsync(i => i.IdDocumento == documento.Id);

            if (existente != null)
            {
                existente.Regimen = documento.IdentificadorPartida.Regimen;
                existente.TipoAdvalorem = documento.IdentificadorPartida.TipoAdvalorem;
                existente.Origen = documento.IdentificadorPartida.Origen;
                existente.Identificador = documento.IdentificadorPartida.Identificador;
                existente.Complemento1 = documento.IdentificadorPartida.Complemento1;
                existente.Complemento2 = documento.IdentificadorPartida.Complemento2;
                existente.Complemento3 = documento.IdentificadorPartida.Complemento3;
                _context.AdDocumentosIdentificadorPartida.Update(existente);
            }
            else
            {
                _context.AdDocumentosIdentificadorPartida.Add(documento.IdentificadorPartida);
            }

            await _context.SaveChangesAsync();
        }

        private async Task SavePermisoAsync(AdDocumentos documento)
        {
            if (documento.Permiso == null) return;

            documento.Permiso.IdDocumento = documento.Id;

            var existente = await _context.AdDocumentosPermiso
                .FirstOrDefaultAsync(p => p.IdDocumento == documento.Id);

            if (existente != null)
            {
                existente.Regimen = documento.Permiso.Regimen;
                existente.Permiso = documento.Permiso.Permiso;
                existente.Numero = documento.Permiso.Numero;
                existente.Firma = documento.Permiso.Firma;
                _context.AdDocumentosPermiso.Update(existente);
            }
            else
            {
                _context.AdDocumentosPermiso.Add(documento.Permiso);
            }

            await _context.SaveChangesAsync();
        }

        public async Task<AdDocumentos?> GetDocumentoByIdAsync(long id)
        {
            return await _context.AdDocumentos
                .Include(d => d.Archivo)
                .Include(d => d.Campos)
                .Include(d => d.IdentificadorGeneral)
                .Include(d => d.IdentificadorPartida)
                .Include(d => d.Permiso)
                .Include(d => d.Operaciones)
                .AsSplitQuery()
                .FirstOrDefaultAsync(d => d.Id == id);
        }

        public async Task<AdDocumentosArchivos> GetDocumentoByIdArchivosAsync(long id)
        {
            return await _context.AdDocumentosArchivos
                .FirstAsync(a => a.IdDocumento == id);
        }

        public async Task<AdAprobaciones> SaveAprobacionAsync(long idDocumento, int idResultado, string? motivo, string aprobadoPor)
        {
            // Verificar si ya existe una aprobación para este documento
            var aprobacionExistente = await _context.AdAprobaciones
                .FirstOrDefaultAsync(a => a.IdDocumento == idDocumento);

            if (aprobacionExistente != null)
            {
                // Actualizar aprobación existente
                aprobacionExistente.IdResultado = idResultado;
                aprobacionExistente.Motivo = motivo;
                aprobacionExistente.FechaAprobacion = DateTime.Now;
                aprobacionExistente.AprobadoPor = aprobadoPor;
                _context.AdAprobaciones.Update(aprobacionExistente);
            }
            else
            {
                // Crear nueva aprobación
                var aprobacion = new AdAprobaciones
                {
                    IdDocumento = idDocumento,
                    IdResultado = idResultado,
                    Motivo = motivo,
                    FechaAprobacion = DateTime.Now,
                    AprobadoPor = aprobadoPor
                };
                _context.AdAprobaciones.Add(aprobacion);
                aprobacionExistente = aprobacion;
            }

            await _context.SaveChangesAsync();
            return aprobacionExistente;
        }

        public async Task<List<CspAdDocumentosPorEstatus>> GetDocumentosPorEstatusAsync(string idCliente, int idEstatus)
        {
            var idClienteParam = new SqlParameter("@idCliente", idCliente);
            var idEstatusParam = new SqlParameter("@idEstatus", idEstatus);

            return await _context.CspAdDocumentosPorEstatus
                .FromSqlRaw("EXEC csp_Ad_DocumentosPorEstatus @idCliente, @idEstatus", idClienteParam, idEstatusParam)
                .ToListAsync();
        }

        public async Task<AdNotifConfig?> GetNotifConfigByMotorConfigHeaderIdAsync(long idMotorConfigHeader)
        {
            return await _context.AdNotifConfig
                .AsNoTracking()
                .FirstOrDefaultAsync(n => n.IdMotorConfigHeader == idMotorConfigHeader);
        }

        public async Task<AdNotifConfig> SaveNotifConfigAsync(AdNotifConfig notifConfig)
        {
            // Verificar si ya existe un registro con el mismo IdMotorConfigHeader
            var notifConfigExistente = await _context.AdNotifConfig
                .FirstOrDefaultAsync(n => n.IdMotorConfigHeader == notifConfig.IdMotorConfigHeader);

            if (notifConfigExistente != null)
            {
                // Actualizar registro existente
                notifConfigExistente.Correos = notifConfig.Correos;
                notifConfigExistente.DiasAntesVencimiento = notifConfig.DiasAntesVencimiento;
                notifConfigExistente.RecordarCorreos = notifConfig.RecordarCorreos;
                notifConfigExistente.FechaActualizacion = DateTime.Now;
                notifConfigExistente.ActualizadoPor = notifConfig.ActualizadoPor ?? "Sistema";

                _context.AdNotifConfig.Update(notifConfigExistente);
                await _context.SaveChangesAsync();

                return notifConfigExistente;
            }
            else
            {
                // Nuevo registro
                notifConfig.FechaCreacion = DateTime.Now;
                if (string.IsNullOrWhiteSpace(notifConfig.CreadoPor))
                {
                    notifConfig.CreadoPor = "Sistema";
                }

                _context.AdNotifConfig.Add(notifConfig);
                await _context.SaveChangesAsync();

                return notifConfig;
            }
        }

        public async Task<bool> ExistsMotorConfigHeaderByIdAsync(long id)
        {
            return await _context.AdMotorConfigHeaders
                .AnyAsync(h => h.Id == id);
        }

        public async Task<AdNotifEnvios> SaveNotifEnvioAsync(long idDocumento, string correosDestino, int diasAntesVencimiento, AdNotifResultado resultado, string? mensajeError, string creadoPor)
        {
            var notifEnvio = new AdNotifEnvios
            {
                IdDocumento = idDocumento,
                FechaEnvio = DateTime.Now,
                CorreosDestino = correosDestino,
                DiasAntesVencimiento = diasAntesVencimiento,
                IdResultado = (int)resultado,
                MensajeError = mensajeError,
                CreadoPor = creadoPor
            };

            _context.AdNotifEnvios.Add(notifEnvio);
            await _context.SaveChangesAsync();

            return notifEnvio;
        }

        public async Task<AdNotifTemplate?> GetNotifTemplateActivaAsync()
        {
            return await _context.AdNotifTemplate
                .AsNoTracking()
                .FirstOrDefaultAsync(t => t.Activo);
        }

        public async Task<List<CspAdDocumentosPorVencer>> GetDocumentosPorVencerAsync(string idCliente, int idMotorConfigHeader, int diasVencimiento)
        {
            var idClienteParam = new SqlParameter("@idCliente", idCliente);
            var idMotorConfigHeaderParam = new SqlParameter("@idMotorConfigHeader", idMotorConfigHeader);
            var diasVencimientoParam = new SqlParameter("@diasVencimiento", diasVencimiento);

            return await _context.CspAdDocumentosPorVencer
                .FromSqlRaw("EXEC csp_Ad_ObtieneDocumentosPorVencer @idCliente, @idMotorConfigHeader, @diasVencimiento", 
                    idClienteParam, idMotorConfigHeaderParam, diasVencimientoParam)
                .ToListAsync();
        }

        public async Task<List<AdNotifConfig>> GetAllNotifConfigAsync()
        {
            return await _context.AdNotifConfig
                .Include(n => n.MotorConfigHeader)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<List<CspAdProveedoresListarPaginado>> GetProveedoresPaginadoAsync(string idCliente, string? filtro, int pageNumber, int pageSize)
        {
            var idClienteParam = new SqlParameter("@IdCliente", idCliente);
            var filtroParam = new SqlParameter("@Filtro", filtro ?? (object)DBNull.Value);
            var pageNumberParam = new SqlParameter("@PageNumber", pageNumber);
            var pageSizeParam = new SqlParameter("@PageSize", pageSize);

            return await _context.CspAdProveedoresListarPaginado
                .FromSqlRaw("EXEC ad_proveedores_listar_paginado @IdCliente, @Filtro, @PageNumber, @PageSize",
                    idClienteParam, filtroParam, pageNumberParam, pageSizeParam)
                .ToListAsync();
        }

        public async Task<List<CspAdGetTraficoPorReferencia>> GetTraficoPorReferenciaRectificacionAsync(string idReferencia, decimal idRectificacion)
        {
            var idReferenciaParam = new SqlParameter("@idReferencia", idReferencia);
            var idRectificacionParam = new SqlParameter("@idRectificacion", idRectificacion);

            return await _context.CspAdGetTraficoPorReferencia
                .FromSqlRaw("EXEC csp_AD_GetTraficoPorReferencia @idReferencia, @idRectificacion",
                    idReferenciaParam, idRectificacionParam)
                .AsNoTracking()
                .ToListAsync();
        }

        public async Task<bool> ExisteDocumentoVigenteAprobadoAsync(string idCliente, int idTipoDocumentoVucem)
        {
            var fechaActual = DateTime.Now;

            return await _context.AdDocumentos
                .AnyAsync(d => 
                    d.IdCliente == idCliente && 
                    d.IdTipoDocumentoVucem == idTipoDocumentoVucem && 
                    (d.IdEstatus == (int)AdDocumentoEstatus.Aprobado || d.IdEstatus == (int)AdDocumentoEstatus.VinculadoOperacion || d.IdEstatus == (int)AdDocumentoEstatus.DigitalizadoEdocs) &&
                    d.FechaVigenciaFin.HasValue &&
                    d.FechaVigenciaFin.Value > fechaActual);
        }

        public async Task<bool> ExisteDocumentoNoPendientePorMotorConfigAsync(long idMotorConfigHeader)
        {
            if (idMotorConfigHeader <= 0)
            {
                return false;
            }

            return await _context.AdDocumentos
                .AnyAsync(d => d.IdMotorConfigHeader == idMotorConfigHeader 
                && (d.IdEstatus == (int)AdDocumentoEstatus.Pendiente ||
                d.IdEstatus == (int)AdDocumentoEstatus.Aprobado ||
                d.IdEstatus == (int)AdDocumentoEstatus.VinculadoOperacion ||
                d.IdEstatus == (int)AdDocumentoEstatus.DigitalizadoEdocs));
        }

        public async Task<List<string>> GetCorreosRecordatorioAsync(string idCliente)
        {
            if (string.IsNullOrWhiteSpace(idCliente))
            {
                return new List<string>();
            }

            var idClienteParam = new SqlParameter("@idCliente", idCliente);

            var correos = await _context.Database
                .SqlQueryRaw<string>("EXEC csp_ad_RecuperaCorreosConfigurados @idCliente", idClienteParam)
                .ToListAsync();

            return correos;
        }

        public async Task<List<AdDocumentoOperacion>> GetDocumentoOperacionesConEdocumentAsync(long idDocumento)
        {
            var idDocumentoParam = new SqlParameter("@idDocumento", idDocumento);

            var spRows = await _context.CspAdGetDocumentoOperacion
                .FromSqlRaw("EXEC csp_Ad_GetDocumentoOperacion @idDocumento", idDocumentoParam)
                .AsNoTracking()
                .ToListAsync();

            var dbOps = await _context.AdDocumentoOperacion
                .AsNoTracking()
                .Where(o => o.IdDocumento == idDocumento)
                .ToListAsync();

            if (spRows.Count == 0)
            {
                return dbOps;
            }

            var spPorOperacion = spRows
                .GroupBy(r => (r.id_referencia, r.id_rectificacion))
                .ToDictionary(
                    g => g.Key,
                    g => g.OrderByDescending(r => !string.IsNullOrWhiteSpace(r.Edocument))
                        .ThenByDescending(r => !string.IsNullOrWhiteSpace(r.Numero))
                        .ThenByDescending(r => !string.IsNullOrWhiteSpace(r.Mensaje))
                        .First());

            foreach (var db in dbOps)
            {
                var key = (db.id_referencia, db.id_rectificacion);
                if (spPorOperacion.TryGetValue(key, out var row))
                {
                    db.Edocument = row.Edocument;
                    db.Numero = row.Numero;
                    db.Mensaje = row.Mensaje;
                    db.EstaPagado = row.EstaPagado;
                }
            }

            return dbOps;
        }

        public async Task<AdDocumentoOperacion> SaveDocumentoOperacionAsync(AdDocumentoOperacion operacion)
        {
            if (operacion == null)
            {
                throw new ArgumentNullException(nameof(operacion));
            }

            if (!await _context.AdDocumentos.AnyAsync(d => d.Id == operacion.IdDocumento))
            {
                throw new InvalidOperationException($"No existe el documento con Id {operacion.IdDocumento}");
            }

            if (operacion.FechaAsociacion == default)
            {
                operacion.FechaAsociacion = DateTime.Now;
            }

            AdDocumentoOperacion entity;

            if (operacion.Id == 0)
            {
                entity = operacion;
                _context.AdDocumentoOperacion.Add(entity);
            }
            else
            {
                entity = await _context.AdDocumentoOperacion
                    .FirstOrDefaultAsync(o => o.Id == operacion.Id)
                    ?? throw new InvalidOperationException($"No se encontró la operación con Id {operacion.Id}");

                entity.IdDocumento = operacion.IdDocumento;
                entity.id_referencia = operacion.id_referencia;
                entity.id_rectificacion = operacion.id_rectificacion;
                entity.pedimento = operacion.pedimento;
                entity.FechaAsociacion = operacion.FechaAsociacion;
                entity.AsociadoPor = operacion.AsociadoPor;
            }

            await _context.SaveChangesAsync();
            return entity;
        }

        public async Task<CspAdGetPatenteRfcClienteRow?> GetPatenteRfcClienteByRelOperacionAsync(string idReferencia, decimal? idRectificacion)
        {
            var idReferenciaParam = new SqlParameter("@idReferencia", idReferencia);
            var idRectificacionParam = new SqlParameter("@idRectificacion", (object?)idRectificacion ?? DBNull.Value);

            var rows = await _context.CspAdGetPatenteRfcClienteRow
                .FromSqlRaw(
                    "EXEC csp_Ad_GetPatenteRfcClienteByRelOperacion @idReferencia, @idRectificacion",
                    idReferenciaParam,
                    idRectificacionParam)
                .AsNoTracking()
                .ToListAsync();

            return rows.FirstOrDefault();
        }

        public async Task<AdRelDocumentoEdoc?> GetRelDocumentoEdocAsync(long idDocumento, int idArchivo)
        {
            return await _context.AdRelDocumentoEdoc
                .AsNoTracking()
                .FirstOrDefaultAsync(r => r.IdDocumento == idDocumento && r.IdArchivo == idArchivo);
        }

        /// <summary>
        /// Obtiene la relación documento-eDOCS de la operación indicada, usando la misma lógica que
        /// <c>csp_Ad_GetDocumentoOperacion</c>: <c>ad_rel_documento_edoc</c> + <c>Tb_Archivos.Referencia</c>
        /// (referencia o referencia_rectificación).
        /// </summary>
        public async Task<AdRelDocumentoEdoc?> GetRelDocumentoEdocPorOperacionAsync(
            long idDocumento,
            string idReferencia,
            decimal? idRectificacion)
        {
            if (string.IsNullOrWhiteSpace(idReferencia))
            {
                return null;
            }

            var referenciaEdocs = idRectificacion.HasValue
                ? $"{idReferencia}_{idRectificacion.Value}"
                : idReferencia;

            var idArchivo = await _context.Database
                .SqlQueryRaw<int>(
                    @"SELECT TOP (1) ed.Id_Archivo AS Value
                      FROM dbo.ad_rel_documento_edoc ed WITH (NOLOCK)
                      INNER JOIN Edocs.dbo.Tb_Archivos ar WITH (NOLOCK)
                          ON ar.Id_Archivo = ed.Id_Archivo
                      WHERE ed.IdDocumento = {0}
                        AND ar.Referencia = {1}
                      ORDER BY ed.Id DESC",
                    idDocumento,
                    referenciaEdocs)
                .FirstOrDefaultAsync();

            if (idArchivo <= 0)
            {
                return null;
            }

            return await GetRelDocumentoEdocAsync(idDocumento, idArchivo);
        }

        public async Task<List<AdRelDocumentoEdoc>> GetRelsDocumentoEdocPorOperacionAsync(
            long idDocumento,
            string idReferencia,
            decimal? idRectificacion)
        {
            if (string.IsNullOrWhiteSpace(idReferencia))
            {
                return new List<AdRelDocumentoEdoc>();
            }

            var referenciaEdocs = idRectificacion.HasValue
                ? $"{idReferencia}_{idRectificacion.Value}"
                : idReferencia;

            var idsRel = await _context.Database
                .SqlQueryRaw<int>(
                    @"SELECT ed.Id AS Value
                      FROM dbo.ad_rel_documento_edoc ed WITH (NOLOCK)
                      INNER JOIN Edocs.dbo.Tb_Archivos ar WITH (NOLOCK)
                          ON ar.Id_Archivo = ed.Id_Archivo
                      WHERE ed.IdDocumento = {0}
                        AND ar.Referencia = {1}
                      ORDER BY ed.Id DESC",
                    idDocumento,
                    referenciaEdocs)
                .ToListAsync();

            if (idsRel.Count == 0)
            {
                return new List<AdRelDocumentoEdoc>();
            }

            return await _context.AdRelDocumentoEdoc
                .Where(r => idsRel.Contains(r.Id))
                .OrderByDescending(r => r.Id)
                .ToListAsync();
        }

        public async Task UpdateRelDocumentoEdocIdSelloEdocAsync(int idRel, int idSelloEdoc)
        {
            var rel = await _context.AdRelDocumentoEdoc.FindAsync(idRel)
                ?? throw new InvalidOperationException($"No se encontró la relación eDOCS con Id {idRel}");

            rel.IdSelloEdoc = idSelloEdoc;
            await _context.SaveChangesAsync();
        }

        public async Task UpdateDocumentoArchivoNombreEdocsAsync(long idDocumento, string nombreEdocs)
        {
            if (string.IsNullOrWhiteSpace(nombreEdocs))
            {
                throw new ArgumentException("NombreEdocs es requerido.", nameof(nombreEdocs));
            }

            var archivo = await _context.AdDocumentosArchivos
                .FirstOrDefaultAsync(a => a.IdDocumento == idDocumento)
                ?? throw new InvalidOperationException($"No se encontró el archivo del documento con Id {idDocumento}");

            archivo.NombreEdocs = nombreEdocs.Trim();
            await _context.SaveChangesAsync();
        }

        public async Task<bool> OperacionPendienteEnvioVucemAsync(long idDocumento, string idReferencia, decimal? idRectificacion)
        {
            var operaciones = await GetDocumentoOperacionesConEdocumentAsync(idDocumento);
            var fila = operaciones.FirstOrDefault(o =>
                o.id_referencia == idReferencia &&
                o.id_rectificacion == idRectificacion);

            if (fila == null)
            {
                return false;
            }

            var edoc = (fila.Edocument ?? string.Empty).Trim();
            var msg = (fila.Mensaje ?? string.Empty).Trim();
            var numero = (fila.Numero ?? string.Empty).Trim();

            if (!string.IsNullOrEmpty(numero))
            {
                return false;
            }

            if (!string.IsNullOrEmpty(edoc) && edoc != "0000000000000")
            {
                return false;
            }

            var sinEdocument = string.IsNullOrEmpty(edoc) || edoc == "0000000000000";
            if (sinEdocument && string.IsNullOrEmpty(msg))
            {
                return true;
            }

            return !string.IsNullOrEmpty(msg);
        }

        public async Task<bool> OperacionPuedeEliminarseRespectoVucemAsync(
            long idDocumento,
            string idReferencia,
            decimal? idRectificacion)
        {
            var operaciones = await GetDocumentoOperacionesConEdocumentAsync(idDocumento);
            var fila = operaciones.FirstOrDefault(o =>
                o.id_referencia == idReferencia &&
                o.id_rectificacion == idRectificacion);

            if (fila == null)
            {
                return false;
            }

            var edoc = (fila.Edocument ?? string.Empty).Trim();
            var numero = (fila.Numero ?? string.Empty).Trim();

            if (!string.IsNullOrEmpty(numero))
            {
                return false;
            }

            if (!string.IsNullOrEmpty(edoc) && edoc != "0000000000000")
            {
                return false;
            }

            return true;
        }

        public async Task<DateTime?> GetFechaPagoBancoByReferenciaAsync(string idReferencia, decimal? idRectificacion)
        {
            if (string.IsNullOrWhiteSpace(idReferencia))
            {
                return null;
            }

            var idReferenciaParam = new SqlParameter("@idReferencia", idReferencia);
            var idRectificacionParam = new SqlParameter("@idRectificacion", (object?)idRectificacion ?? DBNull.Value);

            var rows = await _context.CspAdGetFechaPagoBancoRow
                .FromSqlRaw(
                    "EXEC csp_Ad_GetFechaPagoBancoByRelOperacion @idReferencia, @idRectificacion",
                    idReferenciaParam,
                    idRectificacionParam)
                .AsNoTracking()
                .ToListAsync();

            return rows.FirstOrDefault()?.FechaPagoBanco;
        }

        public async Task<int> EliminarDocumentoOperacionesByClaveAsync(
            long idDocumento,
            string idReferencia,
            decimal? idRectificacion)
        {
            var query = _context.AdDocumentoOperacion
                .Where(o => o.IdDocumento == idDocumento && o.id_referencia == idReferencia);

            if (idRectificacion.HasValue)
            {
                query = query.Where(o => o.id_rectificacion == idRectificacion.Value);
            }
            else
            {
                query = query.Where(o => o.id_rectificacion == null);
            }

            var filas = await query.ToListAsync();
            if (filas.Count == 0)
            {
                return 0;
            }

            _context.AdDocumentoOperacion.RemoveRange(filas);
            await _context.SaveChangesAsync();
            return filas.Count;
        }

        public async Task EliminarRelDocumentoEdocAsync(int idRel)
        {
            var rel = await _context.AdRelDocumentoEdoc.FindAsync(idRel);
            if (rel == null)
            {
                return;
            }

            _context.AdRelDocumentoEdoc.Remove(rel);
            await _context.SaveChangesAsync();
        }

        public async Task<AdRelDocumentoEdoc> SaveRelDocumentoEdocAsync(long idDocumento, int idArchivo, string creadoPor)
        {
            if (!await _context.AdDocumentos.AnyAsync(d => d.Id == idDocumento))
            {
                throw new InvalidOperationException($"No existe el documento con Id {idDocumento}");
            }

            var rel = new AdRelDocumentoEdoc
            {
                IdDocumento = idDocumento,
                IdArchivo = idArchivo,
                FechaRegistro = DateTime.Now,
                CreadoPor = creadoPor ?? string.Empty
            };

            _context.AdRelDocumentoEdoc.Add(rel);
            await _context.SaveChangesAsync();

            return rel;
        }

        [Obsolete("Usar InsertarDatosPedimentoV2Async con csp_ad_InsertaDatosPedimento_v2.")]
        public async Task<bool> InsertarDatosPedimentoAsync(long idDocumento, string idReferencia, int? idRectificacion, string? pedimento)
        {
            var idDocumentoParam = new SqlParameter("@idDocumento", idDocumento);
            var idReferenciaParam = new SqlParameter("@idReferencia", idReferencia ?? (object)DBNull.Value);
            var idRectificacionParam = new SqlParameter("@idRectificacion", idRectificacion ?? (object)DBNull.Value);
            var pedimentoParam = new SqlParameter("@pedimento", (pedimento == string.Empty ? null : pedimento) ?? (object)DBNull.Value);
            var returnParam = new SqlParameter("@ReturnValue", SqlDbType.Bit)
            {
                Direction = ParameterDirection.Output
            };

            await _context.Database.ExecuteSqlRawAsync(
                "EXEC @ReturnValue = csp_ad_InsertaDatosPedimento @idDocumento, @idReferencia, @idRectificacion, @pedimento",
                returnParam,
                idDocumentoParam,
                idReferenciaParam,
                idRectificacionParam,
                pedimentoParam);

            return returnParam.Value is bool boolResult && boolResult;
        }

        public async Task<InsertarDatosPedimentoResultDto> InsertarDatosPedimentoV2Async(long idDocumento, string idReferencia, int? idRectificacion, string? pedimento)
        {
            // Transferencia a pedimento/tráfico puede tardar con muchas fracciones/partes (default EF = 30s).
            _context.Database.SetCommandTimeout(TimeSpan.FromMinutes(10));

            var idDocumentoParam = new SqlParameter("@idDocumento", idDocumento);
            var idReferenciaParam = new SqlParameter("@idReferencia", idReferencia ?? (object)DBNull.Value);
            var idRectificacionParam = new SqlParameter("@idRectificacion", idRectificacion ?? (object)DBNull.Value);
            var pedimentoParam = new SqlParameter("@pedimento", (pedimento == string.Empty ? null : pedimento) ?? (object)DBNull.Value);

            var rows = await _context.Database
                .SqlQueryRaw<InsertarDatosPedimentoResultDto>(
                    "EXEC csp_ad_InsertaDatosPedimento_v2 @idDocumento, @idReferencia, @idRectificacion, @pedimento",
                    idDocumentoParam,
                    idReferenciaParam,
                    idRectificacionParam,
                    pedimentoParam)
                .ToListAsync();

            var row = rows.FirstOrDefault();
            if (row == null)
            {
                return new InsertarDatosPedimentoResultDto
                {
                    Resultado = false,
                    MensajeEjecucion = string.Empty
                };
            }

            return row;
        }
    }
}
