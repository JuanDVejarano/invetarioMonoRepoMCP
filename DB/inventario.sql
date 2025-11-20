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
    nit BIGINT PRIMARY KEY,
    nombre VARCHAR(200) UNIQUE NOT NULL,
    direccion VARCHAR(200) NOT NULL,
    direccion2 VARCHAR(200) NULL,
    telefono VARCHAR(200) NOT NULL,
    telefono2 VARCHAR(200) NULL,
    correo VARCHAR(200) UNIQUE NOT NULL
);

CREATE TABLE proveedor_materia_prima (
    id BIGSERIAL PRIMARY KEY,
    fkProveedor BIGINT NOT NULL,
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
    capital DECIMAL(12,2) NOT NULL
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


CREATE OR REPLACE FUNCTION reset_Database()
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    -- Truncate all tables and reset serial sequences so IDs start from 1 again
    TRUNCATE TABLE
        historial_caja,
        caja,
        tipo_movimiento_caja,
        detalle_orden_compra,
        orden_compra,
        estado_orden,
        proveedor_materia_prima,
        proveedor,
        materia_prima_producto,
        materia_prima,
        detalle_venta,
        venta,
        producto,
        tipo_producto,
        cliente,
        usuario,
        rol,
        empleado
    RESTART IDENTITY CASCADE;

    -- Roles predeterminados
    INSERT INTO rol (nombreRol) VALUES
        ('Admin'),
        ('Cajero'),
        ('Bodeguero'),
        ('Vendedor'),
        ('Agente IA');
    
    -- Tipos de movimiento de caja
    INSERT INTO tipo_movimiento_caja (nombre, descripcion) VALUES
        ('Compra', 'Salida de dinero por compra de materiales'),
        ('Venta', 'Entrada de dinero por venta de productos');

    -- Caja inicial (valores en pesos colombianos - COP)
    INSERT INTO caja (capital) VALUES (40000000.00);

    -- Empleado de prueba
    INSERT INTO empleado (cedula, nombre, correo, direccion, ciudad, telefono, fecha_contratacion) VALUES
        (101010, 'IAInventarios', 'MCPInventario@admin.com', 'MCP server', 'MCP server', '101010', CURRENT_DATE),
        (123456789, 'Admin', 'admin@admin.com', 'Calle Falsa 123', 'Ciudad', '1234567890', CURRENT_DATE);

    -- Usuario de prueba (referencia el rol 'Admin' para obtener su id)
    INSERT INTO usuario (usuario, clave, fkRol, fkEmpleado) VALUES (
        'MCPInventarios',
        'asdfq*_&12AsD',
        (SELECT idRol FROM rol WHERE nombreRol = 'Agente IA' LIMIT 1),
        101010),
        (
        'admin',
        'admin',
        (SELECT idRol FROM rol WHERE nombreRol = 'Admin' LIMIT 1),
        123456789);

    -- Cliente de prueba
    INSERT INTO cliente (cedulaNit, nombre, correo, direccion, ciudad, telefono) VALUES
        (987654321, 'cliente', 'cliente@cliente.com', 'Calle Falsa 456', 'Ciudad', '0987654321');
    
    -- tipo de producto de prueba
    INSERT INTO tipo_producto (nombre, descripcion) VALUES
        ('Instrumental de corte', 'Herramientas diseñadas para incidir o seccionar tejidos con precisión durante procedimientos quirúrgicos.'),
        ('Instrumental de control', 'Dispositivos para sujetar, comprimir o controlar sangrado'),
        ('Instrumental de sutura', 'Herramientas utilizadas para cerrar heridas o incisiones mediante la aplicación de suturas durante procedimientos quirúrgicos.'),
        ('Instrumental de exploración', 'Herramientas utilizadas para examinar y explorar tejidos y cavidades del cuerpo humano durante procedimientos quirúrgicos.');
    
    -- Producto de prueba (precios en COP)
    INSERT INTO producto (nombre, fkTipo, caracteristicas, precio, stock) VALUES
        (
            'Bisturí quirúrgico',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de corte' LIMIT 1),
            'Bisturí de acero inoxidable con mango ergonómico y hoja desechable.',
            102000.00,
            150
        ),
        (
            'Pinza hemostática',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de control' LIMIT 1),
            'Pinza de acero inoxidable con mecanismo de bloqueo para controlar el sangrado durante cirugías.',
            63000.00,
            80
        ),
        (
            'Sutura quirúrgica',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de sutura' LIMIT 1),
            'Hilo de sutura absorbible de poliglactina con aguja de acero inoxidable.',
            40000.00,
            200
        ),
        (
            'Laringoscopio',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de exploración' LIMIT 1),
            'Instrumento de acero inoxidable utilizado para visualizar la laringe y las vías respiratorias durante procedimientos médicos.',
            120000.00,
            40
        ),
        (
            'Espejo quirúrgico',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de exploración' LIMIT 1),
            'Espejo de acero inoxidable con mango largo para explorar cavidades y áreas difíciles de ver.',
            49600.00,
            60
        ),
        (
            'Tijeras quirúrgicas',
            (SELECT id FROM tipo_producto WHERE nombre = 'Instrumental de corte' LIMIT 1),
            'Tijeras de acero inoxidable con punta roma para cortar tejidos durante procedimientos quirúrgicos.',
            89200.00,
            90
        );
    
    -- Materia prima de prueba
    INSERT INTO materia_prima (nombre, descripcion, stock) VALUES
        ('Acero inoxidable', 'Material resistente a la corrosión utilizado en la fabricación de instrumentos quirúrgicos.', 100),
        ('Polímero ABS', 'Material plástico utilizado en la fabricación de componentes duraderos y resistentes.', 50),
        ('Aleaciones de titanio', 'Materiales compuestos utilizados para mejorar las propiedades mecánicas y la resistencia a la corrosión en instrumentos quirúrgicos.', 200),
        ('Hilo: Poliglactina (Vicryl)', 'Hilo de sutura absorbible hecho de copolímero de ácido glicólico y ácido láctico.', 500),
        ('Aguja: Acero inoxidable', 'Aguja quirúrgica fabricada con acero inoxidable de alta calidad para garantizar resistencia y durabilidad.', 300),
        ('Fibra óptica (en modelos con luz)', 'Material utilizado en laringoscopios para proporcionar iluminación durante procedimientos médicos.', 80),
        ('LED o halógeno (en modelos con luz)', 'Fuente de luz utilizada en laringoscopios para mejorar la visibilidad durante procedimientos médicos.', 60),
        ('Conductores de cobre', 'Material utilizado en laringoscopios con luz para transmitir energía eléctrica a la fuente de luz.', 70),
        ('Lentes de vidrio o policarbonato', 'Material utilizado en espejos quirúrgicos para proporcionar una superficie reflectante clara y duradera.', 90),
        ('Mango de acero inoxidable o plástico', 'Componente del espejo quirúrgico que proporciona un agarre cómodo y seguro durante su uso.', 120),
        ('Hojas desechables de acero inoxidable', 'Hojas de bisturí fabricadas con acero inoxidable de alta calidad para garantizar cortes precisos y limpios.', 250),
        ('Mangos ergonómicos de plástico o metal', 'Mangos diseñados para proporcionar comodidad y control durante el uso del bisturí.', 150),
        ('Mecanismos de bloqueo de acero inoxidable', 'Componentes utilizados en pinzas hemostáticas para asegurar un agarre firme y seguro durante procedimientos quirúrgicos.', 180),
        ('Hilos de poliglactina', 'Hilos de sutura absorbibles fabricados con poliglactina para garantizar una cicatrización adecuada de las heridas.', 400),
        ('Agujas de acero inoxidable', 'Agujas quirúrgicas fabricadas con acero inoxidable de alta calidad para garantizar resistencia y durabilidad.', 350);
    
    -- Materia prima y productos asociados
    INSERT INTO materia_prima_producto (fkMateriaPrima, fkProducto, cantidad) VALUES
        ((SELECT id FROM materia_prima WHERE nombre = 'Acero inoxidable' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Bisturí quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Polímero ABS' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Bisturí quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Aleaciones de titanio' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Bisturí quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Hilo: Poliglactina (Vicryl)' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Sutura quirúrgica' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Aguja: Acero inoxidable' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Sutura quirúrgica' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Fibra óptica (en modelos con luz)' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Laringoscopio' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'LED o halógeno (en modelos con luz)' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Laringoscopio' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Conductores de cobre' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Laringoscopio' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Lentes de vidrio o policarbonato' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Espejo quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Mango de acero inoxidable o plástico' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Espejo quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Hojas desechables de acero inoxidable' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Bisturí quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Mangos ergonómicos de plástico o metal' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Bisturí quirúrgico' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Mecanismos de bloqueo de acero inoxidable' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Pinza hemostática' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Hilos de poliglactina' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Sutura quirúrgica' LIMIT 1), 1),
        ((SELECT id FROM materia_prima WHERE nombre = 'Agujas de acero inoxidable' LIMIT 1), (SELECT id FROM producto WHERE nombre = 'Sutura quirúrgica' LIMIT 1), 1);

    -- Proveedor de prueba
    INSERT INTO proveedor (nit, nombre, direccion, telefono, correo) VALUES
        (1122334455, 'Proveedor Medico S.A.S', 'Avenida Principal 789', '3216549870', 'correoPrueba1@ggg.com'),
        (2233445566, 'Suministros Quirúrgicos Ltda', 'Calle Secundaria 456', '6549873210', 'correoPrueba2@ggg.com'),
        (3344556677, 'Insumos Médicos Integrales', 'Carrera Tercera 123', '9873216540', 'correoPrueba3@ggg.com'),
        (4455667788, 'Distribuciones Hospitalarias S.A.', 'Avenida Cuarta 321', '1237894560', 'correoPrueba4@ggg.com'),
        (5566778899, 'Equipos Médicos Avanzados Ltda', 'Calle Quinta 654', '4561237890', 'correoPrueba5@ggg.com');
    
    -- Proveedor-Materia Prima de prueba (referencia materia_prima por nombre)
    INSERT INTO proveedor_materia_prima (fkProveedor, fkMateriaPrima, costoUnidad) VALUES
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Acero inoxidable' LIMIT 1), 5000.00),
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Polímero ABS' LIMIT 1), 8100.00),
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Aleaciones de titanio' LIMIT 1), 11900.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'Hilo: Poliglactina (Vicryl)' LIMIT 1), 3200.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'Aguja: Acero inoxidable' LIMIT 1), 2100.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'Fibra óptica (en modelos con luz)' LIMIT 1), 1400.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'LED o halógeno (en modelos con luz)' LIMIT 1), 2600.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'Conductores de cobre' LIMIT 1), 1750.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'Lentes de vidrio o policarbonato' LIMIT 1), 2300.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Mango de acero inoxidable o plástico' LIMIT 1), 1550.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Hojas desechables de acero inoxidable' LIMIT 1), 4100.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Mangos ergonómicos de plástico o metal' LIMIT 1), 3400.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Mecanismos de bloqueo de acero inoxidable' LIMIT 1), 4600.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Hilos de poliglactina' LIMIT 1), 2900.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Agujas de acero inoxidable' LIMIT 1), 3100.00),
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Acero inoxidable' LIMIT 1), 5200.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'Polímero ABS' LIMIT 1), 8000.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'Aleaciones de titanio' LIMIT 1), 12000.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Hilo: Poliglactina (Vicryl)' LIMIT 1), 3000.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Aguja: Acero inoxidable' LIMIT 1), 2000.00),
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Fibra óptica (en modelos con luz)' LIMIT 1), 1500.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'LED o halógeno (en modelos con luz)' LIMIT 1), 2500.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'Conductores de cobre' LIMIT 1), 1800.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Lentes de vidrio o policarbonato' LIMIT 1), 2200.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Mango de acero inoxidable o plástico' LIMIT 1), 1600.00),
        (1122334455, (SELECT id FROM materia_prima WHERE nombre = 'Hojas desechables de acero inoxidable' LIMIT 1), 4000.00),
        (2233445566, (SELECT id FROM materia_prima WHERE nombre = 'Mangos ergonómicos de plástico o metal' LIMIT 1), 3500.00),
        (3344556677, (SELECT id FROM materia_prima WHERE nombre = 'Mecanismos de bloqueo de acero inoxidable' LIMIT 1), 4500.00),
        (4455667788, (SELECT id FROM materia_prima WHERE nombre = 'Hilos de poliglactina' LIMIT 1), 2800.00),
        (5566778899, (SELECT id FROM materia_prima WHERE nombre = 'Agujas de acero inoxidable' LIMIT 1), 3200.00);

    -- Estado de ordenes de compra predeterminados
    INSERT INTO estado_orden (nombre, descripcion) VALUES
        ('Pendiente', 'Orden de compra creada pero no procesada'),
        ('En Proceso', 'Orden de compra en proceso de adquisición de materiales'),
        ('Completada', 'Orden de compra completada y materiales recibidos'),
        ('Cancelada', 'Orden de compra cancelada y no procesada');
END;
$$;

-- Ejecutar la función para reiniciar la base de datos y poblarla con datos iniciales
SELECT reset_Database();


-- borrar funcion
DROP FUNCTION reset_Database();

SELECT p.id AS idProducto, p.nombre AS nombreProducto, m.id AS idMateriaPrima, m.nombre AS nombreMateriaPrima FROM producto AS p INNER JOIN materia_prima_producto AS mp ON p.id = mp.fkProducto INNER JOIN materia_prima AS m ON mp.fkMateriaPrima = m.id;

SELECT * FROM producto;
SELECT * FROM materia_prima;
SELECT * FROM materia_prima_producto;