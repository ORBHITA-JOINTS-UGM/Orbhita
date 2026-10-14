import type { SupabaseClient } from "../_shared/deps.ts";
import { supabaseDeleteAccountRepo } from "./repo.ts";

function assert(value: boolean, message: string) {
  if (!value) throw new Error(message);
}

async function rejects(action: () => Promise<void>) {
  let rejected = false;
  try {
    await action();
  } catch {
    rejected = true;
  }
  assert(rejected, "Operasi seharusnya gagal.");
}

function fixture(
  initial: string[],
  failure?: "list" | "remove" | "invalid-entry",
) {
  const files = new Set(initial);
  const removed: string[][] = [];

  const db = {
    storage: {
      from(bucket: string) {
        assert(bucket === "inputs", "Bucket harus inputs.");
        return {
          async list(
            folder: string,
            options: { limit: number; offset: number },
          ) {
            if (failure === "list") {
              return { data: null, error: new Error("list failed") };
            }
            if (failure === "invalid-entry") {
              return {
                data: [{ name: "../foreign.pdf", id: "file" }],
                error: null,
              };
            }

            const entries = new Map<
              string,
              { name: string; id: string | null }
            >();
            const prefix = `${folder}/`;

            for (const path of files) {
              if (!path.startsWith(prefix)) continue;
              const rest = path.slice(prefix.length);
              const name = rest.split("/")[0];
              entries.set(name, {
                name,
                id: rest.includes("/") ? null : path,
              });
            }

            const data = [...entries.values()]
              .sort((a, b) => a.name.localeCompare(b.name))
              .slice(options.offset, options.offset + options.limit);

            return { data, error: null };
          },

          async remove(paths: string[]) {
            if (failure === "remove") {
              return { data: null, error: new Error("remove failed") };
            }
            removed.push([...paths]);
            for (const path of paths) files.delete(path);
            return { data: [], error: null };
          },
        };
      },
    },
  } as unknown as SupabaseClient;

  return { files, removed, repo: supabaseDeleteAccountRepo(db) };
}

Deno.test("hapus file: semua batch dan folder bertingkat dibersihkan", async () => {
  const owner = "owner-a";
  const paths = Array.from(
    { length: 245 },
    (_, i) => `${owner}/file-${String(i).padStart(3, "0")}.pdf`,
  );
  paths.push(
    `${owner}/nested/photo.png`,
    `${owner}/nested/deeper/input.pdf`,
    "owner-b/private.pdf",
  );

  const f = fixture(paths);
  await f.repo.removeFiles(owner);

  assert(f.files.size === 1, "Semua file pemilik A harus terhapus.");
  assert(f.files.has("owner-b/private.pdf"), "File pemilik B harus tetap ada.");
  assert(f.removed.length === 3, "File harus dihapus dalam beberapa batch.");
  assert(
    f.removed.flat().every((path) => path.startsWith(`${owner}/`)),
    "Penghapusan harus dibatasi pada folder pemilik.",
  );
});

Deno.test("hapus file: folder kosong tidak memanggil remove", async () => {
  const f = fixture(["owner-b/private.pdf"]);
  await f.repo.removeFiles("owner-a");
  assert(f.removed.length === 0, "Tidak perlu menghapus file.");
  assert(f.files.size === 1, "File pengguna lain harus tetap ada.");
});

Deno.test("hapus file: gagal membaca Storage tidak dianggap selesai", async () => {
  const f = fixture(["owner-a/input.pdf"], "list");
  await rejects(() => f.repo.removeFiles("owner-a"));
  assert(f.removed.length === 0, "Tidak boleh menghapus tanpa daftar file.");
});

Deno.test("hapus file: gagal remove harus menghentikan proses", async () => {
  const f = fixture(["owner-a/input.pdf"], "remove");
  await rejects(() => f.repo.removeFiles("owner-a"));
  assert(f.files.has("owner-a/input.pdf"), "File masih ada setelah kegagalan.");
});

Deno.test("hapus file: entri path yang tidak valid ditolak", async () => {
  const f = fixture(["owner-b/private.pdf"], "invalid-entry");
  await rejects(() => f.repo.removeFiles("owner-a"));
  assert(f.removed.length === 0, "Path tidak valid tidak boleh dihapus.");
});
