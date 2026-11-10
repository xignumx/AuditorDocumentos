using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;
using Microsoft.OpenApi.Models;
using Aduax.AuditorDocumentos.Api.Auth;
using Aduax.AuditorDocumentos.Api.Configuration;
using Aduax.AuditorDocumentos.Api.Data;
using Aduax.AuditorDocumentos.Api.Services;
using Aduax.AuditorDocumentos.Api.Services.Aduasis;
using Aduax.AuditorDocumentos.Api.Services.DesarrolloDb;
using Aduax.AuditorDocumentos.Api.Services.EDOCS;
using Aduax.AuditorDocumentos.Api.Services.FileStorage;
using Aduax.AuditorDocumentos.Api.Services.IaReglas;
using Aduax.AuditorDocumentos.Api.Services.MotorConfigMasiva;
using Aduax.AuditorDocumentos.Api.Services.Vucem;

var builder = WebApplication.CreateBuilder(args);

// Configurar CORS para permitir peticiones del frontend
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        policy.WithOrigins(
                "http://localhost:5173",    // Vite dev server
                "http://localhost:5174",    // Vite dev server
                "http://localhost:3000",    // Alternativa común
                "http://localhost:5000",    // Otra alternativa
                "http://localhost",         // Producción local
                "https://localhost"         // Producción local
            )
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials();
    });
});

// Add services to the container.
builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();

// Configurar autenticación (requerido para UseAuthorization)
builder.Services.AddAuthentication("Bearer")
    .AddScheme<Microsoft.AspNetCore.Authentication.AuthenticationSchemeOptions, Aduax.AuditorDocumentos.Api.Auth.TokenAuthenticationHandler>("Bearer", options => { });

builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Aduax Auditor Documentos API",
        Version = "v1"
    });

    // Configurar autenticación Bearer Token
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "Ingrese el token en el formato: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.ApiKey,
        Scheme = "Bearer"
    });

    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "Bearer"
                }
            },
            Array.Empty<string>()
        }
    });
});

// Configuraciones
builder.Services.Configure<AppSettings>(builder.Configuration.GetSection("AppSettings"));
builder.Services.Configure<MailClient>(builder.Configuration.GetSection("MailClient"));
builder.Services.Configure<FileStorageCfg>(builder.Configuration.GetSection("FileStorageCfg"));
builder.Services.Configure<VucemApiCfg>(builder.Configuration.GetSection("VucemApi"));

// Contextos de Base de Datos
builder.Services.AddDbContext<DesarrolloDB_DBContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DesarrolloDB"))
    );

builder.Services.AddDbContext<Aduasis_DBContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("Aduasis"))
    );

builder.Services.AddDbContext<EDOCS_DBContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("EDOCS"))
    );

// Servicios
builder.Services.AddScoped<IDesarrolloDb_DbContextServices, DesarrolloDb_DbContextServices>();
builder.Services.AddScoped<IAduasisDbContextServices, AduasisDbContextServices>();
builder.Services.AddScoped<IEDOCS_DbContextServices, EDOCS_DbContextServices>();
builder.Services.AddScoped<IConfigAutorizacionService, ConfigAutorizacionService>();
builder.Services.AddScoped<IIaReglasDbContextServices, IaReglasDbContextServices>();
builder.Services.AddScoped<IIaReglasService, IaReglasService>();
builder.Services.AddScoped<IMotorConfigMasivaService, MotorConfigMasivaService>();
builder.Services.AddScoped<SendMailServices>();
builder.Services.AddScoped<INotificacionVencimientoProcessor, NotificacionVencimientoProcessor>();

// FileStorageService con HttpClient
builder.Services.AddHttpClient<IFileStorageService, FileStorageService>();

builder.Services.AddRequestTimeouts(options =>
{
    options.AddPolicy("VucemEnvio", TimeSpan.FromMinutes(10));
});

builder.Services.AddHttpClient<IVucemApiClient, VucemApiClient>((sp, client) =>
{
    var config = sp.GetRequiredService<IOptions<VucemApiCfg>>().Value;
    if (!string.IsNullOrWhiteSpace(config.BaseUrl))
    {
        client.BaseAddress = new Uri(config.BaseUrl.TrimEnd('/') + "/");
    }
})
.ConfigurePrimaryHttpMessageHandler(() => new SocketsHttpHandler
{
    PooledConnectionLifetime = TimeSpan.FromMinutes(5),
    ConnectTimeout = TimeSpan.FromSeconds(30),
});

// Background Services
builder.Services.AddHostedService<NotificacionVencimientoService>();

var app = builder.Build();

app.UseCors("AllowFrontend");

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseRequestTimeouts();

app.UseAuthentication();
app.UseAuthorization();

// Middleware de autenticación personalizado (debe ir después de UseAuthorization para validar endpoints con [Authorize])
app.UseMiddleware<TokenAuthenticationMiddleware>();

app.MapControllers();

app.Run();
