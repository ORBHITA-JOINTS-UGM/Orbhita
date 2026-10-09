# Orbhita

Asisten akademik untuk mahasiswa: mengubah instruksi tugas menjadi langkah pengerjaan, menyusun sesi belajar, dan menyesuaikan rencana ketika kegiatan atau progres berubah.

Repo ini berisi backend Supabase (database, RLS, Edge Functions). Aplikasi Flutter menyusul di `apps/mobile/`.

## Struktur

```
apps/mobile/              aplikasi Flutter (menyusul)
supabase/
  migrations/             skema, trigger, RLS, storage, RPC
  functions/
    _shared/scheduler/    mesin jadwal deterministik
    _shared/claude/       prompt, schema, dan validasi draf AI
    extract/              Edge Function: input tugas -> draf
    plan-propose/         Edge Function: usulan rencana sesi
  tests/                  uji SQL (RLS, constraint, RPC)
scripts/                  uji ujung-ke-ujung ke project yang sudah di-deploy
docs/design/              desain, rencana implementasi, konfigurasi project
```

Konfigurasi project untuk tim aplikasi (URL, publishable key, tabel, RPC, endpoint): [docs/design/supabase-config.md](docs/design/supabase-config.md).

## Kebutuhan

- Node.js 20+
- Deno 2.x (`winget install DenoLand.Deno`)

```bash
npm install
cp .env.example .env
```

Isi `.env` (file ini tidak ikut ke git):

| Variabel | Sumber |
| :---- | :---- |
| `SUPABASE_URL` | `https://<project-ref>.supabase.co` |
| `SUPABASE_ANON_KEY` | Project Settings → API Keys → publishable key |
| `SUPABASE_SERVICE_ROLE_KEY` | Project Settings → API Keys → secret / service_role |
| `SUPABASE_DB_URL` | tombol **Connect** → Session pooler → URI, password database tanpa kurung siku |
| `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys |
| `TEST_EMAIL`, `TEST_PASSWORD` | user uji (Authentication → Users → Add user) |

## Test

```bash
npm run test:deno
```

Uji unit mesin jadwal, validasi draf AI, klien Claude (dengan tiruan), validasi input, dan kedua handler Edge Function.

```bash
npm run test:sql
```

Uji database terhadap project Supabase: RLS dua akun, constraint, trigger, dan RPC. Setiap file dijalankan dalam transaksi yang selalu di-rollback, jadi tidak meninggalkan data.

## Deploy

```bash
npx supabase login
```

```bash
npx supabase link --project-ref nzrkinopvoelpjbwbvhg
```

```bash
npx supabase db push
```

```bash
npx supabase functions deploy extract
```

```bash
npx supabase functions deploy plan-propose
```

Secret untuk Edge Functions diisi lewat Dashboard → Edge Functions → Secrets (atau `npx supabase secrets set`):

- `ANTHROPIC_API_KEY`
- `CLAUDE_MODEL` = `claude-sonnet-5-5`
- `CLAUDE_EFFORT` = `medium`

`SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` sudah tersedia otomatis di Edge Functions.

## Uji ujung-ke-ujung

Setelah secret terisi dan user uji dibuat:

```bash
deno run -A --env-file=.env scripts/smoke.ts
```

Skrip login sebagai user uji, mengisi jam belajar, mengirim [contoh tugas](scripts/sample-task.txt) ke `extract`, mengonfirmasi draf, lalu meminta usulan rencana. Setiap panggilan ke Claude memakai kredit API.

## Batasan tahap 1

- Belum ada integrasi Google Calendar, reminder WhatsApp, sinkronisasi offline, dan hapus akun; semuanya direncanakan di tahap berikutnya.
- Transkripsi suara dilakukan di perangkat; backend menerima teksnya.
- Penjelasan risiko berupa teks templat dari hasil mesin jadwal.

Dokumen desain: [docs/design/2026-10-08-backend-tahap1.md](docs/design/2026-10-08-backend-tahap1.md).

## Endpoint health

Endpoint publik `GET /functions/v1/health` sudah diuji melalui curl
dan menghasilkan HTTP 200 dengan status "ok".
Endpoint ini tidak membaca data pengguna.

## Penggunaan AI

- ChatGPT membantu pembahasan arsitektur, setup Supabase, penulisan
  fungsi health, dan penelusuran error. Fungsi health diperiksa
  dan diuji oleh anggota tim melalui curl.
- Claude Code digunakan untuk membantu pengembangan backend tahap 1.
- Claude API digunakan dalam fitur ekstraksi instruksi tugas menjadi draf.
- Catatan ini diperbarui sesuai penggunaan AI dan pengujian yang dilakukan.
