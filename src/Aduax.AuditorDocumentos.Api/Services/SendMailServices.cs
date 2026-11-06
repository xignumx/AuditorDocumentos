using Google.Api;
using Microsoft.Extensions.Options;
using Aduax.AuditorDocumentos.Api.Configuration;
using Aduax.AuditorDocumentos.Api.Data;
using Shared.Utilerias.Correo;
using Shared.Utilerias.DTOs.Correo;

namespace Aduax.AuditorDocumentos.Api.Services
{
    public class SendMailServices
    {
        private readonly MailClient _mailClient;
        private readonly Aduasis_DBContext _context;

        public SendMailServices(IOptions<MailClient> mailClient, Aduasis_DBContext context)
        {
            _mailClient = mailClient.Value;
            _context = context;
        }

        public async Task EnviarCorreoAsync(string to, string subject, string bodyHtml)
        {
            if (!_mailClient.EnvioDirecto)
            {
                await _context.Database.ExecuteSqlRawAsync(
                    "EXEC sp_send_cdosysmail @FROM = {0}, @TO = {1}, @SUBJECT = {2}, @BODY = {3}, @SMTP = {4}, @USER = {5}",
                    _mailClient.From, to, subject, bodyHtml, _mailClient.Smtp, _mailClient.User);
            }
            else
            {
                try
                {
                    string para = to.Replace(",", ";");
                    List<string> result = para.Split(';').ToList();

                    Servidor serverConnect = new Servidor()
                    {
                        Server = _mailClient.SmtpServer,
                        Cuenta = _mailClient.SmtpAccount,
                        Password = _mailClient.SmtpPassword,
                        Puerto = int.Parse(_mailClient.SmtpPort),
                        Usuario = _mailClient.SmtpUser,
                        SSL = true
                    };

                    Mensaje message = new Mensaje()
                    {
                        Asunto = subject,
                        Body = bodyHtml,
                        Destinatario = result,
                        From = _mailClient.SmtpFrom,
                        ResponderA = "mxochipa@onecore.mx"
                    };

                    Servicio serviceEmail = new Servicio(serverConnect);
                    serviceEmail.Enviar(message);
                }
                catch (Exception ex)
                {
                    Console.WriteLine("Error al enviar correo: " + ex.Message);
                }
            }
        }
    }
}
