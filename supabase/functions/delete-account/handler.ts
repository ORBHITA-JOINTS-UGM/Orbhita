import { ApiError, ok, withErrors } from "../_shared/http.ts";

export interface DeleteAccountDeps {
  authUserId(req: Request): Promise<string>;
  beginDeletion(ownerId: string): Promise<void>;
  revokeCalendar(ownerId: string): Promise<void>;
  removeFiles(ownerId: string): Promise<void>;
  deleteAuthUser(ownerId: string): Promise<void>;
}

export function createDeleteAccountHandler(
  deps: DeleteAccountDeps,
): (req: Request) => Promise<Response> {
  return withErrors(async (req) => {
    if (req.method !== "POST") {
      throw new ApiError(405, "METHOD_NOT_ALLOWED", "Gunakan POST.");
    }

    const ownerId = await deps.authUserId(req);

    let body: unknown;
    try {
      body = await req.json();
    } catch {
      throw new ApiError(
        400,
        "INVALID_INPUT",
        "Body harus berupa JSON.",
      );
    }

    if (
      !body ||
      typeof body !== "object" ||
      Array.isArray(body) ||
      Object.keys(body).length !== 1 ||
      (body as Record<string, unknown>).confirmation !== "DELETE_MY_ACCOUNT"
    ) {
      throw new ApiError(
        400,
        "CONFIRMATION_REQUIRED",
        "Konfirmasi penghapusan akun diperlukan.",
        {
          fieldErrors: {
            confirmation: "Kirim DELETE_MY_ACCOUNT untuk menghapus akun.",
          },
        },
      );
    }

    await deps.beginDeletion(ownerId);

    try {
      await deps.revokeCalendar(ownerId);
      await deps.removeFiles(ownerId);
      await deps.deleteAuthUser(ownerId);
    } catch {
      throw new ApiError(
        503,
        "DELETION_INCOMPLETE",
        "Penghapusan belum selesai. Coba lagi untuk melanjutkan.",
        { retryable: true },
      );
    }

    const response = ok({ deleted: true });
    response.headers.set("Cache-Control", "no-store");
    return response;
  });
}
