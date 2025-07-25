-- Crear base de datos
CREATE DATABASE IF NOT EXISTS SistemaInventario;
USE SistemaInventario;

-- ================================================
-- TABLA PRODUCTOS
-- ================================================
CREATE TABLE Productos (
    ID_Producto INT AUTO_INCREMENT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Descripcion TEXT,
    Precio DECIMAL(10,2) NOT NULL CHECK (Precio > 0),
    Cantidad_Inventario INT NOT NULL DEFAULT 0 CHECK (Cantidad_Inventario >= 0),
    Fecha_Creacion DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Estado ENUM('ACTIVO', 'INACTIVO', 'DESCONTINUADO') NOT NULL DEFAULT 'ACTIVO',

    -- Índices para optimización
    INDEX idx_nombre (Nombre),
    INDEX idx_estado (Estado),
    INDEX idx_fecha_creacion (Fecha_Creacion)
);

-- ================================================
-- TABLA PROVEEDORES
-- ================================================
CREATE TABLE Proveedores (
    ID_Proveedor INT AUTO_INCREMENT PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL,
    Direccion VARCHAR(200),
    Telefono VARCHAR(20),
    Email VARCHAR(100) UNIQUE,
    Fecha_Registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Estado ENUM('ACTIVO', 'INACTIVO', 'SUSPENDIDO') NOT NULL DEFAULT 'ACTIVO',

    -- Índices
    INDEX idx_nombre_proveedor (Nombre),
    INDEX idx_email (Email),
    INDEX idx_estado_proveedor (Estado)
);

-- ================================================
-- TABLA TRANSACCIONES
-- ================================================
CREATE TABLE Transacciones (
    ID_Transaccion INT AUTO_INCREMENT PRIMARY KEY,
    ID_Producto INT NOT NULL,
    ID_Proveedor INT NOT NULL,
    Tipo ENUM('COMPRA', 'VENTA') NOT NULL,
    Fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    Precio_Unitario DECIMAL(10,2) NOT NULL CHECK (Precio_Unitario > 0),
    Total DECIMAL(10,2) GENERATED ALWAYS AS (Cantidad * Precio_Unitario) STORED,
    Observaciones TEXT,

    -- Claves foráneas
    FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (ID_Proveedor) REFERENCES Proveedores(ID_Proveedor)
        ON DELETE RESTRICT ON UPDATE CASCADE,

    -- Índices para consultas frecuentes
    INDEX idx_fecha (Fecha),
    INDEX idx_tipo (Tipo),
    INDEX idx_producto (ID_Producto),
    INDEX idx_proveedor (ID_Proveedor),
    INDEX idx_fecha_tipo (Fecha, Tipo)
);

-- ================================================
-- TABLA RELACIÓN PRODUCTO-PROVEEDOR
-- ================================================
CREATE TABLE Producto_Proveedor (
    ID_Relacion INT AUTO_INCREMENT PRIMARY KEY,
    ID_Producto INT NOT NULL,
    ID_Proveedor INT NOT NULL,
    Precio_Proveedor DECIMAL(10,2) NOT NULL CHECK (Precio_Proveedor > 0),
    Tiempo_Entrega INT CHECK (Tiempo_Entrega > 0), -- días
    Fecha_Inicio DATE NOT NULL,
    Fecha_Fin DATE,
    Estado ENUM('ACTIVO', 'INACTIVO', 'PENDIENTE') NOT NULL DEFAULT 'ACTIVO',

    -- Claves foráneas
    FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto)
        ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ID_Proveedor) REFERENCES Proveedores(ID_Proveedor)
        ON DELETE CASCADE ON UPDATE CASCADE,

    -- Restricciones
    CONSTRAINT chk_fechas CHECK (Fecha_Fin IS NULL OR Fecha_Fin >= Fecha_Inicio),
    CONSTRAINT uk_producto_proveedor_activo UNIQUE (ID_Producto, ID_Proveedor, Estado),

    -- Índices
    INDEX idx_producto_proveedor (ID_Producto, ID_Proveedor),
    INDEX idx_estado_relacion (Estado),
    INDEX idx_fecha_inicio (Fecha_Inicio)
);

-- ================================================
-- TRIGGERS PARA AUTOMATIZACIÓN
-- ================================================

-- Trigger para actualizar inventario en compras
DELIMITER //
CREATE TRIGGER tr_actualizar_inventario_compra
    AFTER INSERT ON Transacciones
    FOR EACH ROW
BEGIN
    IF NEW.Tipo = 'COMPRA' THEN
        UPDATE Productos
        SET Cantidad_Inventario = Cantidad_Inventario + NEW.Cantidad
        WHERE ID_Producto = NEW.ID_Producto;
    END IF;
END//

-- Trigger para actualizar inventario en ventas
CREATE TRIGGER tr_actualizar_inventario_venta
    BEFORE INSERT ON Transacciones
    FOR EACH ROW
BEGIN
    DECLARE stock_actual INT;

    IF NEW.Tipo = 'VENTA' THEN
        SELECT Cantidad_Inventario INTO stock_actual
        FROM Productos
        WHERE ID_Producto = NEW.ID_Producto;

        IF stock_actual < NEW.Cantidad THEN
            SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Stock insuficiente para realizar la venta';
        END IF;

        UPDATE Productos
        SET Cantidad_Inventario = Cantidad_Inventario - NEW.Cantidad
        WHERE ID_Producto = NEW.ID_Producto;
    END IF;
END//
DELIMITER ;

-- ================================================
-- VISTAS ÚTILES
-- ================================================

-- Vista de productos con información de proveedores
CREATE VIEW vw_productos_proveedores AS
SELECT
    p.ID_Producto,
    p.Nombre AS Producto,
    p.Precio,
    p.Cantidad_Inventario,
    pr.Nombre AS Proveedor,
    pp.Precio_Proveedor,
    pp.Tiempo_Entrega
