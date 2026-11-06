# Tiempos — ramas pedimento vs tráfico (antes de cambiar el SP)

**Caso:** cliente `9174`, documento `35081`  
**Fecha:** 2026-10-13  
**SP no modificado.**

## Volúmenes (cliente 9174)

| Universo | Filas | ms |
|----------|------:|---:|
| Tráficos del cliente | 118 937 | 15 |
| Tráficos **sin** pedimento (filtro anterior) | 3 261 | 175 |
| Pedimentos abiertos | 466 | 1 |

Tras la separación, la rama tráfico pasa de evaluar ~3 k a ~119 k filas base.

## Ramas aisladas (EXISTS partida: proveedor + producto + país; búsqueda vacía)

| Paso | ms | Filas | Nota |
|------|---:|------:|------|
| Rama **pedimento** + EXISTS partida | 211 | 1 | |
| Rama **tráfico actual** (con pedimento) | **751** | 31 | sin `NOT EXISTS` pedimento |
| Rama **tráfico anterior** (solo sin ped) | 33 | 0 | con `NOT EXISTS` pedimento |
| Materializar `#TrafCliente` | 247 | 118 937 | candidata |
| `#TrafCliente` + EXISTS partida | 534 | 31 | no mejora vs 751 |
| Tráfico igualdad `id_trafico` | 1 | 1 | con búsqueda |
| **EXEC SP** `operacionBusqueda='RA48356812'` | **108** | 1 | SP completo |

## EXEC SP filtro vacío

| Intento | Timeout | Resultado |
|---------|---------|-----------|
| Previo | 1800 s | Timeout expired |
| Reintento | 300 s | Timeout expired |

El SP completo con búsqueda vacía **sigue sin terminar** en estos timeouts, aunque las ramas aisladas con solo 3 EXISTS de partida tardan &lt; 1 s.

## Lectura

1. El costo de negocio de la separación se ve en volumen (~36× más tráficos) y en la rama tráfico actual (~751 ms / 31 filas vs 33 ms / 0 del filtro anterior) con los EXISTS de partida.
2. Prefiltrar `#TrafCliente` **no** baja el tiempo de forma útil en este caso.
3. Con `@operacionBusqueda` puntual el SP ya es aceptable (~108–419 ms).
4. El timeout del SP en vacío apunta a costo del **SP completo** (más EXISTS, ambas ramas, materialización `#Candidatos`, etc.), no solo al conteo de “tráficos sin pedimento”.

## Archivos

- `02 tiempos ramas pedimento trafico.sql` / `02 tiempos salida.txt`
- `02b sp vacio reintento.txt`
