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