FROM Productos p
INNER JOIN Producto_Proveedor pp ON p.ID_Producto = pp.ID_Producto
INNER JOIN Proveedores pr ON pp.ID_Proveedor = pr.ID_Proveedor
WHERE p.Estado = 'ACTIVO' AND pp.Estado = 'ACTIVO';

-- Vista de resumen de transacciones
CREATE VIEW vw_resumen_transacciones AS
SELECT
    t.ID_Transaccion,
    p.Nombre AS Producto,
    pr.Nombre AS Proveedor,
    t.Tipo,
    t.Fecha,
    t.Cantidad,
    t.Precio_Unitario,
    t.Total
FROM Transacciones t
INNER JOIN Productos p ON t.ID_Producto = p.ID_Producto
INNER JOIN Proveedores pr ON t.ID_Proveedor = pr.ID_Proveedor;

SHOW TABLES;

-- ================================================
-- INSERCIÓN DE DATOS DE PRUEBA
-- ================================================

USE SistemaInventario;

-- ================================================
-- INSERTAR PROVEEDORES
-- ================================================
INSERT INTO Proveedores (Nombre, Direccion, Telefono, Email) VALUES
('TechSupply SA', 'Av. Tecnología 123, Santiago', '+56-2-2345-6789', 'ventas@techsupply.cl'),
('Distribuidora Norte', 'Calle Industrial 456, Antofagasta', '+56-55-234-5678', 'contacto@disnorte.cl'),
('Importadora Global', 'Av. Libertador 789, Valparaíso', '+56-32-345-6789', 'info@impglobal.cl'),
('Suministros del Sur', 'Ruta 5 Sur Km 850, Temuco', '+56-45-456-7890', 'ventas@sumisur.cl'),
('ElectroMax Ltda', 'Av. Providencia 234, Santiago', '+56-2-3456-7890', 'pedidos@electromax.cl');

-- ================================================
-- INSERTAR PRODUCTOS
-- ================================================
INSERT INTO Productos (Nombre, Descripcion, Precio, Cantidad_Inventario) VALUES
('Laptop Dell Inspiron 15', 'Laptop para oficina con procesador Intel i5, 8GB RAM, 256GB SSD', 850000.00, 15),
('Mouse Inalámbrico Logitech', 'Mouse óptico inalámbrico con receptor USB', 25000.00, 50),
('Teclado Mecánico RGB', 'Teclado mecánico con iluminación RGB programable', 89000.00, 25),
('Monitor Samsung 24"', 'Monitor LED Full HD 1920x1080, conexión HDMI y VGA', 180000.00, 12),
('Impresora HP LaserJet', 'Impresora láser monocromática, velocidad 22 ppm', 320000.00, 8),
('Disco Duro Externo 1TB', 'Disco duro externo USB 3.0, capacidad 1TB', 75000.00, 30),
('Webcam HD Logitech', 'Cámara web HD 1080p con micrófono incorporado', 45000.00, 20),
('Auriculares Bluetooth', 'Auriculares inalámbricos con cancelación de ruido', 120000.00, 18),
('Router WiFi 6', 'Router inalámbrico WiFi 6, cobertura hasta 150m²', 95000.00, 10),
('Tablet Samsung Galaxy', 'Tablet Android 10", 64GB almacenamiento, WiFi', 280000.00, 6);

-- ================================================
-- INSERTAR RELACIONES PRODUCTO-PROVEEDOR
-- ================================================
INSERT INTO Producto_Proveedor (ID_Producto, ID_Proveedor, Precio_Proveedor, Tiempo_Entrega, Fecha_Inicio) VALUES
-- TechSupply SA suministra productos tecnológicos
(1, 1, 750000.00, 7, '2024-01-15'),   -- Laptop Dell
(2, 1, 18000.00, 3, '2024-01-15'),    -- Mouse Logitech
(3, 1, 75000.00, 5, '2024-01-15'),    -- Teclado RGB
(7, 1, 38000.00, 4, '2024-01-15'),    -- Webcam

-- Distribuidora Norte - productos de oficina
(4, 2, 150000.00, 10, '2024-02-01'),  -- Monitor Samsung
(5, 2, 280000.00, 14, '2024-02-01'),  -- Impresora HP
(6, 2, 62000.00, 7, '2024-02-01'),    -- Disco Externo

-- Importadora Global - productos premium
(1, 3, 780000.00, 12, '2024-01-20'),  -- Laptop Dell (alternativo)
(8, 3, 95000.00, 8, '2024-01-20'),    -- Auriculares
(10, 3, 250000.00, 15, '2024-01-20'), -- Tablet Samsung

-- Suministros del Sur - productos de conectividad
(9, 4, 82000.00, 6, '2024-02-10'),    -- Router WiFi
(2, 4, 20000.00, 4, '2024-02-10'),    -- Mouse (alternativo)

-- ElectroMax - productos electrónicos
(4, 5, 160000.00, 8, '2024-02-15'),   -- Monitor (alternativo)
(6, 5, 68000.00, 5, '2024-02-15'),    -- Disco Externo (alternativo)
(8, 5, 105000.00, 7, '2024-02-15');   -- Auriculares (alternativo)

-- ================================================
-- INSERTAR TRANSACCIONES DE EJEMPLO
-- ================================================

-- Transacciones de COMPRA (aumentan inventario)
INSERT INTO Transacciones (ID_Producto, ID_Proveedor, Tipo, Fecha, Cantidad, Precio_Unitario, Observaciones) VALUES
(1, 1, 'COMPRA', '2024-06-01 09:00:00', 10, 750000.00, 'Compra inicial de laptops'),
(2, 1, 'COMPRA', '2024-06-01 10:30:00', 30, 18000.00, 'Reposición de stock de mouse'),
(3, 1, 'COMPRA', '2024-06-02 14:15:00', 15, 75000.00, 'Nuevos teclados RGB'),
(4, 2, 'COMPRA', '2024-06-03 11:20:00', 8, 150000.00, 'Monitores para oficina'),
(5, 2, 'COMPRA', '2024-06-05 16:45:00', 5, 280000.00, 'Impresoras departamento'),

