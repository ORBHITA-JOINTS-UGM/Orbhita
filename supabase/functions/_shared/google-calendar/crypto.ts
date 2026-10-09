const encoder = new TextEncoder();
const decoder = new TextDecoder();

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, b => b.toString(16).padStart(2, "0")).join("");
}

function fromHex(value: string): Uint8Array<ArrayBuffer> {
  if (!value || value.length % 2 !== 0 || !/^[0-9a-f]+$/i.test(value)) {
    throw new Error("invalid encrypted token");
  }
  return Uint8Array.from(
    value.match(/.{2}/g)!,
    pair => parseInt(pair, 16),
  );
}

async function encryptionKey(): Promise<CryptoKey> {
  const hex = Deno.env.get("GOOGLE_CALENDAR_ENCRYPTION_KEY") ?? "";
  if (!/^[0-9a-f]{64}$/i.test(hex)) {
    throw new Error("invalid calendar encryption key");
  }
  return await crypto.subtle.importKey(
    "raw", fromHex(hex), "AES-GCM", false, ["encrypt", "decrypt"],
  );
}

// Token terikat ke pemiliknya melalui authenticated additional data.
export async function encryptToken(
  token: string,
  ownerId: string,
): Promise<string> {
  const key = await encryptionKey();
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const encrypted = await crypto.subtle.encrypt(
    { name: "AES-GCM", iv, additionalData: encoder.encode(ownerId) },
    key,
    encoder.encode(token),
  );
  return `v1.${toHex(iv)}.${toHex(new Uint8Array(encrypted))}`;
}

export async function decryptToken(
  value: string,
  ownerId: string,
): Promise<string> {
  const parts = value.split(".");
  if (parts.length !== 3 || parts[0] !== "v1") {
    throw new Error("invalid encrypted token");
  }
  const iv = fromHex(parts[1]);
  const encrypted = fromHex(parts[2]);
  if (iv.length !== 12 || encrypted.length < 16) {
    throw new Error("invalid encrypted token");
  }
  const key = await encryptionKey();
  const decrypted = await crypto.subtle.decrypt(
    { name: "AES-GCM", iv, additionalData: encoder.encode(ownerId) },
    key,
    encrypted,
  );
  return decoder.decode(decrypted);
}
