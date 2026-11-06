export const AdAccionPedimento = Object.freeze({
  AfectaOperacion: "S",
  NoAfectaOperacion: "N",
  PreguntaSiAfecta: "P",
});

export const adAccionPedimentoOptions = [
  { value: AdAccionPedimento.AfectaOperacion, label: "Afecta operación" },
  { value: AdAccionPedimento.NoAfectaOperacion, label: "No afecta operación" },
  { value: AdAccionPedimento.PreguntaSiAfecta, label: "Pregunta si afecta operación" },
];
