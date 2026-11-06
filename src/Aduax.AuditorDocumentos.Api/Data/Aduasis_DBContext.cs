using Microsoft.EntityFrameworkCore;
using Aduax.AuditorDocumentos.Api.Data.Aduasis;

namespace Aduax.AuditorDocumentos.Api.Data
{
    public class Aduasis_DBContext : DbContext
    {
        public Aduasis_DBContext(DbContextOptions<Aduasis_DBContext> options) : base(options)
        {
            // no hace nada
        }

        public DbSet<FCliente> FCliente { get; set; }
        public DbSet<FAduana> FAduana { get; set; }
        public DbSet<FRegimen> FRegimen { get; set; }
        public DbSet<FUsuario> FUsuario { get; set; }

        // Entidad para resultado de SP csp_Ad_SugerenciaPedimentos
        public DbSet<CspAdSugerenciaPedimentos> CspAdSugerenciaPedimentos { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Configuraciones específicas del contexto Aduasis_DBContext pueden ir aquí

            modelBuilder.Entity<FAduana>(entity =>
            {
                entity.HasKey(e => new { e.IdAduana, e.SeccionAduana });
            });

            // Configuración de entidad para SP csp_Ad_SugerenciaPedimentos
            modelBuilder.Entity<CspAdSugerenciaPedimentos>(entity =>
            {
                entity.HasKey(e => new { e.IdReferencia, e.Pedimento });
            });
        }
    }
}
