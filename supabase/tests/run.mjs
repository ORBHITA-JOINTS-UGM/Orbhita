// Runs each supabase/tests/sql/*_test.sql inside a transaction that is always rolled back.
// Usage: npm run test:sql   (needs SUPABASE_DB_URL in .env)
import "dotenv/config";
import { readdir, readFile } from "node:fs/promises";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";
import postgres from "postgres";

const here = dirname(fileURLToPath(import.meta.url));
const sqlDir = join(here, "sql");

if (!process.env.SUPABASE_DB_URL) {
  console.error("SUPABASE_DB_URL belum diisi di .env");
  process.exit(1);
}

const sql = postgres(process.env.SUPABASE_DB_URL, { prepare: false, max: 1, onnotice: () => {} });
const helpers = await readFile(join(sqlDir, "_helpers.sql"), "utf8");
const only = process.argv[2];
const files = (await readdir(sqlDir)).filter((f) => f.endsWith("_test.sql") && (!only || f.includes(only))).sort();

let failed = 0;
for (const file of files) {
  const body = await readFile(join(sqlDir, file), "utf8");
  const conn = await sql.reserve();
  try {
    await conn.unsafe("begin");
    await conn.unsafe(helpers);
    await conn.unsafe(body);
    console.log(`PASS ${file}`);
  } catch (err) {
    failed++;
    console.log(`FAIL ${file}: ${err.message}`);
  } finally {
    await conn.unsafe("rollback").catch(() => {});
    conn.release();
  }
}

await sql.end();
console.log(`${files.length - failed}/${files.length} passed`);
process.exit(failed ? 1 : 0);
