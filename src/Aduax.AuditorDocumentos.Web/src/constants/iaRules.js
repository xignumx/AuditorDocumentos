import { AdCampos } from "./adCampos";

/** Campos que la IA puede extraer y que admiten prompt propio (los campos 1-3 no se leen con IA). */
export const iaCampoOptions = Object.freeze([
  { value: AdCampos.TipoOperacion, label: "Tipo de operación" },
  { value: AdCampos.ClavePedimento, label: "Clave de pedimento" },
  { value: AdCampos.Proveedor, label: "Proveedor" },
  { value: AdCampos.ProductoNoDeParte, label: "Producto / No. de parte" },
  { value: AdCampos.DescripcionMercancia, label: "Descripción de mercancía" },
  { value: AdCampos.Fracciones, label: "Fracciones" },
  { value: AdCampos.Nico, label: "Nico" },
  { value: AdCampos.Cantidad, label: "Cantidad" },
  { value: AdCampos.UnidadMedidaUMT, label: "Unidad de medida (UMT)" },
  { value: AdCampos.PaisOrigenDestino, label: "País origen/destino" },
  { value: AdCampos.VigenciaDesde, label: "Vigencia desde" },
  { value: AdCampos.VigenciaHasta, label: "Vigencia hasta" },
  { value: AdCampos.Aduana, label: "Aduana" },
  { value: AdCampos.FirmaDeRL, label: "Firma de Representante Legal" },
  { value: AdCampos.Nom, label: "Nom" },
  { value: AdCampos.ValorComercial, label: "Valor comercial" },
  { value: AdCampos.Factura, label: "Factura" },
  { value: AdCampos.FechaFactura, label: "Fecha factura" },
  { value: AdCampos.ValorUsd, label: "Valor USD" },
  { value: AdCampos.GuiaBl, label: "Guía/BL" },
  { value: AdCampos.Pedimento, label: "Pedimento" },
]);

export const getIaCampoLabel = (idCampo) =>
  iaCampoOptions.find((option) => option.value === Number(idCampo))?.label ??
  `Campo ${idCampo}`;

export const IaDiccionarioCategoria = Object.freeze({
  General: "GENERAL",
  UnidadMedida: "UM",
});

export const IaPromptTipo = Object.freeze({
  Documento: "DOCUMENTO",
  Campo: "CAMPO",
});

export const iaHistorialEntidadOptions = Object.freeze([
  { value: "", label: "Todos los cambios" },
  { value: "PROMPT_DOC", label: "Prompt del documento" },
  { value: "PROMPT_CAMPO", label: "Prompt de campo" },
  { value: "DICCIONARIO", label: "Diccionario y UM" },
]);
