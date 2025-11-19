import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { pool, query } from "./BDClient.js";

// Tipos para el dominio
interface MaterialRequerido {
    idMateriaPrima: number;
    nombre: string;
    cantidadNecesaria: number;
    stockActual: number;
    faltante: number;
}

interface ProveedorOpcion {
    idProveedor: number;
    nombre: string;
    costoUnidad: number;
    costoTotal: number;
}

interface OrdenCompraDetalle {
    proveedor: string;
    materiales: Array<{
        nombre: string;
        cantidad: number;
        costoUnidad: number;
        costoTotal: number;
    }>;
    costoTotal: number;
}

// Create server instance
const server = new McpServer({
    name: "inventory-management",
    version: "1.0.0",
});

// Tool: Verificar disponibilidad de materiales para producir
server.tool(
    "verificar_materiales_producto",
    "Verifica si hay suficiente materia prima para fabricar una cantidad específica de un producto",
    {
        productId: z.number().describe("ID del producto a fabricar"),
        cantidad: z
            .number()
            .positive()
            .describe("Cantidad de productos a fabricar"),
    },
    async ({ productId, cantidad }) => {
        try {
            // Obtener información del producto
            const productoResult = await query(
                "SELECT nombre FROM producto WHERE id = $1",
                [productId]
            );

            if (productoResult.rows.length === 0) {
                return {
                    content: [
                        {
                            type: "text",
                            text: `Error: Producto con ID ${productId} no encontrado`,
                        },
                    ],
                };
            }

            const nombreProducto = productoResult.rows[0].nombre;

            // Obtener materiales requeridos
            const materialesResult = await query(
                `SELECT 
                    mp.id as id_materia_prima,
                    mp.nombre,
                    mpp.cantidad as cantidad_por_producto,
                    mp.stock as stock_actual,
                    (mpp.cantidad * $1) as cantidad_necesaria,
                    GREATEST(0, (mpp.cantidad * $1) - mp.stock) as faltante
                FROM materia_prima_producto mpp
                JOIN materia_prima mp ON mpp.fkMateriaPrima = mp.id
                WHERE mpp.fkProducto = $2`,
                [cantidad, productId]
            );

            const materiales = materialesResult.rows;
            const hayFaltantes = materiales.some((m: any) => m.faltante > 0);

            let resultado = {
                producto: nombreProducto,
                cantidadSolicitada: cantidad,
                materialesRequeridos: materiales.map((m: any) => ({
                    nombre: m.nombre,
                    cantidadNecesaria: parseFloat(m.cantidad_necesaria),
                    stockActual: m.stock_actual,
                    faltante: parseFloat(m.faltante),
                })),
                puedeProducir: !hayFaltantes,
            };

            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(resultado, null, 2),
                    },
                ],
            };
        } catch (error: any) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Error: ${error.message}`,
                    },
                ],
            };
        }
    }
);

// Tool: Generar opciones de órdenes de compra
server.tool(
    "generar_opciones_orden_compra",
    "Genera opciones de órdenes de compra para materiales faltantes (un proveedor vs óptimo por material)",
    {
        productId: z.number().describe("ID del producto"),
        cantidad: z
            .number()
            .positive()
            .describe("Cantidad de productos a fabricar"),
    },
    async ({ productId, cantidad }) => {
        try {
            // Obtener materiales faltantes
            const faltantesResult = await query(
                `SELECT 
                    mp.id as id_materia_prima,
                    mp.nombre,
                    GREATEST(0, (mpp.cantidad * $1) - mp.stock) as faltante
                FROM materia_prima_producto mpp
                JOIN materia_prima mp ON mpp.fkMateriaPrima = mp.id
                WHERE mpp.fkProducto = $2
                AND (mpp.cantidad * $1) > mp.stock`,
                [cantidad, productId]
            );

            const materialesFaltantes = faltantesResult.rows;

            if (materialesFaltantes.length === 0) {
                return {
                    content: [
                        {
                            type: "text",
                            text: "No hay materiales faltantes. La producción puede proceder.",
                        },
                    ],
                };
            }

            // Para cada material faltante, obtener proveedores y precios
            const opcionesPorMaterial: any = {};

            for (const material of materialesFaltantes) {
                const proveedoresResult = await query(
                    `SELECT 
                        p.nit as id_proveedor,
                        p.nombre,
                        pmp.costoUnidad,
                        (pmp.costoUnidad * $1) as costo_total
                    FROM proveedor_materia_prima pmp
                    JOIN proveedor p ON pmp.fkProveedor = p.nit
                    WHERE pmp.fkMateriaPrima = $2
                    ORDER BY pmp.costoUnidad ASC`,
                    [material.faltante, material.id_materia_prima]
                );

                opcionesPorMaterial[material.nombre] = {
                    cantidadFaltante: parseFloat(material.faltante),
                    proveedores: proveedoresResult.rows.map((p: any) => ({
                        idProveedor: p.id_proveedor,
                        nombre: p.nombre,
                        costoUnidad: parseFloat(p.costounidad),
                        costoTotal: parseFloat(p.costo_total),
                    })),
                };
            }

            // Estrategia 1: Un solo proveedor (el que tenga menor costo total)
            const proveedoresUnicos = new Set<number>();
            for (const material in opcionesPorMaterial) {
                opcionesPorMaterial[material].proveedores.forEach((p: any) => {
                    proveedoresUnicos.add(p.idProveedor);
                });
            }

            let mejorProveedorUnico: any = null;
            let menorCostoUnico = Infinity;

            for (const proveedorId of proveedoresUnicos) {
                let costoTotal = 0;
                let puedeProveerTodo = true;

                for (const material in opcionesPorMaterial) {
                    const opciones = opcionesPorMaterial[material].proveedores;
                    const opcionProveedor = opciones.find(
                        (p: any) => p.idProveedor === proveedorId
                    );

                    if (!opcionProveedor) {
                        puedeProveerTodo = false;
                        break;
                    }

                    costoTotal += opcionProveedor.costoTotal;
                }

                if (puedeProveerTodo && costoTotal < menorCostoUnico) {
                    menorCostoUnico = costoTotal;
                    const provInfo = await query(
                        "SELECT nombre FROM proveedor WHERE nit = $1",
                        [proveedorId]
                    );
                    mejorProveedorUnico = {
                        idProveedor: proveedorId,
                        nombre: provInfo.rows[0].nombre,
                        costoTotal,
                    };
                }
            }

            // Estrategia 2: Proveedor óptimo por material
            const ordenesOptimas: any[] = [];
            let costoTotalOptimo = 0;

            const proveedoresPorOrden: any = {};

            for (const material in opcionesPorMaterial) {
                const mejorOpcion =
                    opcionesPorMaterial[material].proveedores[0];

                if (!proveedoresPorOrden[mejorOpcion.idProveedor]) {
                    proveedoresPorOrden[mejorOpcion.idProveedor] = {
                        nombre: mejorOpcion.nombre,
                        materiales: [],
                        costoTotal: 0,
                    };
                }

                proveedoresPorOrden[mejorOpcion.idProveedor].materiales.push({
                    nombre: material,
                    cantidad: opcionesPorMaterial[material].cantidadFaltante,
                    costoUnidad: mejorOpcion.costoUnidad,
                    costoTotal: mejorOpcion.costoTotal,
                });

                proveedoresPorOrden[mejorOpcion.idProveedor].costoTotal +=
                    mejorOpcion.costoTotal;
                costoTotalOptimo += mejorOpcion.costoTotal;
            }

            for (const provId in proveedoresPorOrden) {
                ordenesOptimas.push(proveedoresPorOrden[provId]);
            }

            const resultado = {
                materialesFaltantes: Object.keys(opcionesPorMaterial).map(
                    (nombre) => ({
                        nombre,
                        cantidadFaltante:
                            opcionesPorMaterial[nombre].cantidadFaltante,
                    })
                ),
                estrategia1_unProveedor:
                    mejorProveedorUnico ||
                    "No hay un proveedor que tenga todos los materiales",
                estrategia2_optimoPorMaterial: {
                    ordenes: ordenesOptimas,
                    costoTotal: costoTotalOptimo,
                },
            };

            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(resultado, null, 2),
                    },
                ],
            };
        } catch (error: any) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Error: ${error.message}`,
                    },
                ],
            };
        }
    }
);

