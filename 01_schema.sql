-- ============================================================
-- 01_schema.sql  |  Sistema de Gestión de E-commerce (MySQL 8.0.16+)
-- ADVERTENCIA: este script ejecuta DROP DATABASE y borra ecommerce_db
-- si ya existe. Los CHECK solo se aplican desde MySQL 8.0.16
-- (en versiones anteriores se ignoran en silencio).
-- ============================================================

DROP DATABASE IF EXISTS ecommerce_db;
CREATE DATABASE ecommerce_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE ecommerce_db;

-- 1. Clientes
CREATE TABLE clientes (
    cliente_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL,
    apellido VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    telefono VARCHAR(20),
    ciudad VARCHAR(50) NOT NULL,
    pais VARCHAR(50) NOT NULL DEFAULT 'Argentina',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- 2. Categorías de productos
CREATE TABLE categorias (
    categoria_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_categoria VARCHAR(50) NOT NULL,
    descripcion TEXT
) ENGINE=InnoDB;

-- 3. Productos y stock
CREATE TABLE productos (
    producto_id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    categoria_id INT,
    precio DECIMAL(10, 2) NOT NULL CHECK (precio > 0),
    stock_actual INT NOT NULL DEFAULT 0 CHECK (stock_actual >= 0),
    stock_minimo INT NOT NULL DEFAULT 5 CHECK (stock_minimo >= 0),
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id)
        REFERENCES categorias(categoria_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- 4. Órdenes (cabecera)
-- Nota de diseño: "total" es un dato derivado (suma de detalle_ordenes.subtotal).
-- Se mantiene como desnormalización deliberada para consultas rápidas de cabecera.
-- Las consultas analíticas recalculan desde el detalle para no depender de él.
CREATE TABLE ordenes (
    orden_id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    fecha_orden DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    estado_orden ENUM('Pendiente', 'Procesando', 'Enviado', 'Entregado', 'Cancelado')
        NOT NULL DEFAULT 'Pendiente',
    total DECIMAL(10, 2) NOT NULL DEFAULT 0.00 CHECK (total >= 0),
    CONSTRAINT fk_orden_cliente FOREIGN KEY (cliente_id)
        REFERENCES clientes(cliente_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- 5. Detalle de órdenes (relación N:M entre órdenes y productos)
-- precio_unitario guarda el precio histórico al momento de la venta,
-- que puede diferir de productos.precio (precio actual).
CREATE TABLE detalle_ordenes (
    detalle_id INT AUTO_INCREMENT PRIMARY KEY,
    orden_id INT NOT NULL,
    producto_id INT NOT NULL,
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10, 2) NOT NULL CHECK (precio_unitario > 0),
    subtotal DECIMAL(10, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,
    CONSTRAINT fk_detalle_orden FOREIGN KEY (orden_id)
        REFERENCES ordenes(orden_id) ON DELETE CASCADE,
    CONSTRAINT fk_detalle_producto FOREIGN KEY (producto_id)
        REFERENCES productos(producto_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- Índices para las consultas analíticas (las FK ya generan los suyos en InnoDB)
CREATE INDEX idx_ordenes_fecha  ON ordenes (fecha_orden);
CREATE INDEX idx_ordenes_estado ON ordenes (estado_orden);

-- Vista plana lista para conectar a Power BI / Excel
CREATE VIEW vw_ventas AS
SELECT
    o.orden_id,
    o.fecha_orden,
    DATE(o.fecha_orden) AS fecha,
    o.estado_orden,
    c.cliente_id,
    CONCAT(c.nombre, ' ', c.apellido) AS cliente,
    c.ciudad,
    p.producto_id,
    p.nombre AS producto,
    COALESCE(cat.nombre_categoria, 'Sin categoría') AS categoria,
    d.cantidad,
    d.precio_unitario,
    d.subtotal
FROM ordenes o
JOIN clientes c ON c.cliente_id = o.cliente_id
JOIN detalle_ordenes d ON d.orden_id = o.orden_id
JOIN productos p ON p.producto_id = d.producto_id
LEFT JOIN categorias cat ON cat.categoria_id = p.categoria_id;