-- Transacciones de VENTA (disminuyen inventario)
(1, 1, 'VENTA', '2024-06-10 10:15:00', 2, 850000.00, 'Venta corporativa - Empresa ABC'),
(2, 1, 'VENTA', '2024-06-10 11:30:00', 5, 25000.00, 'Venta al por menor'),
(3, 1, 'VENTA', '2024-06-12 09:45:00', 3, 89000.00, 'Venta gaming setup'),
(4, 2, 'VENTA', '2024-06-12 15:20:00', 1, 180000.00, 'Monitor para diseñador'),
(2, 1, 'VENTA', '2024-06-15 13:10:00', 8, 25000.00, 'Venta mayorista'),

-- Más transacciones para análisis
(6, 2, 'COMPRA', '2024-06-18 08:30:00', 20, 62000.00, 'Discos para backup'),
(7, 1, 'COMPRA', '2024-06-19 12:00:00', 15, 38000.00, 'Webcams para teletrabajo'),
(8, 3, 'COMPRA', '2024-06-20 10:45:00', 12, 95000.00, 'Auriculares premium'),
(6, 2, 'VENTA', '2024-06-22 14:30:00', 5, 75000.00, 'Discos externos'),
(7, 1, 'VENTA', '2024-06-23 11:15:00', 3, 45000.00, 'Webcams videoconferencia');

-- ================================================
-- VERIFICAR DATOS INSERTADOS
-- ================================================
SELECT 'PROVEEDORES' AS Tabla, COUNT(*) AS Registros FROM Proveedores
UNION ALL
SELECT 'PRODUCTOS' AS Tabla, COUNT(*) AS Registros FROM Productos
UNION ALL
SELECT 'PRODUCTO_PROVEEDOR' AS Tabla, COUNT(*) AS Registros FROM Producto_Proveedor
UNION ALL
SELECT 'TRANSACCIONES' AS Tabla, COUNT(*) AS Registros FROM Transacciones;


-- ================================================
-- CONSULTAS SQL - SISTEMA DE INVENTARIO
-- ================================================

USE SistemaInventario;

-- ================================================
-- 1. CONSULTAS BÁSICAS
-- ================================================

-- 1.1 Recuperar todos los productos disponibles en inventario
SELECT
    ID_Producto,
    Nombre,
    Descripcion,
    Precio,
    Cantidad_Inventario,
    CASE
        WHEN Cantidad_Inventario = 0 THEN 'Sin Stock'
        WHEN Cantidad_Inventario <= 5 THEN 'Stock Bajo'
        WHEN Cantidad_Inventario <= 15 THEN 'Stock Medio'
        ELSE 'Stock Alto'
    END AS Estado_Stock
FROM Productos
WHERE Estado = 'ACTIVO'
ORDER BY Cantidad_Inventario ASC;

-- 1.2 Recuperar proveedores que suministran productos específicos
SELECT DISTINCT
    pr.ID_Proveedor,
    pr.Nombre AS Proveedor,
    pr.Telefono,
    pr.Email,
    p.Nombre AS Producto,
    pp.Precio_Proveedor,
    pp.Tiempo_Entrega
FROM Proveedores pr
INNER JOIN Producto_Proveedor pp ON pr.ID_Proveedor = pp.ID_Proveedor
INNER JOIN Productos p ON pp.ID_Producto = p.ID_Producto
WHERE p.Nombre LIKE '%Laptop%' OR p.Nombre LIKE '%Monitor%'
ORDER BY pr.Nombre, p.Nombre;

-- 1.3 Transacciones realizadas en fecha específica
SELECT
    t.ID_Transaccion,
    p.Nombre AS Producto,
    pr.Nombre AS Proveedor,
    t.Tipo,
    t.Cantidad,
    t.Precio_Unitario,
    t.Total,
    t.Observaciones
FROM Transacciones t
INNER JOIN Productos p ON t.ID_Producto = p.ID_Producto
INNER JOIN Proveedores pr ON t.ID_Proveedor = pr.ID_Proveedor
WHERE DATE(t.Fecha) = '2024-06-10'
ORDER BY t.Fecha;

-- ================================================
-- 2. CONSULTAS CON FUNCIONES DE AGRUPACIÓN
-- ================================================

-- 2.1 Número total de productos vendidos por producto
SELECT
    p.Nombre AS Producto,
    COUNT(t.ID_Transaccion) AS Num_Transacciones_Venta,
    SUM(t.Cantidad) AS Total_Vendido,
    AVG(t.Precio_Unitario) AS Precio_Promedio_Venta,
    SUM(t.Total) AS Ingresos_Totales
FROM Productos p
LEFT JOIN Transacciones t ON p.ID_Producto = t.ID_Producto AND t.Tipo = 'VENTA'
GROUP BY p.ID_Producto, p.Nombre
ORDER BY Total_Vendido DESC;

-- 2.2 Valor total de compras por proveedor
SELECT
    pr.Nombre AS Proveedor,
    COUNT(t.ID_Transaccion) AS Num_Compras,
    SUM(t.Cantidad) AS Total_Productos_Comprados,
    SUM(t.Total) AS Total_Gastado,
    AVG(t.Total) AS Promedio_Por_Compra
FROM Proveedores pr
INNER JOIN Transacciones t ON pr.ID_Proveedor = t.ID_Proveedor
WHERE t.Tipo = 'COMPRA'
GROUP BY pr.ID_Proveedor, pr.Nombre
ORDER BY Total_Gastado DESC;