// Tool: Validar presupuesto disponible en caja
server.tool(
    "validar_presupuesto_caja",
    "Valida si hay suficiente dinero en caja para cubrir el costo de una orden de compra",
    {
        costoTotal: z
            .number()
            .positive()
            .describe("Costo total de la orden de compra"),
    },
    async ({ costoTotal }) => {
        try {
            const cajaResult = await query(
                "SELECT idCaja, capital FROM caja ORDER BY idCaja LIMIT 1"
            );

            if (cajaResult.rows.length === 0) {
                return {
                    content: [
                        {
                            type: "text",
                            text: "Error: No hay caja configurada en el sistema",
                        },
                    ],
                };
            }

            const caja = cajaResult.rows[0];
            const capitalDisponible = parseFloat(caja.capital);
            const hayFondos = capitalDisponible >= costoTotal;

            const resultado = {
                idCaja: caja.idcaja,
                capitalDisponible,
                costoRequerido: costoTotal,
                hayFondosSuficientes: hayFondos,
                diferencia: capitalDisponible - costoTotal,
            };

            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(resultado, null, 2),
                    },
                ],
            };
        } catch (error: any) {
            return {
                content: [
                    {
                        type: "text",
                        text: `Error: ${error.message}`,
                    },
                ],
            };
        }
    }
);

