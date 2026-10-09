# Konfigurasi Supabase Orbhita

Pegangan untuk tim aplikasi Flutter. Nilai di bawah aman dipakai di aplikasi; secret key tidak pernah ditaruh di Flutter maupun di repo.

## Project

| Item | Nilai |
| :---- | :---- |
| Project ID / ref | `nzrkinopvoelpjbwbvhg` |
| URL | `https://nzrkinopvoelpjbwbvhg.supabase.co` |
| Publishable key | `sb_publishable_71MJEpps4ph7_KMeP3bQWw_7VORodNJ` |
| Region | Southeast Asia (Singapore) |
| Postgres | 17 |

Publishable key memang untuk aplikasi klien; keamanannya bergantung pada RLS. `service_role` / secret key, `ANTHROPIC_API_KEY`, dan password database hanya disimpan di `.env` lokal (tidak di-commit) dan Supabase Secrets.

```dart
await Supabase.initialize(
  url: 'https://nzrkinopvoelpjbwbvhg.supabase.co',
  anonKey: 'sb_publishable_71MJEpps4ph7_KMeP3bQWw_7VORodNJ',
);
```

## Tabel

Semua tabel memakai RLS: pengguna hanya bisa membaca dan menulis baris miliknya (`owner_id = auth.uid()`). Kolom umum: `id`, `owner_id`, `created_at`, `updated_at`, `revision`, `deleted_at`.

| Tabel | Isi | Akses aplikasi |
| :---- | :---- | :---- |
| `profiles` | nama, `timezone` (default `Asia/Jakarta`), `locale` | baca, ubah |
| `preferences` | `study_windows` (`[{dow, start, end}]`, 1 = Senin), `max_daily_minutes`, `session_minutes`, `break_minutes`, `reminder_defaults` | baca, ubah |
| `tasks` | `title`, `course`, `requirements`, `official_deadline`, `personal_target`, `priority`, `work_status` | baca, tambah, ubah |
| `steps` | `task_id`, `title`, `order_index`, `estimate_minutes`, `remaining_minutes`, `status` | baca, tambah, ubah |
| `step_dependencies` | `task_id`, `step_id`, `depends_on_id` | baca, tambah, hapus |
| `activities` | kegiatan/jadwal: `title`, `start_at`, `end_at`, `busy`, `locked`, `source` | baca, tambah, ubah (acara Google hanya baca) |
| `plans` | versi rencana: `version`, `status`, `risk_summary`, `unscheduled` | baca |
| `sessions` | sesi kerja: `plan_id`, `task_id`, `step_id`, `start_at`, `end_at`, `status`, `is_active` | baca |
| `sources`, `proposals` | input dan draf hasil AI | baca |
| `owner_state`, `operations` | penanda versi data dan bukti idempotensi | baca |

Profil, preferensi, dan `owner_state` dibuat otomatis saat pengguna pertama kali login.

### Aturan menulis

- Hapus = isi `deleted_at`, bukan DELETE.
- Setiap UPDATE wajib mengirim `revision` terakhir yang dibaca. Jika data sudah diubah perangkat lain, server menolak dengan HTTP 409 `REVISION_CONFLICT`.
- Langkah dengan `status = 'done'` otomatis `remaining_minutes = 0`; `tasks.work_status` mengikuti status langkahnya.

## Fungsi (RPC)

Dipanggil dengan `supabase.rpc(nama, params: {...})`.

| Fungsi | Parameter | Hasil |
| :---- | :---- | :---- |
| `confirm_proposal` | `p_proposal_id`, `p_payload_hash`, `p_draft` (draf hasil koreksi), `p_operation_id` (UUID baru per aksi) | `{task_id | activity_id, warnings}` |
| `confirm_plan` | `p_plan_id`, `p_operation_id` | `{plan_id, version}`; 409 `STALE_PLAN` bila data berubah sejak usulan dibuat |
| `reject_plan` | `p_plan_id` | — |
| `set_session_status` | `p_session_id`, `p_status` (`in_progress`, `completed`, `postponed`), `p_revision` | `{session_id, status, revision}` |

## Edge Functions

Header `Authorization: Bearer <access token pengguna>`.

| Endpoint | Body | Hasil |
| :---- | :---- | :---- |
| `POST /functions/v1/extract` | `{operation_id, input_type: text|image|pdf|voice, text?, storage_paths?, requested_assistance[]}` | draf tugas dari Claude: `{source_id, proposal_id, payload_hash, proposal}` |
| `POST /functions/v1/plan-propose` | `{trigger, postpone?: {session_id, mode: manual|auto, start_at?}}` | usulan rencana: `{plan_id, version, sessions, diff, risk_summary, unscheduled, explanation}` |

Gambar/PDF diunggah dulu ke bucket privat `inputs` di path `{user_id}/{nama-file}`, lalu path-nya dikirim ke `extract`. File dihapus server setelah diproses.

Format error: `{error: {code, message, field_errors, retryable}, request_id}`.

## Google Login

Status: aktif dan sudah diuji (login pertama berhasil, profil/preferensi terbuat otomatis). Scope hanya `email` dan `profile`; tidak ada akses Calendar.

Aplikasi memakai login lewat browser dengan satu OAuth client **Web application** (`Orbhita Supabase`), sehingga berjalan di Android dan iOS tanpa client per platform:

```dart
await supabase.auth.signInWithOAuth(
  OAuthProvider.google,
  redirectTo: 'com.orbhita.app://login-callback',
);
```

Saat membangun aplikasi:

- Tambahkan `com.orbhita.app://login-callback` di Supabase → Authentication → URL Configuration → Redirect URLs (sesuaikan bila package name berbeda).
- Daftarkan scheme deep link itu di `AndroidManifest.xml` dan `Info.plist`.
- Consent screen masih berstatus Testing: hanya email yang terdaftar sebagai Test users yang bisa login (maks. 100).

Login native tanpa browser (paket `google_sign_in`) bisa ditambahkan nanti dengan membuat client Android (package name + SHA-1) dan iOS (bundle ID), lalu menambahkan client ID-nya ke kolom Client IDs di Supabase. Backend tidak perlu diubah.

### Setup awal (sudah dikerjakan)

1. Google Cloud Console → buat project → **OAuth consent screen**: tipe External, isi nama aplikasi, tambahkan email anggota tim sebagai *test users*.
2. **Credentials → Create credentials → OAuth client ID**:
   - **Web application**. Authorized redirect URI: `https://nzrkinopvoelpjbwbvhg.supabase.co/auth/v1/callback`. Simpan Client ID dan Client secret.
   - **Android** (setelah package name aplikasi ditetapkan): isi package name dan SHA-1 dari keystore debug/release.
   - **iOS**: isi bundle ID aplikasi.
3. Supabase Dashboard → **Authentication → Sign In / Providers → Google** → aktifkan, isi Client ID (web; client ID Android/iOS ditambahkan dipisah koma) dan Client secret → Save.
4. Login Google tidak otomatis memberi izin Google Calendar; izin kalender diminta terpisah di tahap integrasi Calendar.

## Akses tim

Supabase Dashboard → pilih organization → **Team** → **Invite** → masukkan email anggota, role **Developer** (bisa deploy, tidak bisa mengubah billing).
