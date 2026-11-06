using Aduax.AuditorDocumentos.Api.Data.EDOCS;
using Microsoft.EntityFrameworkCore;

namespace Aduax.AuditorDocumentos.Api.Data
{
    public class EDOCS_DBContext : DbContext
    {
        public EDOCS_DBContext(DbContextOptions<EDOCS_DBContext> options) : base(options)
        {
            // no hace nada
        }

        public DbSet<TbDocumentosVucem> TbDocumentosVucem { get; set; }
        public DbSet<CspVuceSellosRfcResult> CspVuceSellosRfcResult { get; set; }
        public DbSet<CspVuceSellosAgenteResult> CspVuceSellosAgenteResult { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<CspVuceSellosRfcResult>().HasNoKey();
            modelBuilder.Entity<CspVuceSellosAgenteResult>().HasNoKey();
        }
    }
}
