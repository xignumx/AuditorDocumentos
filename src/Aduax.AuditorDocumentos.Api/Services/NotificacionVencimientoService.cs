using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace Aduax.AuditorDocumentos.Api.Services
{
    public class NotificacionVencimientoService : BackgroundService
    {
        private readonly ILogger<NotificacionVencimientoService> _logger;
        private readonly IServiceProvider _serviceProvider;

        public NotificacionVencimientoService(
            ILogger<NotificacionVencimientoService> logger,
            IServiceProvider serviceProvider)
        {
            _logger = logger;
            _serviceProvider = serviceProvider;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Servicio de notificaciones de vencimiento iniciado.");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    var now = DateTime.Now;
                    var nextRun = now.Date.AddDays(1).AddHours(3);
                    var today3AM = now.Date.AddHours(3);
                    if (now < today3AM)
                    {
                        nextRun = today3AM;
                    }

                    var delay = nextRun - now;
                    _logger.LogInformation("Próxima ejecución programada para: {NextRun:yyyy-MM-dd HH:mm:ss} (en {DelayHoras:F2} horas)", nextRun, delay.TotalHours);

                    await Task.Delay(delay, stoppingToken);

                    if (!stoppingToken.IsCancellationRequested)
                    {
                        await ProcesarNotificacionesAsync(stoppingToken);
                    }
                }
                catch (OperationCanceledException)
                {
                    _logger.LogInformation("Servicio de notificaciones de vencimiento cancelado.");
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error en el servicio de notificaciones de vencimiento. Reintentando en 1 hora.");
                    await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
                }
            }
        }

        private async Task ProcesarNotificacionesAsync(CancellationToken stoppingToken)
        {
            using var scope = _serviceProvider.CreateScope();
            var processor = scope.ServiceProvider.GetRequiredService<INotificacionVencimientoProcessor>();

            try
            {
                var resultado = await processor.ProcesarAsync(stoppingToken);
                _logger.LogInformation(
                    "Resumen: Total procesados {Procesados}, enviados {Enviados}, fallidos {Fallidos}",
                    resultado.TotalProcesados,
                    resultado.TotalEnviados,
                    resultado.TotalFallidos);

                if (resultado.Advertencias.Any())
                {
                    foreach (var advertencia in resultado.Advertencias)
                    {
                        _logger.LogWarning(advertencia);
                    }
                }
            }
            catch (OperationCanceledException)
            {
                _logger.LogInformation("Procesamiento cancelado por token.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error general en el procesamiento de notificaciones.");
                throw;
            }
        }
    }
}
