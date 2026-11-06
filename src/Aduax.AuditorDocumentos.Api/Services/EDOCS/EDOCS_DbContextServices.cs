using System.Data;
using System.Data.Common;
using Microsoft.EntityFrameworkCore;
using Aduax.AuditorDocumentos.Api.Data;
using Aduax.AuditorDocumentos.Api.Data.EDOCS;

namespace Aduax.AuditorDocumentos.Api.Services.EDOCS
{
    public class EDOCS_DbContextServices : IEDOCS_DbContextServices
    {
        private readonly EDOCS_DBContext _context;

        public EDOCS_DbContextServices(EDOCS_DBContext context)
        {
            _context = context;
        }

        public async Task<(List<TbDocumentosVucem> Data, int TotalRecords)> GetDocumentosVucemActivosConPrefijoAsync(string? filter, int page, int size)
        {
            // Validar parámetros de paginación
            if (page < 1) page = 1;
            if (size < 1) size = 10;

            var query = _context.TbDocumentosVucem
                .Where(x => x.ActivoAuditorDocumentos && x.PrefijoEI != null);

            // Aplicar filtro si existe
            if (!string.IsNullOrWhiteSpace(filter))
            {
                query = query.Where(x => 
                    x.Documento.Contains(filter) ||
                    (x.PrefijoEI != null && x.PrefijoEI.Contains(filter)) ||
                    (x.NombreAnterior != null && x.NombreAnterior.Contains(filter)));
            }

            // Obtener total de registros antes de paginar
            int totalRecords = await query.CountAsync();

            // Aplicar paginación
            int skip = (page - 1) * size;
            var data = await query
                .OrderBy(x => x.Documento)
                .Skip(skip)
                .Take(size)
                .ToListAsync();

            return (data, totalRecords);
        }

        public async Task<TbDocumentosVucem?> GetDocumentoVucemporIdTipoDocumentoVucemAsync(int idTipoDocumentoVucemAduana)
        {
            return await _context.TbDocumentosVucem
                .FirstOrDefaultAsync(x => x.Id_DocumentoVucem == idTipoDocumentoVucemAduana);
        }

        public async Task<int> InsertEdocsAsync(string referencia, string rutaLocal, string rutaRemota, string serverUrl, string link, int idUsuario, string idDoc, string idDocVucem, string tipoVucemAnexo, string tipoOperacionReferencia, string tipoOperacionReferenciaId)
        {
            // Limpiar ruta remota removiendo el serverUrl si está presente
            string rutaRemotaLimpia = rutaRemota?.Replace(serverUrl ?? "", "") ?? "";

            var idArchivoRows = await _context.Database.SqlQueryRaw<int>(
                "EXEC Edocs.dbo.csp_Archivos_Ins_EdocsYVucem_2023 {0}, {1}, {2}, {3}, {4}, {5}, {6}, {7}, {8}, {9}, {10}, {11}, {12}, {13}, {14}, {15}, {16}",
                0,
                referencia ?? "",
                tipoOperacionReferenciaId ?? "",
                rutaLocal ?? "",
                rutaRemotaLimpia,
                serverUrl ?? "",
                idUsuario,
                1,
                idDoc ?? "",
                "",
                "",
                "",
                0,
                tipoVucemAnexo ?? "",
                tipoOperacionReferencia ?? "",
                link ?? "",
                idDocVucem ?? "")
                .ToListAsync();

            return idArchivoRows.Single();
        }

        public async Task<int?> GetIdArchivoPorReferenciaAsync(string referenciaEdocs)
        {
            if (string.IsNullOrWhiteSpace(referenciaEdocs))
            {
                return null;
            }

            var rows = await _context.Database.SqlQueryRaw<int>(
                "SELECT Id_Archivo AS Value FROM Edocs.dbo.Tb_Archivos WITH (NOLOCK) WHERE Referencia = {0}",
                referenciaEdocs)
                .ToListAsync();

            return rows.FirstOrDefault();
        }

        public async Task<CspVuceSellosRfcResult?> GetVuceSellosPorRfcAsync(string rfc)
        {
            if (string.IsNullOrWhiteSpace(rfc))
            {
                return null;
            }

            var connection = _context.Database.GetDbConnection();
            var wasOpen = connection.State == ConnectionState.Open;
            if (!wasOpen)
            {
                await connection.OpenAsync();
            }

            try
            {
                await using var command = connection.CreateCommand();
                command.CommandText = "EXEC csp_VuceSellosClientes_RFC @rfc";
                var param = command.CreateParameter();
                param.ParameterName = "@rfc";
                param.Value = rfc;
                command.Parameters.Add(param);

                await using var reader = await command.ExecuteReaderAsync();
                if (!await reader.ReadAsync())
                {
                    return null;
                }

                // Rama sin sello: SELECT 0 AS Resultado, '' AS Patente
                if (HasColumn(reader, "Resultado"))
                {
                    return null;
                }

                if (!HasColumn(reader, "Id_Sello_Cliente"))
                {
                    return null;
                }

                var idSelloCliente = ReadInt32(reader, "Id_Sello_Cliente");
                var idSelloAduana = HasColumn(reader, "Id_Sello_Aduana")
                    ? ReadInt32(reader, "Id_Sello_Aduana")
                    : 0;

                if (idSelloCliente <= 0 && idSelloAduana <= 0)
                {
                    return null;
                }

                return new CspVuceSellosRfcResult
                {
                    IdSelloCliente = idSelloCliente,
                    IdSelloAduana = idSelloAduana
                };
            }
            finally
            {
                if (!wasOpen)
                {
                    await connection.CloseAsync();
                }
            }
        }

        private static bool HasColumn(DbDataReader reader, string columnName)
        {
            for (var i = 0; i < reader.FieldCount; i++)
            {
                if (reader.GetName(i).Equals(columnName, StringComparison.OrdinalIgnoreCase))
                {
                    return true;
                }
            }

            return false;
        }

        private static int ReadInt32(DbDataReader reader, string columnName)
        {
            var ordinal = reader.GetOrdinal(columnName);
            if (reader.IsDBNull(ordinal))
            {
                return 0;
            }

            return reader.GetValue(ordinal) switch
            {
                int i => i,
                long l => (int)l,
                short s => s,
                string str when int.TryParse(str, out var parsed) => parsed,
                _ => Convert.ToInt32(reader.GetValue(ordinal))
            };
        }

        public async Task<int?> GetIdSelloAgentePorPatenteAsync(string patente)
        {
            if (string.IsNullOrWhiteSpace(patente))
            {
                return null;
            }

            var rows = await _context.CspVuceSellosAgenteResult
                .FromSqlRaw("EXEC csp_VuceSellosClientes_Sel_AgenteAduanal_AmazonS3 {0}", patente)
                .AsNoTracking()
                .ToListAsync();

            return rows.FirstOrDefault()?.IdSello;
        }

        public async Task AnularArchivoEdocsAsync(int idArchivo)
        {
            if (idArchivo <= 0)
            {
                throw new ArgumentOutOfRangeException(nameof(idArchivo), "Id_Archivo inválido.");
            }

            await _context.Database.ExecuteSqlRawAsync(
                "EXEC dbo.csp_Archivos_Upd_StatusAnulado {0}",
                idArchivo);
        }
    }
}
