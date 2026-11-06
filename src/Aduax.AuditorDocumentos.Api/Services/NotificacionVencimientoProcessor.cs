using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Logging;
using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.VModels;

namespace Aduax.AuditorDocumentos.Api.Services
{
    public interface INotificacionVencimientoProcessor
    {
        Task<NotificacionProcesoResultado> ProcesarAsync(CancellationToken cancellationToken = default);
    }

    public class NotificacionProcesoResultado
    {
        public int TotalProcesados { get; set; }
        public int TotalEnviados { get; set; }
        public int TotalFallidos { get; set; }
        public List<string> Advertencias { get; } = new();
    }

    public class NotificacionVencimientoProcessor : INotificacionVencimientoProcessor
    {
        private readonly ILogger<NotificacionVencimientoProcessor> _logger;
        private readonly IDesarrolloDb_DbContextServices _desarrolloDbService;
        private readonly IAduasisDbContextServices _aduasisDbContextServices;
        private readonly SendMailServices _sendMailService;

        public NotificacionVencimientoProcessor(
            ILogger<NotificacionVencimientoProcessor> logger,
            IDesarrolloDb_DbContextServices desarrolloDbService,
            IAduasisDbContextServices aduasisDbContextServices,
            SendMailServices sendMailService)
        {
            _logger = logger;
            _desarrolloDbService = desarrolloDbService;
            _aduasisDbContextServices = aduasisDbContextServices;
            _sendMailService = sendMailService;
        }

        public async Task<NotificacionProcesoResultado> ProcesarAsync(CancellationToken cancellationToken = default)
        {
            var resultado = new NotificacionProcesoResultado();
            _logger.LogInformation("Iniciando procesamiento de notificaciones de vencimiento.");

            var notifConfigs = await _desarrolloDbService.GetAllNotifConfigAsync();
            if (!notifConfigs.Any())
            {
                const string mensaje = "No se encontraron configuraciones de notificaci�n.";
                _logger.LogInformation(mensaje);
                resultado.Advertencias.Add(mensaje);
                return resultado;
            }

            var template = await _desarrolloDbService.GetNotifTemplateActivaAsync();
            if (template == null)
            {
                const string mensaje = "No se encontr� una plantilla activa para notificaciones.";
                _logger.LogWarning(mensaje);
                resultado.Advertencias.Add(mensaje);
                return resultado;
            }

            foreach (var notifConfig in notifConfigs)
            {
                cancellationToken.ThrowIfCancellationRequested();

                if (notifConfig.MotorConfigHeader == null)
                {
                    string advertencia = $"AdNotifConfig Id {notifConfig.Id} no tiene MotorConfigHeader asociado. Se omite.";
                    _logger.LogWarning(advertencia);
                    resultado.Advertencias.Add(advertencia);
                    continue;
                }

                string idCliente = notifConfig.MotorConfigHeader.IdCliente;
                int idMotorConfigHeader = (int)notifConfig.IdMotorConfigHeader;

                string[] diasVencimiento = notifConfig.DiasAntesVencimiento
                    .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

                foreach (string diaStr in diasVencimiento)
                {
                    cancellationToken.ThrowIfCancellationRequested();

                    if (!int.TryParse(diaStr, out int diasVencimientoInt) || diasVencimientoInt <= 0)
                    {
                        string advertencia = $"D�a de vencimiento inv�lido en AdNotifConfig Id {notifConfig.Id}: {diaStr}";
                        _logger.LogWarning(advertencia);
                        resultado.Advertencias.Add(advertencia);
                        continue;
                    }

                    var documentos = await _desarrolloDbService.GetDocumentosPorVencerAsync(
                        idCliente,
                        idMotorConfigHeader,
                        diasVencimientoInt);

                    foreach (var documento in documentos)
                    {
                        cancellationToken.ThrowIfCancellationRequested();
                        resultado.TotalProcesados++;

                        try
                        {
                            var cliente = await _aduasisDbContextServices.GetClienteAsync(idCliente);
                            var usuario = await _aduasisDbContextServices.GetUsuarioPorUsuauarioAsync(documento.CreadoPor);
                            string htmlBody = template.Html
                                .Replace("[CLIENTE]", cliente.IdCliente + " " + cliente.RazonSocial)
                                .Replace("[DOCUMENTO]", documento.Documento + ": " + documento.NombreArchivo)
                                .Replace("[VENCIMIENTO]", documento.FechaVigenciaFin?.ToString("dd/MM/yyyy") ?? string.Empty)
                                .Replace("[DIAS_VENCIMIENTO]", (documento.FechaVigenciaFin - DateTime.Today)?.Days.ToString() ?? string.Empty)
                                .Replace("[URL_DOCUMENTO]", documento.AwsRuta)
                                .Replace("[URL_PLATAFORMA]", "https://web.aduax.com/portalunicoapp");

                            string subject = $"Alerta de vencimiento: {documento.Documento} de {cliente.IdCliente} {cliente.RazonSocial}";
                            string correos = notifConfig.Correos;
                            if (usuario != null)
                                correos += ";" + usuario.CorreoElectronico;

                            await _sendMailService.EnviarCorreoAsync(
                                correos,
                                subject,
                                htmlBody);

                            await _desarrolloDbService.SaveNotifEnvioAsync(
                                documento.Id,
                                correos,
                                diasVencimientoInt,
                                AdNotifResultado.Enviado,
                                null,
                                "Sistema");

                            resultado.TotalEnviados++;
                            _logger.LogInformation("Correo enviado exitosamente para documento Id {DocumentoId}", documento.Id);
                        }
                        catch (Exception ex)
                        {
                            resultado.TotalFallidos++;
                            string errorMessage = $"Error al enviar correo para documento Id {documento.Id}: {ex.Message}";
                            _logger.LogError(ex, errorMessage);

                            try
                            {
                                await _desarrolloDbService.SaveNotifEnvioAsync(
                                    documento.Id,
                                    notifConfig.Correos,
                                    diasVencimientoInt,
                                    AdNotifResultado.Fallido,
                                    errorMessage.Length > 500 ? errorMessage[..500] : errorMessage,
                                    "Sistema");
                            }
                            catch (Exception saveEx)
                            {
                                _logger.LogError(saveEx, "Error al guardar registro de env�o fallido para documento Id {DocumentoId}", documento.Id);
                                resultado.Advertencias.Add($"No se pudo registrar el fallo del documento {documento.Id}: {saveEx.Message}");
                            }
                        }
                    }
                }
            }

            _logger.LogInformation(
                "Procesamiento completado. Total procesados: {TotalProcesados}, Enviados: {TotalEnviados}, Fallidos: {TotalFallidos}",
                resultado.TotalProcesados,
                resultado.TotalEnviados,
                resultado.TotalFallidos);

            return resultado;
        }
    }
}
