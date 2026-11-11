-- ============================================================
-- 03_queries.sql  |  Consultas analíticas (MySQL 8.0+)
-- Criterio común: las ventas excluyen órdenes 'Cancelado' y los
-- importes se calculan desde detalle_ordenes (no desde ordenes.total).
-- ============================================================
USE ecommerce_db;

-- ------------------------------------------------------------
-- 1. REPORTE DE VENTAS: detalle de las últimas 100 líneas de orden
--    (LEFT JOIN a categorías para no perder productos sin categoría)
-- ------------------------------------------------------------
SELECT
    o.orden_id,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    p.nombre AS producto,
    COALESCE(cat.nombre_categoria, 'Sin categoría') AS categoria,
    d.cantidad,
    d.precio_unitario,
    d.subtotal,
    o.estado_orden,
    o.fecha_orden
FROM ordenes o
JOIN clientes c ON c.cliente_id = o.cliente_id
JOIN detalle_ordenes d ON d.orden_id = o.orden_id
JOIN productos p ON p.producto_id = d.producto_id
LEFT JOIN categorias cat ON cat.categoria_id = p.categoria_id
ORDER BY o.fecha_orden DESC, o.orden_id DESC
LIMIT 100;

-- ------------------------------------------------------------
-- 2. ALERTAS DE STOCK: productos activos en o bajo el mínimo.
--    Sugerencia de compra: reponer hasta el doble del stock mínimo.
-- ------------------------------------------------------------
SELECT
    producto_id,
    nombre,
    stock_actual,
    stock_minimo,
    (stock_minimo * 2 - stock_actual) AS unidades_sugeridas_a_comprar
FROM productos
WHERE activo = TRUE
  AND stock_actual <= stock_minimo
ORDER BY (stock_actual - stock_minimo), nombre;

-- ------------------------------------------------------------
-- 3. RANKING DE CLIENTES por gasto (incluye clientes sin compras)
-- ------------------------------------------------------------
SELECT
    c.cliente_id,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.ciudad,
    COUNT(DISTINCT o.orden_id) AS total_ordenes,
    COALESCE(SUM(d.subtotal), 0) AS dinero_gastado
FROM clientes c
LEFT JOIN ordenes o
       ON o.cliente_id = c.cliente_id AND o.estado_orden <> 'Cancelado'
LEFT JOIN detalle_ordenes d ON d.orden_id = o.orden_id
GROUP BY c.cliente_id, c.nombre, c.apellido, c.ciudad
ORDER BY dinero_gastado DESC
LIMIT 20;

-- ------------------------------------------------------------
-- 4. PRODUCTOS MÁS VENDIDOS (unidades y recaudación)
-- ------------------------------------------------------------
SELECT
    p.producto_id,
    p.nombre,
    SUM(d.cantidad) AS total_unidades_vendidas,
    SUM(d.subtotal) AS recaudacion_total
FROM productos p
JOIN detalle_ordenes d ON d.producto_id = p.producto_id
JOIN ordenes o ON o.orden_id = d.orden_id AND o.estado_orden <> 'Cancelado'
GROUP BY p.producto_id, p.nombre
ORDER BY total_unidades_vendidas DESC
LIMIT 10;

-- ------------------------------------------------------------
-- 5. CTE + LAG: ventas mensuales, variación vs. mes anterior
--    y ventas acumuladas
-- ------------------------------------------------------------
WITH ventas_mensuales AS (
    SELECT
        DATE_FORMAT(o.fecha_orden, '%Y-%m') AS mes,
        SUM(d.subtotal) AS ventas
    FROM ordenes o
    JOIN detalle_ordenes d ON d.orden_id = o.orden_id
    WHERE o.estado_orden <> 'Cancelado'
    GROUP BY DATE_FORMAT(o.fecha_orden, '%Y-%m')
)
SELECT
    mes,
    ventas,
    LAG(ventas) OVER (ORDER BY mes) AS ventas_mes_anterior,
    ROUND(100 * (ventas - LAG(ventas) OVER (ORDER BY mes))
          / LAG(ventas) OVER (ORDER BY mes), 1) AS variacion_pct,
    SUM(ventas) OVER (ORDER BY mes) AS ventas_acumuladas
