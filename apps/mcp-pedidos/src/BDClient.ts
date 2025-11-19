import { Pool } from "pg";
import fs from "fs";
import path from "path";

// NO usar dotenv en MCPs - las variables vienen del entorno
const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
    throw new Error("DATABASE_URL no definido en las variables de entorno");
}

export const pool = new Pool({ connectionString });

export async function query(text: string, params?: any[]) {
    return pool.query(text, params);
}

export async function runSqlFile(relPath: string) {
    const file = path.resolve(process.cwd(), relPath);
    const sql = fs.readFileSync(file, "utf8");
    return pool.query(sql);
}
