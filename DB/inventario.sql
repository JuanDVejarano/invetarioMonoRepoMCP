CREATE TABLE empleado (
    cedula INT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    correo VARCHAR(200) UNIQUE NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    ciudad VARCHAR(200) NOT NULL,
    telefono VARCHAR(200) NOT NULL,
    telefono2 VARCHAR(200) NULL,
    fecha_contratacion DATE NOT NULL
);

CREATE TABLE rol (
    idRol SERIAL PRIMARY KEY,
    nombreRol VARCHAR(100) UNIQUE NOT NULL
);

CREATE TABLE usuario (
    idUsuario SERIAL PRIMARY KEY,
    usuario VARCHAR(100) UNIQUE NOT NULL,
    clave VARCHAR(100) NOT NULL,
    fkRol INT,
    fkEmpleado INT,
    FOREIGN KEY (fkRol) REFERENCES rol(idRol),
    FOREIGN KEY (fkEmpleado) REFERENCES empleado(cedula)
);

CREATE TABLE cliente (
    cedulaNit BIGINT PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    correo VARCHAR(200) UNIQUE NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    ciudad VARCHAR(200) NOT NULL,
    telefono VARCHAR(200) NOT NULL,
    telefono2 VARCHAR(200) NULL
);

CREATE TABLE tipo_producto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion VARCHAR(200) NULL
);

CREATE TABLE producto (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    fkTipo INT NOT NULL,
    caracteristicas VARCHAR(200) NULL,
    precio DECIMAL(10,2) NOT NULL,
    stock INT CHECK (stock >= 0) NOT NULL DEFAULT 0,
    FOREIGN KEY (fkTipo) REFERENCES tipo_producto(id)
);

CREATE TABLE venta (
    id BIGSERIAL PRIMARY KEY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    fkCliente BIGINT NOT NULL,
    fkUsuario INT NOT NULL,
    valorTotal DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (fkCliente) REFERENCES cliente(cedulaNit),
    FOREIGN KEY (fkUsuario) REFERENCES usuario(idUsuario)
);

CREATE TABLE detalle_venta (
    id BIGSERIAL PRIMARY KEY,
    fkVenta BIGINT NOT NULL,
    fkProducto INT NOT NULL,
    cantidad INT CHECK (cantidad > 0) NOT NULL,
    FOREIGN KEY (fkVenta) REFERENCES venta(id),
    FOREIGN KEY (fkProducto) REFERENCES producto(id)
);

CREATE TABLE materia_prima (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion VARCHAR(200) NULL,
    stock INT CHECK (stock >= 0) NOT NULL DEFAULT 0
);

CREATE TABLE materia_prima_producto (
    id BIGSERIAL PRIMARY KEY,
    fkMateriaPrima INT NOT NULL,
    fkProducto INT NOT NULL,
    cantidad INT CHECK (cantidad > 0) NOT NULL,
    FOREIGN KEY (fkMateriaPrima) REFERENCES materia_prima(id),
    FOREIGN KEY (fkProducto) REFERENCES producto(id)
);

CREATE TABLE proveedor (
    nit INT PRIMARY KEY,
    nombre VARCHAR(200) UNIQUE NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    direccion2 VARCHAR(200) NULL,
    telefono VARCHAR(200) NOT NULL,
    telefono2 VARCHAR(200) NULL,
    correo VARCHAR(200) UNIQUE NOT NULL
);

CREATE TABLE proveedor_materia_prima (
    id BIGSERIAL PRIMARY KEY,
    fkProveedor INT NOT NULL,
    fkMateriaPrima INT NOT NULL,
    costoUnidad DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (fkProveedor) REFERENCES proveedor(nit),
    FOREIGN KEY (fkMateriaPrima) REFERENCES materia_prima(id)
);

CREATE TABLE estado_orden (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion VARCHAR(200) NOT NULL
);

CREATE TABLE orden_compra (
    id BIGSERIAL PRIMARY KEY,
    fechaCreacion DATE NOT NULL DEFAULT CURRENT_DATE,
    fkEstado INT NOT NULL,
    fechaCierre DATE NULL,
    costoTotal DECIMAL(10,2) NOT NULL,
    fkUsuario INT NOT NULL,
    FOREIGN KEY (fkEstado) REFERENCES estado_orden(id),
    FOREIGN KEY (fkUsuario) REFERENCES usuario(idUsuario)
);

CREATE TABLE detalle_orden_compra (
    id BIGSERIAL PRIMARY KEY,
    fkOrdenCompra BIGINT NOT NULL,
    fkMateriaPrima INT NOT NULL,
    cantidad INT CHECK (cantidad > 0) NOT NULL,
    FOREIGN KEY (fkOrdenCompra) REFERENCES orden_compra(id),
    FOREIGN KEY (fkMateriaPrima) REFERENCES materia_prima(id)
);

CREATE TABLE caja (
    idCaja SERIAL PRIMARY KEY,
    capital DECIMAL(10,2) NOT NULL
);

CREATE TABLE tipo_movimiento_caja (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion VARCHAR(200) NOT NULL
);

CREATE TABLE historial_caja (
    id BIGSERIAL PRIMARY KEY,
    fkTipoMovimiento INT NOT NULL,
    fkCaja INT NOT NULL,
    fecha DATE NOT NULL,
    fkOrdenCompra BIGINT NULL,
    fkVenta BIGINT NULL,
    CHECK (
        (fkOrdenCompra IS NOT NULL AND fkVenta IS NULL) OR
        (fkOrdenCompra IS NULL AND fkVenta IS NOT NULL)
    ),
    FOREIGN KEY (fkTipoMovimiento) REFERENCES tipo_movimiento_caja(id),
    FOREIGN KEY (fkCaja) REFERENCES caja(idCaja),
    FOREIGN KEY (fkOrdenCompra) REFERENCES orden_compra(id),
    FOREIGN KEY (fkVenta) REFERENCES venta(id)
);