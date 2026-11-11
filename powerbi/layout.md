# Dashboard de ventas: layout de una página

Lienzo personalizado de **1280 × 860 px** (*Diseño > Tamaño de la página > Personalizado*). Posiciones en *Formato > General > Propiedades* (X, Y, ancho, alto).

## Orden de armado
1. Obtener datos > Base de datos MySQL > `vw_ventas` (Importar; este conector solo funciona en ese modo). Requiere MySQL Connector/NET 8.0.x de 64 bits. Si la tabla aparece con un nombre largo, renombrarla a `vw_ventas`. Tipo de `fecha`: Fecha.
2. Pegar la tabla `Calendario` de `medidas.dax`, marcarla como tabla de fechas y crear la relación `Calendario[Date]` (1) → `vw_ventas[fecha]` (*), filtro en una sola dirección.
3. Pegar las medidas de `medidas.dax`.
4. *Diseño > Importar tema* > `tema_ecommerce.json` (colores, fuentes, bordes redondeados, ejes, leyendas y títulos centrados).
5. Colocar las visuales según la tabla.

## Visuales

| Fila | Visual | Campos | X | Y | Ancho | Alto |
|---|---|---|---|---|---|---|
| Filtros | Segmentación (lista desplegable) | `Calendario[Año]` | 20 | 10 | 406 | 50 |
| Filtros | Segmentación (lista desplegable) | `vw_ventas[categoria]` | 436 | 10 | 406 | 50 |
| Filtros | Segmentación (lista desplegable) | `vw_ventas[ciudad]` | 852 | 10 | 406 | 50 |
| KPIs | Tarjeta | `Ventas` | 20 | 70 | 240 | 90 |
| KPIs | Tarjeta | `Órdenes` | 270 | 70 | 240 | 90 |
| KPIs | Tarjeta | `Ticket promedio` | 520 | 70 | 240 | 90 |
| KPIs | Tarjeta | `% Clientes que repiten` (2+ compras) | 770 | 70 | 240 | 90 |
| KPIs | Tarjeta | `Tasa de cancelación` | 1020 | 70 | 240 | 90 |
| 1 | Gráfico de líneas | Eje: `Calendario[Año-Mes]`; Valores: `Ventas`, `Ventas mes anterior` | 20 | 170 | 620 | 330 |
| 1 | Barras horizontales, filtro N superior = 10 por `Ventas` | Eje: `vw_ventas[producto]`; Valores: `Ventas` | 650 | 170 | 610 | 330 |
| 2 | Gráfico de anillos | Leyenda: `vw_ventas[categoria]`; Valores: `Ventas` | 20 | 510 | 400 | 340 |
| 2 | Barras horizontales | Eje: `vw_ventas[ciudad]`; Valores: `Ventas` | 430 | 510 | 420 | 340 |
| 2 | Barras horizontales | Eje: `vw_ventas[estado_orden]`; Valores: `Órdenes totales` | 860 | 510 | 400 | 340 |

## Ajustes manuales que el tema no cubre
- **Gráfico de líneas:** ordenar el eje por `Año-Mes` ascendente (⋯ > Ordenar eje), desactivar el suavizado de línea y apagar el subtítulo automático.
- **Top 10 productos:** en el panel Filtros, `producto` > N superior > 10 > por valor `Ventas`; ordenar el eje por `Ventas` descendente.
- **Anillo de categorías:** sin leyenda, con etiquetas "Categoría, porcentaje del total" fuera del anillo y 1 decimal.
- **Órdenes por estado:** usar `Órdenes totales` (la medida `Órdenes` excluye las canceladas) y barras en lugar de anillo, porque el 88,7 % en una sola porción vuelve ilegibles las demás.
- **Formato de números:** `Ventas` y `Ticket promedio` como moneda sin decimales; `Órdenes` y `Órdenes totales` como entero con separador de miles; `% Clientes que repiten` y `Tasa de cancelación` como porcentaje con 1 decimal.
- **Títulos:** "Ventas por mes vs. mes anterior", "Top 10 productos", "Ventas por categoría", "Ventas por ciudad", "Órdenes por estado".

## Cifras de control (datos con semilla 42)
Ventas $178.402.950 · Órdenes 1.399 · Ticket promedio $127.522 · % Clientes que repiten 65,1 % · Tasa de cancelación 6,7 %.
