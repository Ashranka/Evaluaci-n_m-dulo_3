# Sistema de Gestión de Inventario
## Documentación Técnica Completa

---

## 📋 Índice
1. [Resumen Ejecutivo](#resumen-ejecutivo)
2. [Diseño del Modelo de Datos](#diseño-del-modelo-de-datos)
3. [Normalización Aplicada](#normalización-aplicada)
4. [Estructura de Base de Datos](#estructura-de-base-de-datos)
5. [Funcionalidades Implementadas](#funcionalidades-implementadas)
6. [Ejemplos de Consultas](#ejemplos-de-consultas)
7. [Manejo de Transacciones](#manejo-de-transacciones)
8. [Restricciones e Integridad](#restricciones-e-integridad)
9. [Rendimiento y Optimización](#rendimiento-y-optimización)
10. [Conclusiones y Recomendaciones](#conclusiones-y-recomendaciones)

---

## 1. Resumen Ejecutivo

Este documento presenta la implementación completa de un **Sistema de Gestión de Inventario** para una empresa de ventas, desarrollado utilizando principios de bases de datos relacionales, normalización hasta 3FN, y mejores prácticas de SQL.

### Objetivos Cumplidos
- ✅ Diseño conceptual usando modelo Entidad-Relación
- ✅ Transformación a modelo relacional normalizado
- ✅ Implementación completa en MySQL/SQL
- ✅ Manejo de transacciones ACID
- ✅ Consultas complejas con JOINs y subconsultas
- ✅ Restricciones de integridad referencial
- ✅ Triggers para automatización
- ✅ Procedimientos almacenados con manejo de errores

---

## 2. Diseño del Modelo de Datos

### 2.1 Entidades Principales

**Productos**
- Representa el catálogo de productos disponibles
- Atributos: ID, nombre, descripción, precio, cantidad en inventario
- Maneja el estado del producto (activo/inactivo/descontinuado)

**Proveedores**
- Información de empresas que suministran productos
- Atributos: ID, nombre, dirección, teléfono, email
- Control de estado del proveedor

**Transacciones**
- Registro histórico de todas las operaciones
- Tipos: COMPRA (aumenta inventario) y VENTA (disminuye inventario)
- Incluye auditoría completa con fechas y observaciones

**Producto_Proveedor**
- Resuelve la relación muchos-a-muchos entre productos y proveedores
- Almacena información específica como precios del proveedor y tiempos de entrega

### 2.2 Relaciones Identificadas

```
PRODUCTOS ←→ PRODUCTO_PROVEEDOR ←→ PROVEEDORES
    ↓              ↓                    ↓
TRANSACCIONES ←----+-----------------→ (M:N)
```

**Cardinalidades:**
- Un producto puede tener múltiples proveedores (1:N)
- Un proveedor puede suministrar múltiples productos (1:N)
- Una transacción involucra un producto y un proveedor (N:1)

---

## 3. Normalización Aplicada

### 3.1 Primera Forma Normal (1FN)
✅ **Cumplida completamente**
- Todas las tablas tienen claves primarias definidas
- No existen valores multivaluados en columnas individuales
- Todos los atributos contienen valores atómicos
- Eliminación de grupos repetidos

### 3.2 Segunda Forma Normal (2FN)
✅ **Cumplida completamente**
- Cumple 1FN
- Eliminación de dependencias parciales
- Todos los atributos no clave dependen completamente de la clave primaria
- Separación apropiada de entidades

### 3.3 Tercera Forma Normal (3FN)
✅ **Cumplida completamente**
- Cumple 2FN
- Eliminación de dependencias transitivas
- Cada atributo no clave depende únicamente de la clave primaria
- No hay redundancia innecesaria

### 3.4 Beneficios de la Normalización
- **Eliminación de redundancia**: Cada dato se almacena una sola vez
- **Integridad de datos**: Actualizaciones consistentes
- **Flexibilidad**: Fácil modificación de estructura
- **Eficiencia de almacenamiento**: Uso óptimo del espacio

---

## 4. Estructura de Base de Datos

### 4.1 Tablas Implementadas

| Tabla | Propósito | Registros Tipo |
|-------|-----------|----------------|
| `Productos` | Catálogo principal | 10 productos muestra |
| `Proveedores` | Directorio de proveedores | 5 proveedores activos |
| `Transacciones` | Historial completo | 15+ transacciones |
| `Producto_Proveedor` | Relaciones comerciales | 13 relaciones activas |
| `Log_Cambios_Precios` | Auditoría de precios | Automático |

---
## 4. Funcionalidades Implementadas

### 4.1 Gestión de Inventario Automatizada

**Triggers Implementados:**
- `tr_actualizar_inventario_compra`: Incrementa stock automáticamente
- `tr_actualizar_inventario_venta`: Decrementa stock con validación
- `tr_validar_email_proveedor`: Valida formato de emails
- `tr_prevenir_eliminacion_producto`: Protege datos con historial

### 4.2 Procedimientos Almacenados

**sp_RegistrarCompra()**
```sql
CALL sp_RegistrarCompra(
    1,           -- ID Producto
    1,           -- ID Proveedor  
    5,           -- Cantidad
    780000.00,   -- Precio
    'Observaciones',
    @resultado,
    @id_transaccion
);
```

**sp_RegistrarVenta()**
- Validación automática de stock
- Manejo de errores con ROLLBACK
- Actualización atómica de inventario

### 4.3 Funciones Personalizadas

- `fn_ValidarEmail()`: Validación de formato de correos
- `fn_CalcularMargen()`: Cálculo de rentabilidad
- `fn_ValidarStockMinimo()`: Verificación de disponibilidad

---
