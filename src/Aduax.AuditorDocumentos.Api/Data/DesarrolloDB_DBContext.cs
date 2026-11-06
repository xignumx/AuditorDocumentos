using Microsoft.EntityFrameworkCore;
using Aduax.AuditorDocumentos.Api.Data.DesarrolloDB;

namespace Aduax.AuditorDocumentos.Api.Data
{
    public class DesarrolloDB_DBContext : DbContext
    {
        public DesarrolloDB_DBContext(DbContextOptions<DesarrolloDB_DBContext> options) : base(options)
        {
            // no hace nada
        }

        public DbSet<AdMotorConfigHeader> AdMotorConfigHeaders { get; set; }
        public DbSet<AdMotorConfigDetalle> AdMotorConfigDetalles { get; set; }
        public DbSet<AdDocumentos> AdDocumentos { get; set; }
        public DbSet<AdDocumentosArchivos> AdDocumentosArchivos { get; set; }
        public DbSet<AdRelDocumentoEdoc> AdRelDocumentoEdoc { get; set; }
        public DbSet<AdDocumentosCampos> AdDocumentosCampos { get; set; }
        public DbSet<AdAprobaciones> AdAprobaciones { get; set; }
        public DbSet<AdDocumentoOperacion> AdDocumentoOperacion { get; set; }
        public DbSet<AdNotifConfig> AdNotifConfig { get; set; }
        public DbSet<AdNotifEnvios> AdNotifEnvios { get; set; }
        public DbSet<AdNotifTemplate> AdNotifTemplate { get; set; }
        public DbSet<AdConfiguracionIa> AdConfiguracionIa { get; set; }
        public DbSet<AdIaPromptCampo> AdIaPromptCampo { get; set; }
        public DbSet<AdIaPromptDocumento> AdIaPromptDocumento { get; set; }
        public DbSet<AdIaEjecucion> AdIaEjecucion { get; set; }
        public DbSet<AdCatEventos> AdCatEventos { get; set; }
        public DbSet<AdBitacoraEventos> AdBitacoraEventos { get; set; }
        public DbSet<AdDocumentosIdentificadorGeneral> AdDocumentosIdentificadorGeneral { get; set; }
        public DbSet<AdDocumentosIdentificadorPartida> AdDocumentosIdentificadorPartida { get; set; }
        public DbSet<AdDocumentosPermiso> AdDocumentosPermiso { get; set; }

        // Entidad para resultado de SP csp_Ad_DocumentosPorEstatus
        public DbSet<CspAdDocumentosPorEstatus> CspAdDocumentosPorEstatus { get; set; }

        // Entidad para resultado de SP csp_Ad_ObtieneDocumentosPorVencer
        public DbSet<CspAdDocumentosPorVencer> CspAdDocumentosPorVencer { get; set; }

        // Entidad para resultado de SP ad_proveedores_listar_paginado
        public DbSet<CspAdProveedoresListarPaginado> CspAdProveedoresListarPaginado { get; set; }

        // Entidad para resultado de SP csp_AD_GetTraficoPorReferencia
        public DbSet<CspAdGetTraficoPorReferencia> CspAdGetTraficoPorReferencia { get; set; }

        // Entidad para resultado de SP csp_Ad_GetDocumentoOperacion
        public DbSet<CspAdGetDocumentoOperacion> CspAdGetDocumentoOperacion { get; set; }

        public DbSet<CspAdGetPatenteRfcClienteRow> CspAdGetPatenteRfcClienteRow { get; set; }

