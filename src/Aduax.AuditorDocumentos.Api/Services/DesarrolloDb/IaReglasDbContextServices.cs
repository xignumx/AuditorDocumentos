using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using Aduax.AuditorDocumentos.Api.Data;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services.DesarrolloDb
{
    public class IaReglasDbContextServices : IIaReglasDbContextServices
    {
        private const int MaxPromptDocumento = 5000;
        private const int MaxPromptCampo = 2000;
        private const int MaxConcepto = 100;
        private const int MaxTermino = 200;

        private readonly DesarrolloDB_DBContext _context;

        public IaReglasDbContextServices(DesarrolloDB_DBContext context)
        {
            _context = context;
        }

        // ===== Prompts =====

        public async Task<IaPromptsDto> GetPromptsAsync(long idTipoDocumentoVucem)
        {
            var documento = await _context.AdIaPromptDocumento
                .AsNoTracking()
                .FirstOrDefaultAsync(p => p.IdTipoDocumentoVucem == idTipoDocumentoVucem);

            var campos = await _context.AdIaPromptCampo
                .AsNoTracking()
                .Where(p => p.IdTipoDocumentoVucem == idTipoDocumentoVucem)
                .OrderBy(p => p.IdCampo)
                .ToListAsync();

            var versionDocumento = documento == null
                ? 0
                : await GetVersionActualAsync(
                    AdIaConfigEntidad.PromptDocumento,
                    ClaveDocumento(idTipoDocumentoVucem),
                    existe: true);

            // Una sola consulta para las versiones de todos los prompts de campo del tipo
            var versionesCampo = await _context.AdIaConfigHistorial
                .AsNoTracking()
                .Where(h => h.Entidad == AdIaConfigEntidad.PromptCampo
                            && h.IdTipoDocumentoVucem == idTipoDocumentoVucem
                            && h.IdCampo != null)
                .GroupBy(h => h.IdCampo!.Value)
                .Select(g => new { IdCampo = g.Key, Version = g.Max(x => x.Version) })
                .ToDictionaryAsync(x => x.IdCampo, x => x.Version);

            return new IaPromptsDto
            {
                PromptDocumento = documento == null
                    ? null
                    : new IaPromptDocumentoDto
                    {
                        Id = documento.Id,
                        IdTipoDocumentoVucem = documento.IdTipoDocumentoVucem,
                        Prompt = documento.Prompt,
                        Activo = documento.Activo,
                        Version = versionDocumento,
                        FechaActualizacion = documento.FechaActualizacion ?? documento.FechaCreacion,
                        ActualizadoPor = documento.ActualizadoPor ?? documento.CreadoPor
                    },
                PromptsCampo = campos.Select(c => new IaPromptCampoDto
                {
                    Id = c.Id,
                    IdTipoDocumentoVucem = c.IdTipoDocumentoVucem,
                    IdCampo = c.IdCampo,
                    NombreCampo = c.NombreCampo,
                    PromptParcial = c.PromptParcial,
                    Activo = c.Activo,
                    Version = versionesCampo.TryGetValue(c.IdCampo, out var version) ? version : 1,
                    FechaActualizacion = c.FechaActualizacion ?? c.FechaCreacion,
                    ActualizadoPor = c.ActualizadoPor ?? c.CreadoPor
                }).ToList()
            };
        }

        public async Task<IaPromptsDto> SavePromptAsync(
            long idTipoDocumentoVucem,
            GuardarIaPromptRequest request,
            string usuario)
        {
            if (idTipoDocumentoVucem <= 0)
            {
                throw new InvalidOperationException("IdTipoDocumentoVucem es requerido y debe ser mayor a cero");
            }

            var texto = request.Texto?.Trim() ?? string.Empty;
            if (texto.Length == 0)
            {
                throw new InvalidOperationException("El texto del prompt es requerido");
            }

            var tipo = request.Tipo?.Trim().ToUpperInvariant();
            if (tipo == IaPromptTipo.Documento)
            {
                await GuardarPromptDocumentoAsync(idTipoDocumentoVucem, texto, request.Activo, usuario);
            }
            else if (tipo == IaPromptTipo.Campo)
            {
                await GuardarPromptCampoAsync(idTipoDocumentoVucem, request.IdCampo, texto, request.Activo, usuario);
            }
            else
            {
                throw new InvalidOperationException("El tipo de prompt debe ser DOCUMENTO o CAMPO");
            }

            return await GetPromptsAsync(idTipoDocumentoVucem);
        }

        private async Task GuardarPromptDocumentoAsync(long idTipo, string texto, bool activo, string usuario)
        {
            if (texto.Length > MaxPromptDocumento)
            {
                throw new InvalidOperationException($"El prompt del documento no puede exceder {MaxPromptDocumento} caracteres");
            }

            // La plantilla se completa con estos marcadores; sin ellos la IA no recibe campos ni estructura de respuesta.
            if (!texto.Contains("[CAMPOS]", StringComparison.Ordinal) || !texto.Contains("[JSON]", StringComparison.Ordinal))
            {
                throw new InvalidOperationException("El prompt del documento debe conservar los marcadores [CAMPOS] y [JSON]");
            }

            var ahora = DateTime.Now;
            var clave = ClaveDocumento(idTipo);
            var existente = await _context.AdIaPromptDocumento
                .FirstOrDefaultAsync(p => p.IdTipoDocumentoVucem == idTipo);

            if (existente == null)
            {
                _context.AdIaPromptDocumento.Add(new AdIaPromptDocumento
                {
                    IdTipoDocumentoVucem = idTipo,
                    Prompt = texto,
                    Activo = activo,
                    FechaCreacion = ahora,
                    CreadoPor = usuario
                });
                AddHistorial(AdIaConfigEntidad.PromptDocumento, clave, idTipo, null, 1,
                    AdIaConfigAccion.Alta, null, texto, usuario, ahora);
            }
            else
            {
                var textoCambio = !string.Equals(existente.Prompt, texto, StringComparison.Ordinal);
                var activoCambio = existente.Activo != activo;
                if (!textoCambio && !activoCambio)
                {
                    return;
                }

                var version = await GetVersionActualAsync(AdIaConfigEntidad.PromptDocumento, clave, existe: true) + 1;
                if (textoCambio)
                {
                    AddHistorial(AdIaConfigEntidad.PromptDocumento, clave, idTipo, null, version,
                        AdIaConfigAccion.Cambio, existente.Prompt, texto, usuario, ahora);
                }
                if (activoCambio)
                {
                    AddHistorial(AdIaConfigEntidad.PromptDocumento, clave, idTipo, null, version,
                        AdIaConfigAccion.Cambio, $"Activo: {SiNo(existente.Activo)}", $"Activo: {SiNo(activo)}", usuario, ahora);
                }

                existente.Prompt = texto;
                existente.Activo = activo;
                existente.FechaActualizacion = ahora;
                existente.ActualizadoPor = usuario;
            }

            await _context.SaveChangesAsync();
        }

        private async Task GuardarPromptCampoAsync(long idTipo, int? idCampo, string texto, bool activo, string usuario)
        {
            if (!idCampo.HasValue || !Enum.IsDefined(typeof(AdCampos), idCampo.Value))
            {
                throw new InvalidOperationException("El campo del prompt no es válido");
            }

            if (texto.Length > MaxPromptCampo)
            {
                throw new InvalidOperationException($"El prompt del campo no puede exceder {MaxPromptCampo} caracteres");
            }

            // El texto se inserta como valor de la estructura JSON de ejemplo que recibe la IA.
            if (texto.Contains('"'))
            {
                throw new InvalidOperationException("El prompt del campo no puede contener comillas dobles (\")");
            }

            var ahora = DateTime.Now;
            var campo = idCampo.Value;
            var nombreCampo = Enum.GetName(typeof(AdCampos), campo) ?? campo.ToString();
            var clave = ClaveCampo(idTipo, campo);
            var existente = await _context.AdIaPromptCampo
                .FirstOrDefaultAsync(p => p.IdTipoDocumentoVucem == idTipo && p.IdCampo == campo);

            if (existente == null)
            {
                _context.AdIaPromptCampo.Add(new AdIaPromptCampo
                {
                    IdTipoDocumentoVucem = idTipo,
                    IdCampo = campo,
                    NombreCampo = nombreCampo,
                    PromptParcial = texto,
                    Activo = activo,
                    FechaCreacion = ahora,
                    CreadoPor = usuario
                });
                AddHistorial(AdIaConfigEntidad.PromptCampo, clave, idTipo, campo, 1,
                    AdIaConfigAccion.Alta, null, texto, usuario, ahora);
            }
            else
            {
                var textoCambio = !string.Equals(existente.PromptParcial, texto, StringComparison.Ordinal);
                var activoCambio = existente.Activo != activo;
                if (!textoCambio && !activoCambio)
                {
                    return;
                }

                var version = await GetVersionActualAsync(AdIaConfigEntidad.PromptCampo, clave, existe: true) + 1;
                if (textoCambio)
                {
                    AddHistorial(AdIaConfigEntidad.PromptCampo, clave, idTipo, campo, version,
                        AdIaConfigAccion.Cambio, existente.PromptParcial, texto, usuario, ahora);
                }
                if (activoCambio)
                {
                    AddHistorial(AdIaConfigEntidad.PromptCampo, clave, idTipo, campo, version,
                        AdIaConfigAccion.Cambio, $"Activo: {SiNo(existente.Activo)}", $"Activo: {SiNo(activo)}", usuario, ahora);
                }

                existente.PromptParcial = texto;
                existente.Activo = activo;
                existente.FechaActualizacion = ahora;
                existente.ActualizadoPor = usuario;
            }

            await _context.SaveChangesAsync();
        }

        // ===== Diccionario =====

        public async Task<List<IaDiccionarioConceptoDto>> GetDiccionarioAsync(string? categoria)
        {
            var categoriaNormalizada = string.IsNullOrWhiteSpace(categoria)
                ? null
                : IaDiccionarioCategoria.Normalizar(categoria)
                    ?? throw new InvalidOperationException("La categoría debe ser GENERAL o UM");

            var query = _context.AdIaDiccionario.AsNoTracking().AsQueryable();
            if (categoriaNormalizada != null)
            {
                query = query.Where(d => d.Categoria == categoriaNormalizada);
            }

            var filas = await query.OrderBy(d => d.Id).ToListAsync();

            return filas
                .GroupBy(d => new { d.Categoria, d.Concepto })
                .OrderBy(g => g.Key.Categoria)
                .ThenBy(g => g.Key.Concepto, StringComparer.CurrentCultureIgnoreCase)
                .Select(g => new IaDiccionarioConceptoDto
                {
                    Categoria = g.Key.Categoria,
                    Concepto = g.Key.Concepto,
                    IdCampo = g.Select(x => x.IdCampo).FirstOrDefault(x => x.HasValue),
                    TerminosEs = g.Where(x => x.Idioma == "ES").Select(x => x.Termino).ToList(),
                    TerminosEn = g.Where(x => x.Idioma == "EN").Select(x => x.Termino).ToList()
                })
                .ToList();
        }

        public async Task<IaDiccionarioConceptoDto> SaveDiccionarioConceptoAsync(IaDiccionarioConceptoDto concepto, string usuario)
        {
            var categoria = IaDiccionarioCategoria.Normalizar(concepto.Categoria)
                ?? throw new InvalidOperationException("La categoría debe ser GENERAL o UM");

            var nombreConcepto = LimpiarTexto(concepto.Concepto);
            if (nombreConcepto.Length == 0)
            {
                throw new InvalidOperationException("El concepto es requerido");
            }
            if (nombreConcepto.Length > MaxConcepto)
            {
                throw new InvalidOperationException($"El concepto no puede exceder {MaxConcepto} caracteres");
            }

            int? idCampo = null;
            if (categoria == IaDiccionarioCategoria.General && concepto.IdCampo.HasValue)
            {
                if (!Enum.IsDefined(typeof(AdCampos), concepto.IdCampo.Value))
                {
                    throw new InvalidOperationException("El campo destino no es válido");
                }
                idCampo = concepto.IdCampo.Value;
            }

            var terminos = ConstruirTerminos(concepto.TerminosEs, concepto.TerminosEn);
            if (terminos.Count == 0)
            {
                throw new InvalidOperationException(
                    "Capture al menos un término; para quitar el concepto use la opción de eliminar");
            }

            // Un término solo puede pertenecer a un concepto de la categoría (evita falsos positivos)
            var textos = terminos.Select(t => t.Termino).ToList();
            var conflicto = await _context.AdIaDiccionario
                .AsNoTracking()
                .Where(d => d.Categoria == categoria && d.Concepto != nombreConcepto && textos.Contains(d.Termino))
                .Select(d => new { d.Termino, d.Concepto })
                .FirstOrDefaultAsync();
            if (conflicto != null)
            {
                throw new InvalidOperationException(
                    $"El término '{conflicto.Termino}' ya pertenece al concepto '{conflicto.Concepto}'");
            }

            var existentes = await _context.AdIaDiccionario
                .Where(d => d.Categoria == categoria && d.Concepto == nombreConcepto)
                .ToListAsync();

            var descripcionAnterior = existentes.Count == 0
                ? null
                : DescribirConcepto(
                    existentes.Select(e => (e.Termino, e.Idioma)).ToList(),
                    existentes.Select(e => e.IdCampo).FirstOrDefault(x => x.HasValue));
            var descripcionNueva = DescribirConcepto(terminos, idCampo);

            if (string.Equals(descripcionAnterior, descripcionNueva, StringComparison.Ordinal))
            {
                return ConstruirDto(categoria, nombreConcepto, idCampo, terminos);
            }

            var ahora = DateTime.Now;
            var terminosNuevos = terminos.ToDictionary(t => t.Termino, t => t, StringComparer.OrdinalIgnoreCase);

            // Quitar los términos que ya no están
            var aEliminar = existentes.Where(e => !terminosNuevos.ContainsKey(e.Termino)).ToList();
            _context.AdIaDiccionario.RemoveRange(aEliminar);

            // Actualizar los que se conservan (idioma, campo destino o mayúsculas del texto)
            foreach (var fila in existentes.Except(aEliminar))
            {
                var nuevo = terminosNuevos[fila.Termino];
                if (fila.Idioma != nuevo.Idioma || fila.IdCampo != idCampo
                    || !string.Equals(fila.Termino, nuevo.Termino, StringComparison.Ordinal))
                {
                    fila.Termino = nuevo.Termino;
                    fila.Idioma = nuevo.Idioma;
                    fila.IdCampo = idCampo;
                    fila.FechaActualizacion = ahora;
                    fila.ActualizadoPor = usuario;
                }
            }

            // Agregar los nuevos
            var yaExisten = existentes.Select(e => e.Termino).ToHashSet(StringComparer.OrdinalIgnoreCase);
            foreach (var (termino, idioma) in terminos.Where(t => !yaExisten.Contains(t.Termino)))
            {
                _context.AdIaDiccionario.Add(new AdIaDiccionario
                {
                    Categoria = categoria,
                    Concepto = nombreConcepto,
                    IdCampo = idCampo,
                    Termino = termino,
                    Idioma = idioma,
                    FechaCreacion = ahora,
                    CreadoPor = usuario
                });
            }

            var clave = ClaveDiccionario(categoria, nombreConcepto);
            var version = await GetVersionActualAsync(
                AdIaConfigEntidad.Diccionario, clave, existe: existentes.Count > 0) + 1;
            AddHistorial(
                AdIaConfigEntidad.Diccionario, clave, null, idCampo, version,
                existentes.Count == 0 ? AdIaConfigAccion.Alta : AdIaConfigAccion.Cambio,
                descripcionAnterior, descripcionNueva, usuario, ahora);

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateException)
            {
                throw new InvalidOperationException(
                    "No se pudo guardar el diccionario: alguno de los términos ya existe en otro concepto");
            }

            return ConstruirDto(categoria, nombreConcepto, idCampo, terminos);
        }

        public async Task DeleteDiccionarioConceptoAsync(string categoria, string concepto, string usuario)
        {
            var categoriaNormalizada = IaDiccionarioCategoria.Normalizar(categoria)
                ?? throw new InvalidOperationException("La categoría debe ser GENERAL o UM");
            var nombreConcepto = LimpiarTexto(concepto);
            if (nombreConcepto.Length == 0)
            {
                throw new InvalidOperationException("El concepto es requerido");
            }

            var filas = await _context.AdIaDiccionario
                .Where(d => d.Categoria == categoriaNormalizada && d.Concepto == nombreConcepto)
                .ToListAsync();
            if (filas.Count == 0)
            {
                throw new InvalidOperationException("El concepto no existe en el diccionario");
            }

            var clave = ClaveDiccionario(categoriaNormalizada, nombreConcepto);
            var idCampo = filas.Select(f => f.IdCampo).FirstOrDefault(x => x.HasValue);
            var version = await GetVersionActualAsync(AdIaConfigEntidad.Diccionario, clave, existe: true) + 1;

            AddHistorial(
                AdIaConfigEntidad.Diccionario, clave, null, idCampo, version, AdIaConfigAccion.Eliminacion,
                DescribirConcepto(filas.Select(f => (f.Termino, f.Idioma)).ToList(), idCampo),
                null, usuario, DateTime.Now);

            _context.AdIaDiccionario.RemoveRange(filas);
            await _context.SaveChangesAsync();
        }

        public async Task<Dictionary<string, string>> GetMapaUnidadMedidaAsync()
        {
            var filas = await _context.AdIaDiccionario
                .AsNoTracking()
                .Where(d => d.Categoria == IaDiccionarioCategoria.UnidadMedida)
                .Select(d => new { d.Termino, d.Concepto })
                .ToListAsync();

            var mapa = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var fila in filas)
            {
                mapa[fila.Termino.Trim()] = fila.Concepto;
            }

            return mapa;
        }

        // ===== Historial =====

        public async Task<(List<IaHistorialDto> Data, int TotalRecords)> GetHistorialAsync(
            IaHistorialFiltro? filtro,
            int page,
            int size)
        {
            if (page < 1) page = 1;
            if (size < 1) size = 10;
            if (size > 100) size = 100;

            var query = _context.AdIaConfigHistorial.AsNoTracking().AsQueryable();

            var entidad = filtro?.Entidad?.Trim().ToUpperInvariant();
            if (entidad is AdIaConfigEntidad.PromptDocumento or AdIaConfigEntidad.PromptCampo or AdIaConfigEntidad.Diccionario)
            {
                query = query.Where(h => h.Entidad == entidad);
            }

            if (filtro?.IdTipoDocumentoVucem is > 0)
            {
                var idTipo = filtro.IdTipoDocumentoVucem.Value;
                query = query.Where(h => h.IdTipoDocumentoVucem == idTipo);
            }

            var total = await query.CountAsync();
            var data = await query
                .OrderByDescending(h => h.Fecha)
                .ThenByDescending(h => h.Id)
                .Skip((page - 1) * size)
                .Take(size)
                .Select(h => new IaHistorialDto
                {
                    Id = h.Id,
                    Entidad = h.Entidad,
                    Clave = h.Clave,
                    IdTipoDocumentoVucem = h.IdTipoDocumentoVucem,
                    IdCampo = h.IdCampo,
                    Version = h.Version,
                    Accion = h.Accion,
                    ValorAnterior = h.ValorAnterior,
                    ValorNuevo = h.ValorNuevo,
                    Usuario = h.Usuario,
                    Fecha = h.Fecha
                })
                .ToListAsync();

            return (data, total);
        }

        // ===== Utilidades =====

        private async Task<int> GetVersionActualAsync(string entidad, string clave, bool existe)
        {
            var maxima = await _context.AdIaConfigHistorial
                .Where(h => h.Entidad == entidad && h.Clave == clave)
                .MaxAsync(h => (int?)h.Version);

            // Lo que ya existía sin historial se considera versión 1
            return maxima ?? (existe ? 1 : 0);
        }

        private void AddHistorial(
            string entidad,
            string clave,
            long? idTipoDocumentoVucem,
            int? idCampo,
            int version,
            string accion,
            string? valorAnterior,
            string? valorNuevo,
            string usuario,
            DateTime fecha)
        {
            _context.AdIaConfigHistorial.Add(new AdIaConfigHistorial
            {
                Entidad = entidad,
                Clave = clave,
                IdTipoDocumentoVucem = idTipoDocumentoVucem,
                IdCampo = idCampo,
                Version = version,
                Accion = accion,
                ValorAnterior = valorAnterior,
                ValorNuevo = valorNuevo,
                Usuario = usuario,
                Fecha = fecha
            });
        }

        private static string ClaveDocumento(long idTipo) => idTipo.ToString();
        private static string ClaveCampo(long idTipo, int idCampo) => $"{idTipo}:{idCampo}";
        private static string ClaveDiccionario(string categoria, string concepto) => $"{categoria}|{concepto}";

        private static string SiNo(bool valor) => valor ? "Sí" : "No";

        private static string LimpiarTexto(string? texto)
        {
            return Regex.Replace(texto?.Trim() ?? string.Empty, @"\s+", " ");
        }

        /// <summary>
        /// Une los términos ES y EN: limpia, quita ';' y comillas, descarta vacíos y repetidos (ES tiene prioridad).
        /// </summary>
        private static List<(string Termino, string Idioma)> ConstruirTerminos(
            IEnumerable<string>? es,
            IEnumerable<string>? en)
        {
            var resultado = new List<(string Termino, string Idioma)>();
            var vistos = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            void Agregar(IEnumerable<string>? origen, string idioma)
            {
                foreach (var crudo in origen ?? Enumerable.Empty<string>())
                {
                    var limpio = LimpiarTexto(crudo.Replace(";", " ").Replace("\"", "'"));
                    if (limpio.Length == 0 || !vistos.Add(limpio))
                    {
                        continue;
                    }
                    if (limpio.Length > MaxTermino)
                    {
                        throw new InvalidOperationException($"Un término no puede exceder {MaxTermino} caracteres");
                    }
                    resultado.Add((limpio, idioma));
                }
            }

            Agregar(es, "ES");
            Agregar(en, "EN");
            return resultado;
        }

        private static string DescribirConcepto(IReadOnlyCollection<(string Termino, string Idioma)> terminos, int? idCampo)
        {
            var es = string.Join("; ", terminos.Where(t => t.Idioma == "ES").Select(t => t.Termino));
            var en = string.Join("; ", terminos.Where(t => t.Idioma == "EN").Select(t => t.Termino));
            var campo = idCampo.HasValue
                ? $"[Campo: {Enum.GetName(typeof(AdCampos), idCampo.Value) ?? idCampo.Value.ToString()}] "
                : string.Empty;
            return $"{campo}ES: {es} | EN: {en}";
        }

        private static IaDiccionarioConceptoDto ConstruirDto(
            string categoria,
            string concepto,
            int? idCampo,
            IReadOnlyCollection<(string Termino, string Idioma)> terminos)
        {
            return new IaDiccionarioConceptoDto
            {
                Categoria = categoria,
                Concepto = concepto,
                IdCampo = idCampo,
                TerminosEs = terminos.Where(t => t.Idioma == "ES").Select(t => t.Termino).ToList(),
                TerminosEn = terminos.Where(t => t.Idioma == "EN").Select(t => t.Termino).ToList()
            };
        }
    }
}
