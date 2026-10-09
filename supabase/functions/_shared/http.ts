export class ApiError extends Error {
  constructor(
    public status: number,
    public code: string,
    message: string,
    public opts: { fieldErrors?: Record<string, string>; retryable?: boolean; retryAfter?: number } = {},
  ) {
    super(message);
    this.name = "ApiError";
  }
}

const JSON_HEADERS = { "Content-Type": "application/json; charset=utf-8" };

export function ok(data: unknown, operationId?: string): Response {
  const body = operationId === undefined ? { data } : { data, operation_id: operationId };
  return new Response(JSON.stringify(body), { status: 200, headers: JSON_HEADERS });
}

export function fail(err: unknown, requestId: string): Response {
  const e = err instanceof ApiError
    ? err
    : new ApiError(500, "INTERNAL", "Terjadi kesalahan pada server.", { retryable: true });
  const headers: Record<string, string> = { ...JSON_HEADERS };
  if (e.opts.retryAfter !== undefined) headers["Retry-After"] = String(e.opts.retryAfter);
  const body = {
    error: {
      code: e.code,
      message: e.message,
      field_errors: e.opts.fieldErrors ?? {},
      retryable: e.opts.retryable ?? false,
    },
    request_id: requestId,
  };
  return new Response(JSON.stringify(body), { status: e.status, headers });
}

/** Wraps a handler with a request id and a uniform error envelope. Logs ids and codes only. */
export function withErrors(
  handler: (req: Request, requestId: string) => Response | Promise<Response>,
): (req: Request) => Promise<Response> {
  return async (req) => {
    const requestId = crypto.randomUUID();
    try {
      return await handler(req, requestId);
    } catch (err) {
      const code = err instanceof ApiError ? err.code : "INTERNAL";
      const name = err instanceof Error ? err.name : typeof err;
      console.error(JSON.stringify({ request_id: requestId, code, error: name }));
      return fail(err, requestId);
    }
  };
}