// Tool: Crear orden de compra
server.tool(
    "crear_orden_compra",
    "Crea una orden de compra para materiales específicos con validación de presupuesto",
    {
        usuarioId: z.number().describe("ID del usuario que crea la orden"),
        materiales: z
            .array(
                z.object({
                    materiaPrimaId: z.number(),
                    cantidad: z.number().positive(),
                })
            )
            .describe("Array de materiales con sus cantidades"),
    },
    async ({ usuarioId, materiales }) => {
        const client = await pool.connect();

        try {
            await client.query("BEGIN");

            // Calcular costo total
            let costoTotal = 0;
            for (const mat of materiales) {
                const costoResult = await client.query(
                    `SELECT pmp.costoUnidad 
                     FROM proveedor_materia_prima pmp 
                     WHERE pmp.fkMateriaPrima = $1 
                     ORDER BY pmp.costoUnidad ASC 
                     LIMIT 1`,
                    [mat.materiaPrimaId]
                );

                if (costoResult.rows.length === 0) {
                    throw new Error(
                        `No hay proveedor para materia prima ID ${mat.materiaPrimaId}`
                    );
                }

                costoTotal +=
                    parseFloat(costoResult.rows[0].costounidad) * mat.cantidad;
            }

            // Validar presupuesto
            const cajaResult = await client.query(
                "SELECT idCaja, capital FROM caja ORDER BY idCaja LIMIT 1"
            );

            if (cajaResult.rows.length === 0) {
                throw new Error("No hay caja configurada");
            }

            const capitalDisponible = parseFloat(cajaResult.rows[0].capital);

            if (capitalDisponible < costoTotal) {
                throw new Error(
                    `Fondos insuficientes. Disponible: ${capitalDisponible}, Requerido: ${costoTotal}`
                );
            }

            // Obtener ID del estado "Pendiente" (asumimos que existe)
            const estadoResult = await client.query(
                "SELECT id FROM estado_orden WHERE nombre = 'Pendiente' LIMIT 1"
            );

            if (estadoResult.rows.length === 0) {
                throw new Error(
                    "Estado 'Pendiente' no encontrado. Debe crearse primero."
                );
            }

            const estadoId = estadoResult.rows[0].id;

            // Crear orden de compra
            const ordenResult = await client.query(
                `INSERT INTO orden_compra (fkEstado, costoTotal, fkUsuario) 
                 VALUES ($1, $2, $3) 
                 RETURNING id`,
                [estadoId, costoTotal, usuarioId]
            );

            const ordenId = ordenResult.rows[0].id;

            // Crear detalles de la orden
            for (const mat of materiales) {
                await client.query(
                    `INSERT INTO detalle_orden_compra (fkOrdenCompra, fkMateriaPrima, cantidad) 
                     VALUES ($1, $2, $3)`,
                    [ordenId, mat.materiaPrimaId, mat.cantidad]
                );
            }

            await client.query("COMMIT");

            return {
                content: [
                    {
                        type: "text",
                        text: JSON.stringify(
                            {
                                success: true,
                                ordenId,
                                costoTotal,
                                mensaje: "Orden de compra creada exitosamente",
                            },
                            null,
                            2
                        ),
                    },
                ],
            };
        } catch (error: any) {
            await client.query("ROLLBACK");
            return {
                content: [
                    {
                        type: "text",
                        text: `Error al crear orden: ${error.message}`,
                    },
                ],
            };
        } finally {
            client.release();
        }
    }
);

// Start server
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("MCP Inventory Management Server running on stdio");
}

main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
