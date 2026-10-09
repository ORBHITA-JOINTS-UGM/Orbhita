# Orbhita

Asisten akademik untuk mahasiswa: mengubah instruksi tugas menjadi langkah pengerjaan, menyusun sesi belajar, dan menyesuaikan rencana ketika kegiatan atau progres berubah.

Repo ini berisi backend Supabase (database, RLS, Edge Functions) dan nantinya aplikasi Flutter.

## Struktur

```
apps/mobile/              aplikasi Flutter (menyusul)
supabase/
  migrations/             skema, RLS, trigger, RPC
  functions/
    _shared/scheduler/    mesin jadwal deterministik
    _shared/claude/       prompt, schema, dan validasi proposal
    extract/              Edge Function: input tugas -> draf
    plan-propose/         Edge Function: usulan rencana sesi
  tests/                  uji SQL (RLS, constraint, RPC)
docs/design/              desain dan rencana implementasi
```

## Kebutuhan

- Node.js 20+
- Deno 2.x (`winget install DenoLand.Deno`)

```bash
npm install
```

## Menjalankan test

```bash
npm run test:deno
```

Dokumen desain: [docs/design/2026-10-08-backend-tahap1.md](docs/design/2026-10-08-backend-tahap1.md).
