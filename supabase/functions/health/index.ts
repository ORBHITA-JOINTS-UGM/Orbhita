Deno.serve((req) => {
  if (req.method !== "GET") {
    return Response.json(
      { error: "Method not allowed" },
      { status: 405, headers: { Allow: "GET" } },
    );
  }

  return Response.json({
    status: "ok",
    service: "orbhita-backend",
    timestamp: new Date().toISOString(),
  });
});
