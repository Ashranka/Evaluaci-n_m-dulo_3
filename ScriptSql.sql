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


