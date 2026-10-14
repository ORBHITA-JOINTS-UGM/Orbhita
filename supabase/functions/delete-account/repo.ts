import type { SupabaseClient } from "../_shared/deps.ts";
import { check } from "../_shared/supabase.ts";
import { decryptToken } from "../_shared/google-calendar/crypto.ts";

const BUCKET = "inputs";

export function supabaseDeleteAccountRepo(db: SupabaseClient) {
  return {
    async beginDeletion(ownerId: string): Promise<void> {
      check(await db.rpc("begin_account_deletion", {
        p_owner_id: ownerId,
      }));
    },

    async revokeCalendar(ownerId: string): Promise<void> {
      const row = check(
        await db.from("google_calendar_connections")
          .select("refresh_token_encrypted")
          .eq("owner_id", ownerId)
          .maybeSingle(),
      ) as { refresh_token_encrypted: string } | null;

      if (!row) return;

      const token = await decryptToken(row.refresh_token_encrypted, ownerId);
      const response = await fetch("https://oauth2.googleapis.com/revoke", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
        },
        body: new URLSearchParams({ token }),
        redirect: "error",
        signal: AbortSignal.timeout(15_000),
      });

      if (response.ok) return;

      // Saat proses diulang, token mungkin sudah dicabut sebelumnya.
      if (response.status === 400) {
        const body = await response.json().catch(() => null);
        if (body?.error === "invalid_token") return;
      }
      throw new Error("calendar revocation failed");
    },

    async removeFiles(ownerId: string): Promise<void> {
      const root = ownerId;
      const prefix = `${ownerId}/`;

      async function collectBatch(): Promise<string[]> {
        const queue: Array<{ folder: string; offset: number }> = [
          { folder: root, offset: 0 },
        ];
        const paths: string[] = [];
        let calls = 0;

        while (queue.length && paths.length < 100) {
          if (++calls > 500) {
            throw new Error("storage traversal limit");
          }

          const current = queue.shift()!;
          const { data, error } = await db.storage.from(BUCKET).list(
            current.folder,
            {
              limit: 100,
              offset: current.offset,
              sortBy: { column: "name", order: "asc" },
            },
          );
          if (error || !data) throw new Error("storage list failed");

          for (const item of data) {
            if (
              !item.name ||
              item.name.includes("/") ||
              item.name === "." ||
              item.name === ".."
            ) {
              throw new Error("invalid storage entry");
            }

            const path = `${current.folder}/${item.name}`;
            if (!path.startsWith(prefix)) {
              throw new Error("invalid storage owner");
            }

            if (item.id) {
              paths.push(path);
              if (paths.length === 100) return paths;
            } else {
              queue.push({ folder: path, offset: 0 });
            }
          }

          if (data.length === 100) {
            queue.push({
              folder: current.folder,
              offset: current.offset + 100,
            });
          }
        }

        return paths;
      }

      // Setiap batch membaca ulang setelah penghapusan, tanpa melewati file.
      for (let batch = 0; batch < 20; batch++) {
        const paths = await collectBatch();
        if (!paths.length) return;

        const { error } = await db.storage.from(BUCKET).remove(paths);
        if (error) throw new Error("storage remove failed");
      }

      // Akun tetap terkunci; permintaan berikutnya melanjutkan pembersihan.
      throw new Error("storage cleanup needs another request");
    },

    async deleteAuthUser(ownerId: string): Promise<void> {
      const { error } = await db.auth.admin.deleteUser(ownerId, false);
      if (error) throw new Error("auth user deletion failed");
    },
  };
}
