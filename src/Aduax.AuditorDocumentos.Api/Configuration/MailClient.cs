namespace Aduax.AuditorDocumentos.Api.Configuration
{
    public class MailClient
    {
        public string From { get; set; } = default!;
        public string Smtp { get; set; } = default!;
        public string User { get; set; } = default!;

        public bool EnvioDirecto { get; set; } = false;

        public string SmtpServer { get; set; } = default!;
        public string SmtpAccount { get; set; } = default!;
        public string SmtpUser { get; set; } = default!;
        public string SmtpPassword { get; set; } = default!;
        public string SmtpPort { get; set; } = default!;
        public string SmtpFrom { get; set; } = default!;

    }
}