-- 2.3 Resumen mensual de transacciones
SELECT
    YEAR(Fecha) AS Año,
    MONTH(Fecha) AS Mes,
    MONTHNAME(Fecha) AS Nombre_Mes,
    Tipo,
    COUNT(*) AS Num_Transacciones,
    SUM(Cantidad) AS Total_Productos,
    SUM(Total) AS Valor_Total
FROM Transacciones
GROUP BY YEAR(Fecha), MONTH(Fecha), Tipo
ORDER BY Año, Mes, Tipo;

-- ================================================
-- 3. CONSULTAS COMPLEJAS CON JOINS
-- ================================================

-- 3.1 Total de ventas de productos durante el mes anterior
SELECT
    p.ID_Producto,
    p.Nombre AS Producto,
    p.Precio AS Precio_Actual,
    COALESCE(SUM(t.Cantidad), 0) AS Cantidad_Vendida,
    COALESCE(SUM(t.Total), 0) AS Ingresos_Generados,
    p.Cantidad_Inventario AS Stock_Actual
FROM Productos p
LEFT JOIN Transacciones t ON p.ID_Producto = t.ID_Producto
    AND t.Tipo = 'VENTA'
    AND t.Fecha >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH)
    AND t.Fecha < CURDATE()
GROUP BY p.ID_Producto, p.Nombre, p.Precio, p.Cantidad_Inventario
ORDER BY Ingresos_Generados DESC;

-- 3.2 Análisis completo de productos con proveedores (INNER y LEFT JOIN)
SELECT
    p.ID_Producto,
    p.Nombre AS Producto,
    p.Precio,
    p.Cantidad_Inventario,
    pr.Nombre AS Proveedor,
    pp.Precio_Proveedor,
    pp.Tiempo_Entrega,
    (p.Precio - pp.Precio_Proveedor) AS Margen_Ganancia,
    ROUND(((p.Precio - pp.Precio_Proveedor) / pp.Precio_Proveedor) * 100, 2) AS Porcentaje_Margen
FROM Productos p
LEFT JOIN Producto_Proveedor pp ON p.ID_Producto = pp.ID_Producto AND pp.Estado = 'ACTIVO'
LEFT JOIN Proveedores pr ON pp.ID_Proveedor = pr.ID_Proveedor
WHERE p.Estado = 'ACTIVO'
ORDER BY Porcentaje_Margen DESC;

-- ================================================
-- 4. SUBCONSULTAS (SUBQUERIES)
-- ================================================

-- 4.1 Productos que no se han vendido en los últimos 30 días
SELECT
    p.ID_Producto,
    p.Nombre,
    p.Precio,
    p.Cantidad_Inventario,
    p.Fecha_Creacion
FROM Productos p
WHERE p.ID_Producto NOT IN (
    SELECT DISTINCT t.ID_Producto
    FROM Transacciones t
    WHERE t.Tipo = 'VENTA'
    AND t.Fecha >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
)
AND p.Estado = 'ACTIVO'
ORDER BY p.Cantidad_Inventario DESC;

-- 4.2 Proveedores con precios por encima del promedio
SELECT
    pr.Nombre AS Proveedor,
    p.Nombre AS Producto,
    pp.Precio_Proveedor
FROM Proveedores pr
INNER JOIN Producto_Proveedor pp ON pr.ID_Proveedor = pp.ID_Proveedor
INNER JOIN Productos p ON pp.ID_Producto = p.ID_Producto
WHERE pp.Precio_Proveedor > (
    SELECT AVG(pp2.Precio_Proveedor)
    FROM Producto_Proveedor pp2
    WHERE pp2.ID_Producto = pp.ID_Producto
    AND pp2.Estado = 'ACTIVO'
)
AND pp.Estado = 'ACTIVO'
ORDER BY pp.Precio_Proveedor DESC;

-- 4.3 Top 3 productos más vendidos
SELECT
    p.Nombre AS Producto,
    SUM(t.Cantidad) AS Total_Vendido,
    SUM(t.Total) AS Ingresos_Totales
FROM Productos p
INNER JOIN Transacciones t ON p.ID_Producto = t.ID_Producto
WHERE t.Tipo = 'VENTA'
GROUP BY p.ID_Producto, p.Nombre
ORDER BY Total_Vendido DESC
LIMIT 3;

-- ================================================
-- 5. CONSULTAS DE ANÁLISIS AVANZADO
-- ================================================

-- 5.1 Análisis de rotación de inventario
SELECT
    p.Nombre AS Producto,
    p.Cantidad_Inventario AS Stock_Actual,
    COALESCE(ventas.Total_Vendido, 0) AS Total_Vendido,
    COALESCE(compras.Total_Comprado, 0) AS Total_Comprado,
    CASE
        WHEN p.Cantidad_Inventario > 0 AND ventas.Total_Vendido > 0
        THEN ROUND(ventas.Total_Vendido / p.Cantidad_Inventario, 2)
        ELSE 0
    END AS Rotacion_Inventario,
    CASE
        WHEN ventas.Total_Vendido > p.Cantidad_Inventario THEN 'Alta Rotación'
        WHEN ventas.Total_Vendido > (p.Cantidad_Inventario * 0.5) THEN 'Rotación Media'
        WHEN ventas.Total_Vendido > 0 THEN 'Baja Rotación'
        ELSE 'Sin Movimiento'
    END AS Clasificacion_Rotacion
FROM Productos p
LEFT JOIN (
    SELECT ID_Producto, SUM(Cantidad) AS Total_Vendido
    FROM Transacciones
    WHERE Tipo = 'VENTA'
    AND Fecha >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY ID_Producto
) ventas ON p.ID_Producto = ventas.ID_Producto
LEFT JOIN (
    SELECT ID_Producto, SUM(Cantidad) AS Total_Comprado
    FROM Transacciones
    WHERE Tipo = 'COMPRA'
    AND Fecha >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
    GROUP BY ID_Producto
) compras ON p.ID_Producto = compras.ID_Producto
WHERE p.Estado = 'ACTIVO'
ORDER BY Rotacion_Inventario DESC;

