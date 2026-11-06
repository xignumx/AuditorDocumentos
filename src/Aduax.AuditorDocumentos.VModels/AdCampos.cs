using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Aduax.AuditorDocumentos.VModels
{
    public enum AdCampos : int
    {
        // ===== Atributos configurables (Motor Normativo) =====
        IdCliente = 1,
        RfcCliente = 2,
        TipoPedimento = 3,
        TipoOperacion = 4,
        ClavePedimento = 5,
        Proveedor = 6,
        ProductoNoDeParte = 7,
        DescripcionMercancia = 8,
        Fracciones = 9,
        Nico = 10,
        Cantidad = 11,
        UnidadMedidaUMT = 12,
        PaisOrigenDestino = 13,
        VigenciaDesde = 14,
        VigenciaHasta = 15,
        Aduana = 16,
        FirmaDeRL = 17,
        Nom = 18,
        ValorComercial = 19,
        Factura = 20,
        FechaFactura = 21,
        ValorUsd = 22,
        GuiaBl = 23,
        Pedimento = 24,

        // ===== Lectura IA (validación/extracción) =====
        CadenaOriginal = 100,
        CodigoQR = 101
    }
}
