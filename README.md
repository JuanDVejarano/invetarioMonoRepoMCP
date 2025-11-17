# invetarioMonoRepoMCP

Instrucciones rápidas para ejecutar el monorepo (pnpm workspace).

## Requisitos

-   pnpm >= 7 (se recomienda usar la versión indicada en package.json: pnpm@10.x)
-   Node.js compatible con tus dependencias

## Instalación (desde la raíz)

```bash
cd /home/juanj/invetarioMonoRepoMCP
pnpm install
```

## Ejecutar todos los servicios en modo desarrollo (paralelo)

```bash
pnpm run dev
# equivale a: pnpm -r --parallel run dev
```

## Ejecutar una app específica

-   API (Nest):

```bash
pnpm --filter api run dev
# o
pnpm --filter ./apps/api run dev
# o alias
pnpm -F api run dev
```

-   Un microservicio (ej. mcp-pedidos):

```bash
pnpm --filter mcp-pedidos run dev
```

## Ver scripts disponibles de un paquete

```bash
pnpm --filter api run
pnpm --filter mcp-pedidos run
```

-   Asegúrate de ejecutar los comandos desde la raíz del repo donde está `pnpm-workspace.yaml`.
-   Usa `pnpm --filter <name> run` para inspeccionar scripts disponibles antes de ejecutar.