-- 5.2 Rentabilidad por producto
SELECT
    p.Nombre AS Producto,
    COALESCE(ventas.Ingresos_Ventas, 0) AS Ingresos_Ventas,
    COALESCE(compras.Costo_Compras, 0) AS Costo_Compras,
    (COALESCE(ventas.Ingresos_Ventas, 0) - COALESCE(compras.Costo_Compras, 0)) AS Ganancia_Bruta,
    CASE
        WHEN compras.Costo_Compras > 0 THEN
            ROUND(((ventas.Ingresos_Ventas - compras.Costo_Compras) / compras.Costo_Compras) * 100, 2)
        ELSE 0
    END AS ROI_Porcentaje
FROM Productos p
LEFT JOIN (
    SELECT
        ID_Producto,
        SUM(Total) AS Ingresos_Ventas,
        SUM(Cantidad) AS Cantidad_Vendida
    FROM Transacciones
    WHERE Tipo = 'VENTA'
    GROUP BY ID_Producto
) ventas ON p.ID_Producto = ventas.ID_Producto
LEFT JOIN (
    SELECT
        ID_Producto,
        SUM(Total) AS Costo_Compras,
        SUM(Cantidad) AS Cantidad_Comprada
    FROM Transacciones
    WHERE Tipo = 'COMPRA'
    GROUP BY ID_Producto
) compras ON p.ID_Producto = compras.ID_Producto
WHERE p.Estado = 'ACTIVO'
ORDER BY Ganancia_Bruta DESC;

-- ================================================
-- 6. CONSULTAS DE CONTROL Y ALERTAS
-- ================================================

-- 6.1 Productos con stock bajo (menos de 10 unidades)
SELECT
    p.ID_Producto,
    p.Nombre,
    p.Cantidad_Inventario,
    DATEDIFF(CURDATE(), MAX(t.Fecha)) AS Dias_Sin_Movimiento,
    'ALERTA: Stock Bajo' AS Mensaje
FROM Productos p
LEFT JOIN Transacciones t ON p.ID_Producto = t.ID_Producto
WHERE p.Cantidad_Inventario < 10
AND p.Estado = 'ACTIVO'
GROUP BY p.ID_Producto, p.Nombre, p.Cantidad_Inventario
ORDER BY p.Cantidad_Inventario ASC;

-- 6.2 Productos sin movimiento en los últimos 60 días
SELECT
    p.ID_Producto,
    p.Nombre,
    p.Cantidad_Inventario,
    p.Precio,
    (p.Cantidad_Inventario * p.Precio) AS Valor_Inventario_Inmovilizado,
    'ALERTA: Producto sin movimiento' AS Mensaje
FROM Productos p
WHERE p.ID_Producto NOT IN (
    SELECT DISTINCT t.ID_Producto
    FROM Transacciones t
    WHERE t.Fecha >= DATE_SUB(CURDATE(), INTERVAL 60 DAY)
)
AND p.Estado = 'ACTIVO'
AND p.Cantidad_Inventario > 0
ORDER BY Valor_Inventario_Inmovilizado DESC;

-- ================================================
-- MANEJO DE TRANSACCIONES SQL
-- ================================================
-- ================================================
-- 1. TRANSACCIÓN PARA COMPRA DE PRODUCTOS
-- ================================================

DELIMITER //

-- Procedimiento para registrar compras de productos
CREATE PROCEDURE sp_RegistrarCompra(
    IN p_id_producto INT,
    IN p_id_proveedor INT,
    IN p_cantidad INT,
    IN p_precio_unitario DECIMAL(10,2),
    IN p_observaciones TEXT,
    OUT p_resultado VARCHAR(100),
    OUT p_id_transaccion INT
)
BEGIN
    DECLARE v_error_count INT DEFAULT 0;
    DECLARE v_error_msg VARCHAR(255);

    -- Manejador de errores para hacer rollback si algo sale mal
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_resultado = CONCAT('ERROR: ', v_error_msg);
        SET p_id_transaccion = 0;
    END;

    START TRANSACTION;

    -- Validacion de cantidad positiva
    IF p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'La cantidad debe ser mayor a cero';
    END IF;

    -- Validacion de precio positivo
    IF p_precio_unitario <= 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'El precio debe ser mayor a cero';
    END IF;

    -- Verificar que el producto existe y esta activo
    SELECT COUNT(*) INTO v_error_count
    FROM Productos
    WHERE ID_Producto = p_id_producto AND Estado = 'ACTIVO';

    IF v_error_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Producto no encontrado o inactivo';
    END IF;

    -- Verificar que el proveedor existe y esta activo
    SELECT COUNT(*) INTO v_error_count
    FROM Proveedores
    WHERE ID_Proveedor = p_id_proveedor AND Estado = 'ACTIVO';

    IF v_error_count = 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Proveedor no encontrado o inactivo';
    END IF;

    -- Insertar la transaccion de compra
    INSERT INTO Transacciones (
        ID_Producto,
        ID_Proveedor,
        Tipo,
        Cantidad,
        Precio_Unitario,
        Observaciones
    ) VALUES (
        p_id_producto,
        p_id_proveedor,
        'COMPRA',
        p_cantidad,
        p_precio_unitario,
        p_observaciones
    );

    -- Obtener el ID de la transaccion recien creada
    SET p_id_transaccion = LAST_INSERT_ID();

    COMMIT;

    SET p_resultado = 'Compra registrada exitosamente';

END//

DELIMITER ;

-- ================================================
-- PROCEDIMIENTO PARA VENTAS DE PRODUCTOS
-- ================================================

-- ================================================
-- TRANSACCION COMPLEJA: TRANSFERENCIA ENTRE PROVEEDORES
-- ================================================