FROM ventas_mensuales
ORDER BY mes;

-- ------------------------------------------------------------
-- 6. KPI: ticket promedio y cantidad de órdenes por mes
-- ------------------------------------------------------------
SELECT
    DATE_FORMAT(o.fecha_orden, '%Y-%m') AS mes,
    COUNT(DISTINCT o.orden_id) AS ordenes,
    SUM(d.subtotal) AS ventas,
    ROUND(SUM(d.subtotal) / COUNT(DISTINCT o.orden_id), 2) AS ticket_promedio
FROM ordenes o
JOIN detalle_ordenes d ON d.orden_id = o.orden_id
WHERE o.estado_orden <> 'Cancelado'
GROUP BY DATE_FORMAT(o.fecha_orden, '%Y-%m')
ORDER BY mes;

-- ------------------------------------------------------------
-- 7. RANK(): top 3 productos por recaudación dentro de cada categoría
-- ------------------------------------------------------------
WITH recaudacion_producto AS (
    SELECT
        COALESCE(cat.nombre_categoria, 'Sin categoría') AS categoria,
        p.nombre AS producto,
        SUM(d.subtotal) AS recaudacion,
        RANK() OVER (PARTITION BY p.categoria_id ORDER BY SUM(d.subtotal) DESC) AS ranking
    FROM detalle_ordenes d
    JOIN ordenes o ON o.orden_id = d.orden_id AND o.estado_orden <> 'Cancelado'
    JOIN productos p ON p.producto_id = d.producto_id
    LEFT JOIN categorias cat ON cat.categoria_id = p.categoria_id
    GROUP BY p.categoria_id, cat.nombre_categoria, p.producto_id, p.nombre
)
SELECT categoria, ranking, producto, recaudacion
FROM recaudacion_producto
WHERE ranking <= 3
ORDER BY categoria, ranking;

-- ------------------------------------------------------------
-- 8. Concentración de la recaudación por categoría (% del total)
-- ------------------------------------------------------------
SELECT
    COALESCE(cat.nombre_categoria, 'Sin categoría') AS categoria,
    SUM(d.subtotal) AS recaudacion,
    ROUND(100 * SUM(d.subtotal) / SUM(SUM(d.subtotal)) OVER (), 1) AS pct_del_total
FROM detalle_ordenes d
JOIN ordenes o ON o.orden_id = d.orden_id AND o.estado_orden <> 'Cancelado'
JOIN productos p ON p.producto_id = d.producto_id
LEFT JOIN categorias cat ON cat.categoria_id = p.categoria_id
GROUP BY cat.nombre_categoria
ORDER BY recaudacion DESC;

-- ------------------------------------------------------------
-- 9. Clientes únicos vs. recurrentes (CASE + CTE)
-- ------------------------------------------------------------
WITH compras AS (
    SELECT
        o.cliente_id,
        COUNT(DISTINCT o.orden_id) AS n_ordenes,
        SUM(d.subtotal) AS gasto
    FROM ordenes o
    JOIN detalle_ordenes d ON d.orden_id = o.orden_id
    WHERE o.estado_orden <> 'Cancelado'
    GROUP BY o.cliente_id
)
SELECT
    CASE
        WHEN n_ordenes = 1 THEN '1 compra'
        WHEN n_ordenes BETWEEN 2 AND 3 THEN '2-3 compras'
        ELSE '4+ compras'
    END AS segmento,
    COUNT(*) AS clientes,
    SUM(gasto) AS recaudacion,
    ROUND(100 * SUM(gasto) / SUM(SUM(gasto)) OVER (), 1) AS pct_recaudacion
FROM compras
GROUP BY segmento
ORDER BY MIN(n_ordenes);

-- ------------------------------------------------------------
-- 10. Órdenes por estado y su peso porcentual (incluye tasa de cancelación)
-- ------------------------------------------------------------
SELECT
    estado_orden,
    COUNT(*) AS ordenes,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_ordenes
FROM ordenes
GROUP BY estado_orden
ORDER BY ordenes DESC;
