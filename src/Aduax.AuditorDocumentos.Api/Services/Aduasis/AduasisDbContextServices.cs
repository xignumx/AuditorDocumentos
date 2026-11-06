using System.Data;
using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore.Storage;
using Aduax.AuditorDocumentos.Api.Data;
using Aduax.AuditorDocumentos.Api.Data.Aduasis;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.Aduasis
{
    public class AduasisDbContextServices : IAduasisDbContextServices
    {
        private readonly Aduasis_DBContext _context;

        public AduasisDbContextServices(Aduasis_DBContext context)
        {
            _context = context;
        }

        public async Task<(List<FCliente> Data, int TotalRecords)> GetClientesAsync(string? filter, int page, int size)
        {
            // Validar parámetros de paginación
            if (page < 1) page = 1;
            if (size < 1) size = 10;

            var query = _context.FCliente
                .Where(x => x.CveCliente != "0")
                .AsQueryable();

            // Aplicar filtro si existe
            if (!string.IsNullOrWhiteSpace(filter))
            {
                query = query.Where(x => 
                    x.IdCliente.Contains(filter) ||
                    x.RazonSocial.Contains(filter) ||
                    x.Rfc.Contains(filter));
            }

            // Obtener total de registros antes de paginar
            int totalRecords = await query.CountAsync();

            // Aplicar paginación
            int skip = (page - 1) * size;
            var data = await query
                .OrderBy(x => x.RazonSocial)
                .Skip(skip)
                .Take(size)
                .ToListAsync();

            return (data, totalRecords);
        }

        public async Task<(List<FAduana> Data, int TotalRecords)> GetAduanasAsync(string? filter, int page, int size)
        {
            // Validar parámetros de paginación
            if (page < 1) page = 1;
            if (size < 1) size = 10;

            var query = _context.FAduana.Distinct().AsQueryable();

            // Aplicar filtro si existe (buscar en aduana concatenada o descripción)
            if (!string.IsNullOrWhiteSpace(filter))
            {
                query = query.Where(x => 
                    (x.IdAduana + x.SeccionAduana).Contains(filter) ||
                    (x.DescripcionOficial ?? "-").Contains(filter));
            }

            // Obtener total de registros antes de paginar
            int totalRecords = await query.CountAsync();

            // Aplicar paginación
            int skip = (page - 1) * size;
            var data = await query
                .OrderBy(x => x.IdAduana)
                .ThenBy(x => x.SeccionAduana)
                .Skip(skip)
                .Take(size)
                .ToListAsync();

            return (data, totalRecords);
        }

        public async Task<(List<FRegimen> Data, int TotalRecords)> GetRegimenesAsync(string? filter, int page, int size, string? cveTipoOperacion)
        {
            // Validar parámetros de paginación
            if (page < 1) page = 1;
            if (size < 1) size = 10;
            var query = _context.FRegimen
                .Where(x => string.IsNullOrEmpty(cveTipoOperacion) || x.CveTipoOperacion == cveTipoOperacion)
                .Distinct()
                .AsQueryable();

            // Aplicar filtro si existe (buscar en id_regimen o descripcion_reg)
            if (!string.IsNullOrWhiteSpace(filter))
            {
                query = query.Where(x => 
                    x.IdRegimen.Contains(filter));
            }

            // Obtener total de registros antes de paginar
            int totalRecords = await query.CountAsync();

            // Aplicar paginación
            int skip = (page - 1) * size;
            var data = await query
                .OrderBy(x => x.IdRegimen)
                .Skip(skip)
                .Take(size)
                .ToListAsync();

            return (data, totalRecords);
        }

        public async Task<FCliente> GetClienteAsync(string idCliente)
        {
            return await _context.FCliente
                .FirstOrDefaultAsync(c => c.IdCliente == idCliente)
                ?? throw new KeyNotFoundException($"Cliente con Id '{idCliente}' no encontrado.");
        }

        public async Task<string?> ValidaFraccionAsync(string idCliente, string idFraccion)
        {
            var sql = @"
                SELECT TOP 1 id_fraccion_mex AS Value
                FROM ADUASIS.dbo.frel_prod_frac 
                WHERE id_cliente = @idCliente AND id_fraccion_mex like @idFraccion + '%'";

            var idClienteParam = new SqlParameter("@idCliente", idCliente);
            var idFraccionParam = new SqlParameter("@idFraccion", idFraccion);

            // Ejecutar consulta, materializar con ToListAsync y luego obtener el primer resultado
            var results = await _context.Database
                .SqlQueryRaw<ScalarResult>(sql, idClienteParam, idFraccionParam)
                .ToListAsync();

            return results.FirstOrDefault()?.Value;
        }

        public async Task<string?> ValidaUnidadMedidaAsync(string unidadMedida)
        {
            var sql = @"
                SELECT TOP 1 id_unidad_universal AS Value
                FROM ADUASIS.dbo.funidad_universal 
                WHERE id_unidad_universal = @um
                   OR descripcion LIKE '%' + @um + '%' 
                   OR desc_abreviada = @um";

            var umParam = new SqlParameter("@um", unidadMedida);

            // Ejecutar consulta, materializar con ToListAsync y luego obtener el primer resultado
            var results = await _context.Database
                .SqlQueryRaw<ScalarResult>(sql, umParam)
                .ToListAsync();

            return results.FirstOrDefault()?.Value;
        }

        public async Task<string?> ValidaPaisAsync(string pais)
        {
            var sql = @"
                SELECT TOP 1 id_pais AS Value
                FROM ADUASIS.dbo.fpais 
                WHERE descripcion LIKE '%' + @pais + '%' 
                   OR desc_breve LIKE @pais
                   OR cve_pais like @pais";

            var paisParam = new SqlParameter("@pais", pais);

            // Ejecutar consulta, materializar con ToListAsync y luego obtener el primer resultado
            var results = await _context.Database
                .SqlQueryRaw<ScalarResult>(sql, paisParam)
                .ToListAsync();

            return results.FirstOrDefault()?.Value;
        }

        public async Task<List<CspAdSugerenciaPedimentos>> GetSugerenciaPedimentosAsync(
            string idCliente,
            long idAdDocumento,
            string operacionBusqueda,
            int pageNumber,
            int pageSize)
        {
            var idClienteParam = new SqlParameter("@idCliente", SqlDbType.VarChar, 10)
            {
                Value = idCliente ?? (object)DBNull.Value
            };
            var idAdDocumentoParam = new SqlParameter("@idAdDocumento", SqlDbType.BigInt) { Value = idAdDocumento };
            var operacionBusquedaParam = CreateVarcharParameter("@operacionBusqueda", operacionBusqueda, 40);
            var pageNumberParam = new SqlParameter("@PageNumber", SqlDbType.Int) { Value = pageNumber };
            var pageSizeParam = new SqlParameter("@PageSize", SqlDbType.Int) { Value = pageSize };

            _context.Database.SetCommandTimeout(System.TimeSpan.FromMinutes(5));

            return await _context.CspAdSugerenciaPedimentos
                .FromSqlRaw(
                    "EXEC csp_Ad_SugerenciaPedimentos_v2 @idCliente, @idAdDocumento, @operacionBusqueda, @PageNumber, @PageSize",
                    idClienteParam,
                    idAdDocumentoParam,
                    operacionBusquedaParam,
                    pageNumberParam,
                    pageSizeParam)
                .ToListAsync();
        }

        public async Task<List<CspAdDiagnosticoSugerenciaPedimentoRow>> GetDiagnosticoSugerenciaPedimentosAsync(
            string idCliente,
            long idAdDocumento,
            string operacionBusqueda)
        {
            var idClienteParam = new SqlParameter("@idCliente", idCliente ?? (object)DBNull.Value);
            var idAdDocumentoParam = new SqlParameter("@idAdDocumento", idAdDocumento);
            var operacionBusquedaParam = CreateVarcharParameter("@operacionBusqueda", operacionBusqueda, 40);

            const string sql =
                "EXEC csp_Ad_DiagnosticoSugerenciaPedimentos_v2 @idCliente, @idAdDocumento, @operacionBusqueda";

            return await _context.Database
                .SqlQueryRaw<CspAdDiagnosticoSugerenciaPedimentoRow>(
                    sql,
                    idClienteParam,
                    idAdDocumentoParam,
                    operacionBusquedaParam)
                .ToListAsync();
        }

        public async Task<FUsuario?> GetUsuarioPorUsuauarioAsync(string usuario)
        {
            var usuarioEntity = await _context.FUsuario
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Usuario == usuario);
            
            return usuarioEntity;
        }

        public async Task<bool> EsUsuarioAdminLider(string usuario)
        {
            if (string.IsNullOrWhiteSpace(usuario))
            {
                return false;
            }

            var usuarioEntity = await _context.FUsuario
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Usuario == usuario);

            if (usuarioEntity == null)
            {
                return false;
            }

            return string.Equals(usuarioEntity.IdClase, "ADM", StringComparison.OrdinalIgnoreCase) ||
                   string.Equals(usuarioEntity.IdClase, "LIDER", StringComparison.OrdinalIgnoreCase) ||
                   string.Equals(usuarioEntity.IdClase, "CALIDAD", StringComparison.OrdinalIgnoreCase);
        }

        public async Task<int> GetIdUsuarioEdocsAsync(string usuario)
        {
            if (string.IsNullOrWhiteSpace(usuario))
            {
                return 0;
            }

            var sql = @"SELECT TOP 1 Id_Usuario AS Value FROM SUITE.dbo.Tb_Usuarios WITH (NOLOCK) WHERE usuario = @usuario";
            var usuarioParam = new SqlParameter("@usuario", usuario);

            var results = await _context.Database
                .SqlQueryRaw<IntegerResult>(sql, usuarioParam)
                .ToListAsync();

            var value = results.FirstOrDefault()?.Value;
            return value ?? 0;
        }

        private static SqlParameter CreateVarcharParameter(string name, string? value, int size)
        {
            return new SqlParameter(name, SqlDbType.VarChar, size)
            {
                Value = value ?? string.Empty
            };
        }
    }
}