DELIMITER //

CREATE PROCEDURE sp_TransferirProductoProveedor(
    IN p_id_producto INT,
    IN p_id_proveedor_origen INT,
    IN p_id_proveedor_destino INT,
    IN p_cantidad INT,
    IN p_precio_transferencia DECIMAL(10,2),
    OUT p_resultado VARCHAR(200)
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_id_venta INT;
    DECLARE v_id_compra INT;
    DECLARE v_error_msg VARCHAR(255);

    -- Manejo de errores con rollback automatico
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_resultado = CONCAT('ERROR en transferencia: ', v_error_msg);
    END;

    START TRANSACTION;

    -- Verificar stock suficiente para la transferencia
    SELECT Cantidad_Inventario INTO v_stock_actual
    FROM Productos
    WHERE ID_Producto = p_id_producto;

    IF v_stock_actual < p_cantidad THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Stock insuficiente para transferencia';
    END IF;

    -- Registrar salida del proveedor origen (como venta)
    INSERT INTO Transacciones (
        ID_Producto, ID_Proveedor, Tipo, Cantidad,
        Precio_Unitario, Observaciones
    ) VALUES (
        p_id_producto, p_id_proveedor_origen, 'VENTA', p_cantidad,
        p_precio_transferencia, 'Transferencia - Salida'
    );
    SET v_id_venta = LAST_INSERT_ID();

    -- Registrar entrada al proveedor destino (como compra)
    INSERT INTO Transacciones (
        ID_Producto, ID_Proveedor, Tipo, Cantidad,
        Precio_Unitario, Observaciones
    ) VALUES (
        p_id_producto, p_id_proveedor_destino, 'COMPRA', p_cantidad,
        p_precio_transferencia, 'Transferencia - Entrada'
    );
    SET v_id_compra = LAST_INSERT_ID();

    -- Confirmar todas las operaciones
    COMMIT;

    SET p_resultado = CONCAT('Transferencia exitosa. Venta ID: ', v_id_venta, ', Compra ID: ', v_id_compra);

END//

DELIMITER ;




DELIMITER //

CREATE PROCEDURE sp_RegistrarVenta(
    IN p_id_producto INT,
    IN p_id_proveedor INT,
    IN p_cantidad INT,
    IN p_precio_unitario DECIMAL(10,2),
    IN p_observaciones TEXT,
    OUT p_resultado VARCHAR(100),
    OUT p_id_transaccion INT
)
BEGIN
    DECLARE v_stock_actual INT;
    DECLARE v_error_msg VARCHAR(255);

    -- Capturar errores y hacer rollback automatico
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_resultado = CONCAT('ERROR: ', v_error_msg);
        SET p_id_transaccion = 0;
    END;

    -- Validaciones basicas de entrada
    IF p_cantidad <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'La cantidad debe ser mayor a cero';
    END IF;

    IF p_precio_unitario <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio debe ser mayor a cero';
    END IF;

    START TRANSACTION;

    -- Obtener stock actual del producto (con bloqueo para evitar problemas de concurrencia)
    SELECT Cantidad_Inventario INTO v_stock_actual
    FROM Productos
    WHERE ID_Producto = p_id_producto AND Estado = 'ACTIVO'
    FOR UPDATE;

    -- Verificar si el producto existe
    IF v_stock_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Producto no encontrado o inactivo';
    END IF;

    -- Validar que hay suficiente stock
    IF v_stock_actual < p_cantidad THEN
        SET v_error_msg = CONCAT('Stock insuficiente. Disponible: ', v_stock_actual, ', Solicitado: ', p_cantidad);
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = v_error_msg;
    END IF;

    -- Registrar la venta en transacciones
    INSERT INTO Transacciones (
        ID_Producto,
        ID_Proveedor,
        Tipo,
        Cantidad,
        Precio_Unitario,
        Observaciones
    ) VALUES (
        p_id_producto,
        p_id_proveedor,
        'VENTA',
        p_cantidad,
        p_precio_unitario,
        p_observaciones
    );

    SET p_id_transaccion = LAST_INSERT_ID();

    -- Actualizar inventario restando la cantidad vendida
    UPDATE Productos
    SET Cantidad_Inventario = Cantidad_Inventario - p_cantidad
    WHERE ID_Producto = p_id_producto;

    COMMIT;

    SET p_resultado = 'Venta registrada exitosamente';

END//

DELIMITER ;
-- ================================================
-- EJEMPLOS DE USO
-- ================================================

-- Ejemplo 1: Registrar una compra
CALL sp_RegistrarCompra(
    1,                    -- ID del producto
    1,                    -- ID del proveedor
    5,                    -- Cantidad a comprar
    780000.00,            -- Precio por unidad
    'Compra adicional para stock',  -- Observaciones
    @resultado,           -- Variable para el resultado
    @id_transaccion       -- Variable para el ID de transaccion
);

-- Ver resultado de la compra
SELECT @resultado AS Resultado, @id_transaccion AS ID_Transaccion;

-- Ejemplo 2: Registrar una venta
CALL sp_RegistrarVenta(
    2,                    -- ID del producto
    1,                    -- ID del proveedor
    10,                   -- Cantidad a vender
    25000.00,             -- Precio por unidad
    'Venta corporativa - Lote grande',  -- Observaciones
    @resultado_venta,     -- Variable para resultado
    @id_venta            -- Variable para ID de venta
);

-- Ver resultado de la venta
SELECT @resultado_venta AS Resultado_Venta, @id_venta AS ID_Venta;

-- Ejemplo 3: Intento de venta con stock insuficiente (debe fallar)
CALL sp_RegistrarVenta(
    1,                    -- ID del producto
    1,                    -- ID del proveedor
    100,                  -- Cantidad excesiva
    850000.00,            -- Precio por unidad
    'Venta grande - debe fallar',  -- Observaciones
    @resultado_error,     -- Variable para error
    @id_error            -- Variable para ID
);

-- Ver el error
SELECT @resultado_error AS Resultado_Error, @id_error AS ID_Error;

-- ================================================
-- VERIFICACION DE INTEGRIDAD DE DATOS
-- ================================================

-- Consulta para verificar la consistencia del inventario
SELECT
    p.Nombre AS Producto,
    p.Cantidad_Inventario AS Stock_Actual,
    COALESCE(SUM(CASE WHEN t.Tipo = 'COMPRA' THEN t.Cantidad ELSE 0 END), 0) AS Total_Compras,
    COALESCE(SUM(CASE WHEN t.Tipo = 'VENTA' THEN t.Cantidad ELSE 0 END), 0) AS Total_Ventas,
    (COALESCE(SUM(CASE WHEN t.Tipo = 'COMPRA' THEN t.Cantidad ELSE 0 END), 0) -
     COALESCE(SUM(CASE WHEN t.Tipo = 'VENTA' THEN t.Cantidad ELSE 0 END), 0)) AS Stock_Calculado,
    CASE
        WHEN p.Cantidad_Inventario = (COALESCE(SUM(CASE WHEN t.Tipo = 'COMPRA' THEN t.Cantidad ELSE 0 END), 0) -
                                      COALESCE(SUM(CASE WHEN t.Tipo = 'VENTA' THEN t.Cantidad ELSE 0 END), 0))
        THEN 'CORRECTO'
        ELSE 'INCONSISTENCIA'
    END AS Estado_Integridad
FROM Productos p
LEFT JOIN Transacciones t ON p.ID_Producto = t.ID_Producto
WHERE p.Estado = 'ACTIVO'
GROUP BY p.ID_Producto, p.Nombre, p.Cantidad_Inventario
ORDER BY p.Nombre;

-- ================================================
-- RESTRICCIONES DE INTEGRIDAD
-- ================================================

-- Restricciones para la tabla productos
ALTER TABLE Productos
ADD CONSTRAINT chk_precio_positivo
    CHECK (Precio > 0),
ADD CONSTRAINT chk_inventario_no_negativo
    CHECK (Cantidad_Inventario >= 0),
ADD CONSTRAINT chk_nombre_no_vacio
    CHECK (TRIM(Nombre) != '');

-- Restricciones para proveedores
ALTER TABLE Proveedores
ADD CONSTRAINT chk_telefono_formato
    CHECK (Telefono REGEXP '^[+]?[0-9\-\s()]+$'),
ADD CONSTRAINT chk_nombre_proveedor_no_vacio
    CHECK (TRIM(Nombre) != '');


-- Restricciones para relacion producto-proveedor
ALTER TABLE Producto_Proveedor
ADD CONSTRAINT chk_precio_proveedor_positivo
    CHECK (Precio_Proveedor > 0),
ADD CONSTRAINT chk_tiempo_entrega_valido
    CHECK (Tiempo_Entrega IS NULL OR Tiempo_Entrega > 0);

-- ================================================
-- FUNCIONES AUXILIARES
-- ================================================

DELIMITER //

-- Funcion para validar formato de email (no muy sofisticada pero funciona)
CREATE FUNCTION fn_ValidarEmail(email VARCHAR(100))
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE es_valido BOOLEAN DEFAULT FALSE;

    -- Expresion regular basica para email
    IF email REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        SET es_valido = TRUE;
    END IF;

    RETURN es_valido;
END//

-- Funcion para calcular margenes de ganancia
CREATE FUNCTION fn_CalcularMargen(precio_venta DECIMAL(10,2), precio_costo DECIMAL(10,2))
RETURNS DECIMAL(5,2)
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE margen DECIMAL(5,2) DEFAULT 0.00;

    -- Calcular porcentaje de margen solo si los precios son validos
    IF precio_costo > 0 AND precio_venta > precio_costo THEN
        SET margen = ROUND(((precio_venta - precio_costo) / precio_costo) * 100, 2);
    END IF;

    RETURN margen;
END//

-- Funcion para verificar si hay stock suficiente
CREATE FUNCTION fn_ValidarStockMinimo(id_producto INT, cantidad_venta INT)
RETURNS BOOLEAN
READS SQL DATA
DETERMINISTIC
BEGIN
    DECLARE stock_actual INT DEFAULT 0;
    DECLARE es_valido BOOLEAN DEFAULT FALSE;

    -- Obtener stock actual del producto
    SELECT Cantidad_Inventario INTO stock_actual
    FROM Productos
    WHERE ID_Producto = id_producto;

    -- Verificar si hay suficiente stock
    IF stock_actual >= cantidad_venta THEN
        SET es_valido = TRUE;
    END IF;

    RETURN es_valido;
END//

DELIMITER ;

-- ================================================
-- 4. TRIGGERS PARA MANTENER INTEGRIDAD
-- ================================================

DELIMITER //

-- Trigger para validar email antes de insertar proveedor
CREATE TRIGGER tr_validar_email_proveedor
    BEFORE INSERT ON Proveedores
    FOR EACH ROW
BEGIN
    IF NEW.Email IS NOT NULL AND NOT fn_ValidarEmail(NEW.Email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Formato de email inválido';
    END IF;
END//

-- Trigger para validar email antes de actualizar proveedor
CREATE TRIGGER tr_validar_email_proveedor_update
    BEFORE UPDATE ON Proveedores
    FOR EACH ROW
BEGIN
    IF NEW.Email IS NOT NULL AND NOT fn_ValidarEmail(NEW.Email) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Formato de email inválido';
    END IF;
END//

-- Trigger para prevenir eliminación de productos con transacciones
CREATE TRIGGER tr_prevenir_eliminacion_producto
    BEFORE DELETE ON Productos
    FOR EACH ROW
BEGIN
    DECLARE num_transacciones INT DEFAULT 0;

    SELECT COUNT(*) INTO num_transacciones
    FROM Transacciones
    WHERE ID_Producto = OLD.ID_Producto;

    IF num_transacciones > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'No se puede eliminar producto con transacciones asociadas';
    END IF;
END//

-- Trigger para registrar cambios en precios de productos
CREATE TRIGGER tr_registrar_cambio_precio
    AFTER UPDATE ON Productos
    FOR EACH ROW
BEGIN
    IF OLD.Precio != NEW.Precio THEN
        INSERT INTO Log_Cambios_Precios (
            ID_Producto,
            Precio_Anterior,
            Precio_Nuevo,
            Fecha_Cambio,
            Usuario
        ) VALUES (
            NEW.ID_Producto,
            OLD.Precio,
            NEW.Precio,
            NOW(),
            USER()
        );
    END IF;
END//

DELIMITER ;

-- ================================================
-- 5. TABLA DE LOG PARA AUDITORIA
-- ================================================

CREATE TABLE Log_Cambios_Precios (
    ID_Log INT AUTO_INCREMENT PRIMARY KEY,
    ID_Producto INT NOT NULL,
    Precio_Anterior DECIMAL(10,2) NOT NULL,
    Precio_Nuevo DECIMAL(10,2) NOT NULL,
    Fecha_Cambio DATETIME NOT NULL,
    Usuario VARCHAR(100) NOT NULL,

    FOREIGN KEY (ID_Producto) REFERENCES Productos(ID_Producto)
        ON DELETE CASCADE ON UPDATE CASCADE,

    INDEX idx_fecha_cambio (Fecha_Cambio),
    INDEX idx_producto_log (ID_Producto)
);

-- ================================================
-- 6. PROCEDIMIENTOS PARA MANEJO DE EXCEPCIONES
-- ================================================

DELIMITER //

-- Procedimiento con manejo completo de errores
CREATE PROCEDURE sp_ActualizarPrecioProducto(
    IN p_id_producto INT,
    IN p_precio_nuevo DECIMAL(10,2),
    OUT p_resultado VARCHAR(200)
)
BEGIN
    DECLARE v_precio_actual DECIMAL(10,2);
    DECLARE v_nombre_producto VARCHAR(100);
    DECLARE v_error_msg VARCHAR(255);

    -- Handler para manejar excepciones
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        GET DIAGNOSTICS CONDITION 1
            v_error_msg = MESSAGE_TEXT;
        ROLLBACK;
        SET p_resultado = CONCAT('ERROR: ', v_error_msg);
    END;

    -- Iniciar transacción
    START TRANSACTION;

    -- Validaciones
    IF p_precio_nuevo <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'El precio debe ser mayor a cero';
    END IF;

    -- Obtener información actual del producto
    SELECT Precio, Nombre INTO v_precio_actual, v_nombre_producto
    FROM Productos
    WHERE ID_Producto = p_id_producto AND Estado = 'ACTIVO';

    IF v_precio_actual IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Producto no encontrado o inactivo';
    END IF;

    -- Verificar si el cambio es significativo (más del 20%)
    IF ABS(p_precio_nuevo - v_precio_actual) / v_precio_actual > 0.20 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Cambio de precio superior al 20% no permitido sin autorización';
    END IF;

    -- Actualizar precio
    UPDATE Productos
    SET Precio = p_precio_nuevo
    WHERE ID_Producto = p_id_producto;

    -- Confirmar transacción
    COMMIT;

    SET p_resultado = CONCAT('Precio actualizado exitosamente para: ', v_nombre_producto,
                           '. Precio anterior: $', FORMAT(v_precio_actual, 0),
                           ', Precio nuevo: $', FORMAT(p_precio_nuevo, 0));
END//

DELIMITER ;

-- ================================================
-- 7. EJEMPLOS DE USO Y PRUEBAS
-- ================================================

-- Ejemplo 1: Actualizar precio válido
CALL sp_ActualizarPrecioProducto(1, 900000.00, @resultado);
SELECT @resultado;

-- Ejemplo 2: Intentar precio inválido (debe fallar)
CALL sp_ActualizarPrecioProducto(1, -5000.00, @resultado_error);
SELECT @resultado_error;

-- Ejemplo 3: Verificar log de cambios
SELECT
    lcp.*,
    p.Nombre AS Producto
FROM Log_Cambios_Precios lcp
INNER JOIN Productos p ON lcp.ID_Producto = p.ID_Producto
ORDER BY lcp.Fecha_Cambio DESC;

-- ================================================
-- 8. CONSULTA DE VALIDACIÓN DE INTEGRIDAD
-- ================================================

-- Verificar que todas las restricciones se cumplen
SELECT
    'Productos con precio válido' AS Validacion,
    COUNT(*) AS Total,
    SUM(CASE WHEN Precio > 0 THEN 1 ELSE 0 END) AS Validos,
    SUM(CASE WHEN Precio <= 0 THEN 1 ELSE 0 END) AS Invalidos
FROM Productos

UNION ALL

SELECT
    'Productos con inventario válido' AS Validacion,
    COUNT(*) AS Total,
    SUM(CASE WHEN Cantidad_Inventario >= 0 THEN 1 ELSE 0 END) AS Validos,
    SUM(CASE WHEN Cantidad_Inventario < 0 THEN 1 ELSE 0 END) AS Invalidos
FROM Productos

UNION ALL

SELECT
    'Proveedores con email válido' AS Validacion,
    COUNT(*) AS Total,
    SUM(CASE WHEN Email IS NULL OR fn_ValidarEmail(Email) THEN 1 ELSE 0 END) AS Validos,
    SUM(CASE WHEN Email IS NOT NULL AND NOT fn_ValidarEmail(Email) THEN 1 ELSE 0 END) AS Invalidos
FROM Proveedores;