        public DbSet<CspAdGetFechaPagoBancoRow> CspAdGetFechaPagoBancoRow { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            // Configurar entidades con triggers para no usar OUTPUT clause
            // Esto evita el error: "The target table cannot have any enabled triggers if the statement contains an OUTPUT clause without INTO clause"
            modelBuilder.Entity<AdMotorConfigHeader>()
                .ToTable(tb => tb.UseSqlOutputClause(false));
            
            modelBuilder.Entity<AdMotorConfigDetalle>()
                .ToTable(tb => tb.UseSqlOutputClause(false));

            // Índice único filtrado: solo 1 configuración activa por (IdCliente, IdTipoDocumentoVucem)
            modelBuilder.Entity<AdMotorConfigHeader>()
                .HasIndex(e => new { e.IdCliente, e.IdTipoDocumentoVucem })
                .HasDatabaseName("UX_ad_motor_config_header_UnaActiva")
                .IsUnique()
                .HasFilter("[Activo] = 1");

            // Relación: AdMotorConfigDetalle -> AdMotorConfigHeader
            modelBuilder.Entity<AdMotorConfigDetalle>()
                .HasOne(d => d.MotorConfigHeader)
                .WithMany(h => h.Detalles)
                .HasForeignKey(d => d.IdMotorConfigHeader)
                .HasConstraintName("FK_ad_motor_config_detalle_header")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentos -> AdMotorConfigHeader
            modelBuilder.Entity<AdDocumentos>()
                .HasOne(d => d.MotorConfigHeader)
                .WithMany()
                .HasForeignKey(d => d.IdMotorConfigHeader)
                .HasConstraintName("FK_ad_documentos_motor_header")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentosArchivos -> AdDocumentos (1 a 1)
            modelBuilder.Entity<AdDocumentosArchivos>()
                .HasOne(d => d.Documento)
                .WithOne(d => d.Archivo)
                .HasForeignKey<AdDocumentosArchivos>(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documentos_archivos_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdRelDocumentoEdoc -> AdDocumentos (sin navegación inversa para no acoplar el agregado)
            modelBuilder.Entity<AdRelDocumentoEdoc>()
                .HasOne(d => d.Documento)
                .WithMany()
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_rel_documento_edoc_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentosCampos -> AdDocumentos
            modelBuilder.Entity<AdDocumentosCampos>()
                .HasOne(d => d.Documento)
                .WithMany(d => d.Campos)
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documentos_campos_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdAprobaciones -> AdDocumentos (1 a 1)
            modelBuilder.Entity<AdAprobaciones>()
                .HasOne(d => d.Documento)
                .WithOne()
                .HasForeignKey<AdAprobaciones>(d => d.IdDocumento)
                .HasConstraintName("FK_ad_aprobaciones_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentoOperacion -> AdDocumentos (1 a muchos)
            modelBuilder.Entity<AdDocumentoOperacion>()
                .HasOne(d => d.Documento)
                .WithMany(d => d.Operaciones)
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documento_operacion_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentosIdentificadorGeneral -> AdDocumentos (1 a 1)
            modelBuilder.Entity<AdDocumentosIdentificadorGeneral>()
                .HasOne(d => d.Documento)
                .WithOne(d => d.IdentificadorGeneral)
                .HasForeignKey<AdDocumentosIdentificadorGeneral>(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documentos_identificador_general_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentosIdentificadorPartida -> AdDocumentos (1 a 1)
            modelBuilder.Entity<AdDocumentosIdentificadorPartida>()
                .HasOne(d => d.Documento)
                .WithOne(d => d.IdentificadorPartida)
                .HasForeignKey<AdDocumentosIdentificadorPartida>(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documentos_identificador_partida_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdDocumentosPermiso -> AdDocumentos (1 a 1)
            modelBuilder.Entity<AdDocumentosPermiso>()
                .HasOne(d => d.Documento)
                .WithOne(d => d.Permiso)
                .HasForeignKey<AdDocumentosPermiso>(d => d.IdDocumento)
                .HasConstraintName("FK_ad_documentos_permiso_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdNotifConfig -> AdMotorConfigHeader (1 a 1)
            modelBuilder.Entity<AdNotifConfig>()
                .HasOne(d => d.MotorConfigHeader)
                .WithOne()
                .HasForeignKey<AdNotifConfig>(d => d.IdMotorConfigHeader)
                .HasConstraintName("FK_ad_notif_config_motor_header")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdNotifEnvios -> AdDocumentos
            modelBuilder.Entity<AdNotifEnvios>()
                .HasOne(d => d.Documento)
                .WithMany()
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_notif_envios_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdIaEjecucion -> AdDocumentos
            modelBuilder.Entity<AdIaEjecucion>()
                .HasOne(d => d.Documento)
                .WithMany()
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_ia_ejecucion_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Relación: AdBitacoraEventos -> AdDocumentos
            modelBuilder.Entity<AdBitacoraEventos>()
                .HasOne(d => d.Documento)
                .WithMany()
                .HasForeignKey(d => d.IdDocumento)
                .HasConstraintName("FK_ad_bitacora_eventos_documentos")
                .OnDelete(DeleteBehavior.Restrict);

            // Índice único filtrado: solo 1 plantilla activa global
            modelBuilder.Entity<AdNotifTemplate>()
                .HasIndex(e => e.Activo)
                .HasDatabaseName("UX_ad_notif_template_SoloUnoActivo")
                .IsUnique()
                .HasFilter("[Activo] = 1");

            // CHECK constraint: Version >= 1
            modelBuilder.Entity<AdNotifTemplate>()
                .HasCheckConstraint("CK_ad_notif_template_Version", "[Version] >= 1");

            // Configuración de entidad para SP csp_Ad_DocumentosPorEstatus (usa Id como llave)
            modelBuilder.Entity<CspAdDocumentosPorEstatus>();

            // Configuración de entidad para SP csp_Ad_ObtieneDocumentosPorVencer (usa Id como llave)
            modelBuilder.Entity<CspAdDocumentosPorVencer>();

            // Configuración de entidad para SP ad_proveedores_listar_paginado (usa IdProveedor como llave)
            modelBuilder.Entity<CspAdProveedoresListarPaginado>()
                .HasNoKey();

            // Configuración de entidad para SP csp_AD_GetTraficoPorReferencia
            modelBuilder.Entity<CspAdGetTraficoPorReferencia>()
                .HasNoKey();

            // Configuración de entidad para SP csp_Ad_GetDocumentoOperacion
            modelBuilder.Entity<CspAdGetDocumentoOperacion>()
                .HasNoKey();

            modelBuilder.Entity<CspAdGetPatenteRfcClienteRow>()
                .HasNoKey();

            modelBuilder.Entity<CspAdGetFechaPagoBancoRow>()
                .HasNoKey();
        }
    }
}
