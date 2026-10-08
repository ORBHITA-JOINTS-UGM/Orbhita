# Backend Tahap 1 — Rencana Implementasi

**Tujuan:** Backend Supabase yang bisa menerima input tugas, membuat draf lewat Claude, menyimpan tugas setelah dikonfirmasi, menyusun usulan jadwal, dan mengaktifkan rencana.

**Arsitektur:** Postgres + RLS + RPC untuk data dan transaksi; Edge Functions (Deno/TypeScript) `extract` dan `plan-propose`. Logika inti (mesin jadwal, validasi proposal, validasi input) berupa modul murni di `supabase/functions/_shared/` yang diuji dengan `deno test`. Handler Edge Function menerima dependensi lewat parameter agar bisa diuji dengan tiruan.

**Stack:** Deno 2, TypeScript, Luxon, `@anthropic-ai/sdk`, `@supabase/supabase-js` v2, `pdf-lib`, Supabase CLI (lewat npm), Node + `postgres` untuk uji SQL.

**Spec:** `docs/design/2026-10-08-backend-tahap1.md` (dibaca bersama rencana ini).

## Batasan global

- Semua timestamp UTC; zona waktu IANA dari `profiles.timezone`, default `Asia/Jakarta`.
- Model dari env `CLAUDE_MODEL` (default `claude-sonnet-5-5`), effort dari `CLAUDE_EFFORT` (default `medium`).
- Batas input: teks 1–10.000 karakter; gambar JPG/PNG 1–5 file total ≤ 10 MB; PDF 1 file ≤ 10 MB ≤ 20 halaman, terenkripsi ditolak.
- Rate limit: 10 input / 10 menit / pengguna; satu `sources` `processing` per pengguna.
- Default preferensi: `max_daily_minutes` 120, `session_minutes` 25, `break_minutes` 5, horizon 30 hari.
- Proposal kedaluwarsa 24 jam. Prompt version awal `extract-v1`.
- Kode error dan HTTP status mengikuti tabel spec bagian 8. Error dari Postgres memakai SQLSTATE `PT4xx` agar PostgREST meneruskan status HTTP yang sama (mis. `PT409`), dengan `message` = kode error.
- Secret (`ANTHROPIC_API_KEY`, service role key, connection string) tidak pernah di-commit, tidak dicetak ke log, dan diisi sendiri oleh developer.
- Dependensi npm dipanggil dengan specifier `npm:` versi pasti, hanya lewat `supabase/functions/_shared/deps.ts`. Versi diambil dari `npm view <paket> version` saat Task 1.
- Pesan commit gaya conventional commits, tanpa baris atribusi tambahan.

## Fokus review

Kondisi yang tersirat di spec tetapi mudah terlewat; masing-masing punya test di task pemiliknya:

1. Jendela belajar melewati tengah malam (`22:00`–`01:00`) → dianggap berlanjut ke hari berikutnya, bukan dibuang. (Task 1)
2. Sisa slot terpotong-potong kurang dari 10 menit → tidak menghasilkan sesi sangat pendek; potongan itu dilewati. (Task 2)
3. Langkah yang prasyaratnya tidak teralokasi penuh → ikut tidak dijadwalkan, bukan dijadwalkan sebelum prasyaratnya. (Task 2)
4. Waktu relatif ("besok") dekat tengah malam → Claude menerima `reference_now` dalam waktu lokal pengguna beserta offset, bukan hanya UTC. (Task 4)
5. `extract` dipanggil ulang dengan `operation_id` sama setelah timeout → tidak membuat source/proposal ganda dan tidak memanggil Claude lagi. (Task 8)

---

### Task 1: Scaffold proyek dan slot kosong

**Files:**
- Create: `package.json`, `.env.example`, `README.md`, `supabase/config.toml` (lewat `npx supabase init`)
- Create: `supabase/functions/deno.json`, `supabase/functions/_shared/deps.ts`
- Create: `supabase/functions/_shared/scheduler/types.ts`, `supabase/functions/_shared/scheduler/slots.ts`
- Test: `supabase/functions/_shared/scheduler/slots_test.ts`

**Interfaces:**
- Produces (`types.ts`):
  ```ts
  export type Ms = number; // epoch milidetik UTC
  export interface Interval { start: Ms; end: Ms }
  export interface StudyWindow { dow: 1|2|3|4|5|6|7; start: string; end: string } // "HH:MM", 1 = Senin
  export interface Prefs { studyWindows: StudyWindow[]; maxDailyMinutes: number; sessionMinutes: number; breakMinutes: number }
  export type Priority = "high" | "normal" | "low";
  export type WorkStatus = "not_started" | "in_progress" | "done";
  export interface StepInput { id: string; title: string; orderIndex: number; remainingMinutes: number; status: WorkStatus; dependsOn: string[] }
  export interface TaskInput { id: string; title: string; officialDeadline: Ms | null; personalTarget: Ms | null; priority: Priority; createdAt: Ms; steps: StepInput[] }
  export interface FixedSession { taskId: string; stepId: string; start: Ms; end: Ms }
  export type PinnedSlot = FixedSession;
  export interface SchedulerInput { now: Ms; timezone: string; horizonDays: number; prefs: Prefs; busy: Interval[]; fixedSessions: FixedSession[]; tasks: TaskInput[]; pinned?: PinnedSlot[]; blocked?: Interval[] }
  export interface PlannedSession { taskId: string; stepId: string; start: Ms; end: Ms; pinned: boolean }
  export type Risk = "ok" | "target_risk" | "deadline_risk" | "overdue" | "missing_deadline";
  export interface TaskResult { taskId: string; risk: Risk; remainingMinutes: number; allocatedMinutes: number; unallocatedMinutes: number; capacityBeforeTarget: number | null; capacityBeforeDeadline: number | null; lastSessionEnd: Ms | null }
  export type UnscheduledReason = "missing_deadline" | "no_capacity" | "overdue" | "beyond_horizon" | "blocked_by_dependency";
  export interface Unscheduled { taskId: string; stepId: string | null; minutes: number; reason: UnscheduledReason }
  export interface SchedulerOutput { sessions: PlannedSession[]; perTask: TaskResult[]; unscheduled: Unscheduled[]; totals: { remainingMinutes: number; allocatedMinutes: number; unallocatedMinutes: number } }
  ```
- Produces (`slots.ts`):
  - `buildFreeSlots(args: { now: Ms; timezone: string; horizonDays: number; studyWindows: StudyWindow[]; busy: Interval[] }): Interval[]` — terurut, tidak tumpang tindih, dipotong di `now` dan di `now + horizonDays`.
  - `localDayKey(t: Ms, timezone: string): string` — `"yyyy-MM-dd"` di zona pengguna.
  - `subtractIntervals(base: Interval[], cut: Interval[]): Interval[]`
- Produces (`deps.ts`): re-export `DateTime` (Luxon), `Anthropic`, `createClient`, `PDFDocument`, dan assert dari `jsr:@std/assert`.

- [ ] **Step 1: Pasang tooling**

Run: `winget install --id DenoLand.Deno -e` lalu buka shell baru, `deno --version` → 2.x.
Run: `npm init -y`, `npm i -D supabase@<versi terbaru> postgres@<versi terbaru> dotenv@<versi terbaru>`, `npx supabase init` (jawab tidak untuk setelan VS Code).
Isi `package.json` scripts: `"test:deno": "deno test --allow-env --allow-read supabase/functions"`, `"test:sql": "node supabase/tests/run.mjs"`.
Isi `.env.example`: `SUPABASE_URL=`, `SUPABASE_ANON_KEY=`, `SUPABASE_SERVICE_ROLE_KEY=`, `SUPABASE_DB_URL=`, `ANTHROPIC_API_KEY=`, `CLAUDE_MODEL=claude-sonnet-5-5`, `CLAUDE_EFFORT=medium`.
`README.md` awal: deskripsi singkat, struktur folder, cara menjalankan test. (Diperluas di Task 10.)

- [ ] **Step 2: Tulis test gagal di `slots_test.ts`**

```ts
// 2026-10-08 adalah Kamis. Asia/Jakarta = UTC+7.
Deno.test("jendela Kamis 19:00-21:00 Jakarta menjadi 12:00-14:00 UTC", () => {
  const slots = buildFreeSlots({ now: utc("2026-10-08T00:00Z"), timezone: "Asia/Jakarta", horizonDays: 1,
    studyWindows: [{ dow: 4, start: "19:00", end: "21:00" }], busy: [] });
  assertEquals(slots, [{ start: utc("2026-10-08T12:00Z"), end: utc("2026-10-08T14:00Z") }]);
});
Deno.test("busy di tengah jendela memotong slot menjadi dua", ...);         // busy 19:30-20:00 → [19:00-19:30], [20:00-21:00]
Deno.test("slot yang sudah lewat dipotong di now", ...);                   // now 19:45 → [19:45-21:00]
Deno.test("jendela melewati tengah malam berlanjut ke hari berikutnya", ...); // Kamis 22:00-01:00 → Kamis 22:00 s.d. Jumat 01:00 lokal
Deno.test("zona ber-DST memakai offset yang benar di kedua sisi pergantian", ...); // Europe/Berlin 2026-10-25, jendela 09:00-10:00 Sabtu & Minggu → 07:00Z dan 08:00Z
Deno.test("tanpa jendela belajar hasilnya kosong", ...);
Deno.test("localDayKey memakai tanggal lokal", ...);                       // 2026-10-08T18:00Z di Jakarta → "2026-10-09"
```
`utc(s)` = helper `Date.parse` di file test.

- [ ] **Step 3: Jalankan test, pastikan gagal**

Run: `deno test supabase/functions/_shared/scheduler/slots_test.ts`
Expected: FAIL, `buildFreeSlots` belum ada.

- [ ] **Step 4: Implementasi `types.ts`, `slots.ts`, `deps.ts`**

Iterasi hari lokal dari `now` (mundur satu hari agar jendela lintas tengah malam dari hari sebelumnya ikut) sampai `now + horizonDays`; untuk tiap `StudyWindow` dengan `dow` cocok, bangun `DateTime.fromObject({...}, { zone })`; jika `end <= start`, tambahkan satu hari pada `end`. Gabungkan, kurangi `busy`, potong di `now` dan batas horizon.

- [ ] **Step 5: Jalankan test, pastikan lulus**

Run: `npm run test:deno` → semua PASS.

- [ ] **Step 6: Commit**

```bash
git add package.json package-lock.json .env.example README.md supabase/config.toml supabase/functions
git commit -m "feat(scheduler): free slot builder with timezone support"
```

---

### Task 2: Alokasi sesi dan risiko

**Files:**
- Create: `supabase/functions/_shared/scheduler/allocate.ts`, `supabase/functions/_shared/scheduler/mod.ts`
- Test: `supabase/functions/_shared/scheduler/allocate_test.ts`

**Interfaces:**
- Consumes: semua tipe dan fungsi Task 1.
- Produces: `planSchedule(input: SchedulerInput): SchedulerOutput` diekspor dari `scheduler/mod.ts` (bersama tipe-tipenya).

- [ ] **Step 1: Tulis test gagal di `allocate_test.ts`**

Helper test `windows(...)` dan `task(...)` di file test. Kasus wajib:

```ts
// TC08 skenario 1. Konfigurasi: sessionMinutes 120, breakMinutes 0, maxDailyMinutes 240.
// Kamis 2026-10-08 slot 19:00-21:00, Jumat 2026-10-09 slot 19:00-21:00 (Asia/Jakarta). now = Kamis 08:00.
// A: 90 menit, deadline Kamis 21:00. B: 150 menit, target Kamis 21:00, deadline Jumat 21:00.
Deno.test("TC08: kapasitas 120+120", () => {
  const out = planSchedule(tc08Input({ thursdayWindow: ["19:00", "21:00"] }));
  assertEquals(minutesOn(out, "A", "2026-10-08"), 90);
  assertEquals(minutesOn(out, "B", "2026-10-08"), 30);
  assertEquals(minutesOn(out, "B", "2026-10-09"), 120);
  assertEquals(result(out, "A").risk, "ok");
  assertEquals(result(out, "B").risk, "target_risk");
  assertEquals(out.totals.unallocatedMinutes, 0);
});
Deno.test("TC08: kapasitas Kamis tinggal 60", () => {
  const out = planSchedule(tc08Input({ thursdayWindow: ["20:00", "21:00"] }));
  assertEquals(result(out, "A").unallocatedMinutes, 30);
  assertEquals(result(out, "A").risk, "deadline_risk");
  assertEquals(minutesOn(out, "B", "2026-10-09"), 120);
  assertEquals(result(out, "B").unallocatedMinutes, 30);
  assertEquals(out.totals.unallocatedMinutes, 60);
  assert(out.perTask.every((r) => r.risk !== "ok"));
});
```
Kasus lain (nama test → assertion inti):
- `"sesi tidak melewati deadline"` → semua `end <= officialDeadline`.
- `"sesi tidak menabrak busy maupun sesi lain"` → tidak ada dua interval (sesi + busy) yang overlap.
- `"panjang sesi maksimal sessionMinutes dan diikuti jeda"` → 60 menit, session 25, break 5 → potongan 25/25/10 dengan selisih ≥ 5 menit antar-sesi.
- `"total harian tidak melewati maxDailyMinutes"` → cap 60, slot 180 → 60 menit per hari.
- `"langkah bergantung dijadwalkan setelah prasyaratnya selesai"` → `start(S2) >= end(last S1)`.
- `"prasyarat tidak teralokasi penuh membuat langkah berikutnya tidak dijadwalkan"` → S2 di `unscheduled` dengan reason `blocked_by_dependency`.
- `"potongan slot kurang dari 10 menit dilewati"` → slot 8 menit tidak dipakai bila sisa langkah 30.
- `"sisa langkah kurang dari 10 menit tetap dijadwalkan"` → sisa 5 menit menghasilkan sesi 5 menit.
- `"tugas tanpa deadline tidak dijadwalkan"` → risk `missing_deadline`, reason `missing_deadline`.
- `"deadline sudah lewat menjadi overdue tanpa sesi"`.
- `"deadline di luar horizon: sisa yang tidak muat diberi reason beyond_horizon"` → risk bukan `deadline_risk`.
- `"urutan: deadline lalu prioritas lalu createdAt"` → dua tugas deadline sama, `high` mendapat slot lebih awal.
- `"langkah done dilewati"`; `"fixedSessions dihitung ke batas harian dan tidak ditimpa"`.
- `"pinned dipakai apa adanya dan mengurangi sisa langkah"` → sesi pinned `pinned: true`.
- `"blocked tidak dipakai"`.
- `"deterministik"` → dua panggilan dengan input sama → `assertEquals` output.

- [ ] **Step 2: Jalankan test, pastikan gagal**

Run: `deno test supabase/functions/_shared/scheduler/allocate_test.ts` → FAIL.

- [ ] **Step 3: Implementasi `planSchedule` di `allocate.ts`**

```
1. free = buildFreeSlots(busy ∪ fixedSessions ∪ pinned ∪ blocked)
   dailyUsed[localDayKey] diisi dari fixedSessions dan pinned.
   Pinned langsung masuk sessions (pinned: true) dan mengurangi remaining langkahnya.
2. Tugas aktif = punya langkah status != done dengan remaining > 0.
   Tanpa deadline → missing_deadline. Deadline <= now → overdue (tanpa sesi).
   Sisanya diurutkan (deadline, priority high>normal>low, createdAt, id).
3. Per tugas, langkah dalam urutan topologis (tie-break orderIndex, id).
   earliest = max(now, end sesi terakhir tiap prasyarat). Jika prasyarat masih punya sisa
   tak teralokasi → langkah ini blocked_by_dependency.
4. Isi sisa: jalan di free slots terurut, mulai dari max(slot.start, earliest), selama < deadline:
     len = min(sessionMinutes, sisa, menit tersisa sampai min(slot.end, deadline), maxDaily - dailyUsed[hari])
     jika len < min(10, sisa) → lewati ke slot/hari berikutnya
     catat sesi; potong slot dari depan sebanyak len + breakMinutes; dailyUsed += len
   Sisa yang tidak muat: reason beyond_horizon jika deadline > now + horizon, selain itu no_capacity.
5. Risiko: overdue > deadline_risk (sisa no_capacity > 0) > target_risk (personalTarget ada dan
   lastSessionEnd > target atau masih ada sisa) > ok.
   capacityBeforeDeadline/Target = menit free slots (dengan batas harian) sebelum waktu tsb, dihitung dari free awal.
```

Hari untuk batas harian ditentukan dari `localDayKey(start)`; sesi tidak boleh menyeberang batas hari lokal (potong di tengah malam lokal).

- [ ] **Step 4: Jalankan test, pastikan lulus**

Run: `npm run test:deno` → PASS.

- [ ] **Step 5: Commit**

```bash
git add supabase/functions/_shared/scheduler
git commit -m "feat(scheduler): deterministic session allocation and risk"
```

---

### Task 3: Schema dan validasi proposal

**Files:**
- Create: `supabase/functions/_shared/claude/schema.ts`, `supabase/functions/_shared/claude/validate.ts`
- Test: `supabase/functions/_shared/claude/validate_test.ts`

**Interfaces:**
- Produces (`schema.ts`):
  ```ts
  export type Intent = "task" | "activity" | "clarification";
  export type Assistance = "requirements" | "steps" | "estimate" | "schedule" | "reminder";
  export interface Requirement { text: string; source_locator: string; source_excerpt: string }
  export interface TimePoint { at: string | null; original_text: string | null; needs_confirmation: boolean }
  export interface ProposalStep { client_step_id: string; title: string; estimate_minutes: number; estimate_basis: string; depends_on: string[] }
  export interface ProposalActivity { title: string; start_at: string; end_at: string; locked: boolean }
  export interface Proposal { schema_version: "1"; intent: Intent; title: string | null; course: string | null;
    requirements: Requirement[]; official_deadline: TimePoint; personal_target: TimePoint; steps: ProposalStep[];
    activity: ProposalActivity | null; requested_assistance: Assistance[]; assumptions: string[]; questions: string[];
    warnings: string[]; first_action: string | null; explanation: string }
  export const PROPOSAL_JSON_SCHEMA: Record<string, unknown>; // JSON Schema yang setara, additionalProperties: false, semua field required
  ```
- Produces (`validate.ts`):
  - `validateProposal(p: Proposal): { proposal: Proposal; errors: string[] }` — `errors` berisi pelanggaran berat yang memicu perbaikan; `proposal` sudah berisi koreksi ringan.

- [ ] **Step 1: Tulis test gagal**

- `"proposal valid lolos tanpa error dan tanpa perubahan"`.
- `"siklus dependensi menjadi error"` → `errors` memuat `"dependency_cycle"`.
- `"depends_on tidak dikenal menjadi error"` → `"unknown_dependency:s9"`.
- `"client_step_id ganda menjadi error"` → `"duplicate_step_id:s1"`.
- `"estimate_minutes di luar 1-600 menjadi error"`.
- `"activity end_at sebelum start_at menjadi error"`.
- `"deadline tanpa original_text diubah menjadi null dan ditanyakan"` → `official_deadline.at === null`, `questions` bertambah satu, `errors` kosong.
- `"target setelah deadline menambah warning"`.
- `"intent task tanpa title menjadi clarification"` → `intent === "clarification"`, `questions` menanyakan judul.
- `"PROPOSAL_JSON_SCHEMA mewajibkan semua field top-level"` → `required` berisi semua key `Proposal`.

- [ ] **Step 2: Jalankan, pastikan gagal** — `deno test supabase/functions/_shared/claude/validate_test.ts` → FAIL.

- [ ] **Step 3: Implementasi** `schema.ts` dan `validateProposal`. Deteksi siklus dengan DFS tiga warna. Teks pertanyaan/peringatan dalam bahasa Indonesia, mis. `"Kapan deadline resmi tugas ini?"`.

- [ ] **Step 4: Jalankan** `npm run test:deno` → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(ai): proposal schema and semantic validation"`

---

### Task 4: Klien ekstraksi Claude

**Files:**
- Create: `supabase/functions/_shared/claude/prompt.ts`, `supabase/functions/_shared/claude/extract.ts`
- Test: `supabase/functions/_shared/claude/extract_test.ts`

**Interfaces:**
- Consumes: `Proposal`, `PROPOSAL_JSON_SCHEMA`, `validateProposal` (Task 3).
- Produces:
  ```ts
  // prompt.ts
  export const PROMPT_VERSION = "extract-v1";
  export const SYSTEM_PROMPT: string; // statis, isi pokok sesuai spec 5.3
  export function buildUserContent(input: ExtractInput): unknown[]; // blok image/document lalu satu blok text
  // extract.ts
  export interface MediaPart { kind: "image" | "pdf"; mediaType: "image/jpeg" | "image/png" | "application/pdf"; base64: string }
  export interface ExtractInput { inputType: "text" | "image" | "pdf" | "voice"; text: string | null; media: MediaPart[];
    requestedAssistance: Assistance[]; referenceNow: number; timezone: string }
  export interface MessagesApi { create(params: Record<string, unknown>): Promise<any> } // subset klien SDK beta messages
  export type ExtractResult =
    | { ok: true; proposal: Proposal; usage: Record<string, number>; modelId: string; promptVersion: string }
    | { ok: false; code: "AI_REFUSED" | "AI_FAILED" | "AI_INVALID_OUTPUT"; message: string };
  export function extractProposal(api: MessagesApi, cfg: { model: string; effort: string }, input: ExtractInput): Promise<ExtractResult>;
  export function anthropicMessagesApi(apiKey: string): MessagesApi; // membungkus client.beta.messages dengan maxRetries 2
  ```

Sebelum menulis kode, baca contoh TypeScript resmi untuk structured output (`output_config.format`), adaptive thinking, dan `fallbacks: "default"` + beta `server-side-fallback-2026-07-01`; jangan menebak bentuk parameter.

- [ ] **Step 1: Tulis test gagal dengan `MessagesApi` tiruan**

- `"request memakai model, effort, schema, dan fallback dari konfigurasi"` → params yang direkam berisi `model`, `output_config.effort`, `output_config.format.schema === PROPOSAL_JSON_SCHEMA`, `fallbacks === "default"`, `system === SYSTEM_PROMPT`.
- `"system prompt tidak memuat waktu atau data pengguna"` → `SYSTEM_PROMPT` tidak mengandung `"2026"` maupun teks input.
- `"reference_now dikirim dalam waktu lokal dengan offset"` → untuk `referenceNow = 2026-10-08T17:30Z`, `timezone "Asia/Jakarta"`, blok teks memuat `"2026-10-09T00:30:00+07:00"` dan `"Asia/Jakarta"`.
- `"gambar dan PDF dikirim sebelum blok teks"`.
- `"respons valid menghasilkan ok dengan usage dan model"`.
- `"stop_reason refusal menghasilkan AI_REFUSED"`; `"stop_reason max_tokens menghasilkan AI_FAILED"`.
- `"output melanggar validasi dicoba perbaiki sekali"` → panggilan kedua memuat daftar error; respons kedua valid → `ok: true`; total 2 panggilan.
- `"masih tidak valid setelah perbaikan menghasilkan AI_INVALID_OUTPUT"` → total 2 panggilan.
- `"exception dari API menghasilkan AI_FAILED tanpa membocorkan detail"`.

- [ ] **Step 2: Jalankan, pastikan gagal.**

- [ ] **Step 3: Implementasi `prompt.ts` dan `extract.ts`.** Perbaikan: tambahkan giliran `assistant` berisi JSON sebelumnya lalu giliran `user` berisi daftar `errors` dan permintaan memperbaiki. `max_tokens` 16000.

- [ ] **Step 4: Jalankan** `npm run test:deno` → PASS.

- [ ] **Step 5: Commit** — `git commit -m "feat(ai): Claude extraction client with repair and refusal handling"`

---

### Task 5: Helper HTTP dan validasi input

**Files:**
- Create: `supabase/functions/_shared/http.ts`, `supabase/functions/_shared/hash.ts`, `supabase/functions/extract/input.ts`
- Test: `supabase/functions/_shared/http_test.ts`, `supabase/functions/extract/input_test.ts`

**Interfaces:**
- Consumes: `Assistance` (Task 3), `MediaPart` (Task 4).
- Produces (`http.ts`):
  ```ts
  export class ApiError extends Error { constructor(public status: number, public code: string, message: string,
    public opts?: { fieldErrors?: Record<string, string>; retryable?: boolean; retryAfter?: number }) }
  export function ok(data: unknown, operationId?: string): Response;          // 200 {data, operation_id}
  export function fail(err: unknown, requestId: string): Response;            // ApiError → envelope; lainnya → 500 tanpa detail
  export function withErrors(handler: (req: Request, requestId: string) => Promise<Response>): (req: Request) => Promise<Response>;
  ```
- Produces (`hash.ts`): `canonicalJson(v: unknown): string` (key terurut, rekursif), `sha256Hex(s: string): Promise<string>`.
- Produces (`input.ts`):
  ```ts
  export interface ExtractRequest { operationId: string; inputType: "text"|"image"|"pdf"|"voice"; text: string | null;
    storagePaths: string[]; requestedAssistance: Assistance[] }
  export function parseExtractRequest(body: unknown, userId: string): ExtractRequest;     // lempar ApiError 400/403
  export function checkMedia(inputType: "image" | "pdf", files: { path: string; bytes: Uint8Array }[]): Promise<MediaPart[]>; // lempar ApiError
  ```

- [ ] **Step 1: Tulis test gagal**

`http_test.ts`: `"ApiError menjadi envelope dengan status dan kode"`; `"error tak dikenal menjadi 500 tanpa pesan internal"`; `"canonicalJson tidak bergantung urutan key"`.
`input_test.ts`:
- `"teks kosong atau lebih dari 10000 karakter ditolak INVALID_INPUT"`.
- `"operation_id bukan UUID ditolak"`.
- `"path milik pengguna lain ditolak FORBIDDEN"` (403).
- `"image tanpa path atau lebih dari 5 file ditolak"`.
- `"magic bytes tidak cocok ditolak UNSUPPORTED_MEDIA"` → file `.jpg` berisi `%PDF`.
- `"total gambar lebih dari 10 MB ditolak PAYLOAD_TOO_LARGE"` (413).
- `"PDF lebih dari 20 halaman ditolak PDF_TOO_MANY_PAGES"` → PDF 21 halaman dibuat dengan pdf-lib di test.
- `"PDF terenkripsi ditolak PDF_ENCRYPTED"` → buat PDF dengan pdf-lib di test, lalu sisipkan entri `/Encrypt` ke trailer sebelum `%%EOF` (pdf-lib menolak memuat dokumen ber-`/Encrypt` tanpa `ignoreEncryption`).
- `"requested_assistance di luar enum ditolak"`.

- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi.** Magic bytes: JPEG `FF D8 FF`, PNG `89 50 4E 47`, PDF `25 50 44 46`. `withErrors` membuat `request_id` (UUID) dan hanya me-log `request_id`, kode error, dan nama exception; isi body, media, dan header Authorization tidak pernah di-log.
- [ ] **Step 4: Jalankan** `npm run test:deno` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(api): response envelope and extract input validation"`

---

### Task 6: Skema database, trigger, RLS, storage

**Prasyarat:** project Supabase sudah dibuat dan `.env` berisi `SUPABASE_DB_URL` (diisi developer). `npx supabase link --project-ref <ref>` sudah dijalankan.

**Files:**
- Create: `supabase/migrations/20261008000001_core_schema.sql`
- Create: `supabase/migrations/20261008000002_triggers.sql`
- Create: `supabase/migrations/20261008000003_rls_storage.sql`
- Create: `supabase/tests/run.mjs`, `supabase/tests/sql/_helpers.sql`
- Test: `supabase/tests/sql/schema_test.sql`, `supabase/tests/sql/rls_test.sql`

**Interfaces:**
- Produces: tabel `profiles`, `owner_state`, `preferences`, `sources`, `proposals`, `tasks`, `steps`, `step_dependencies`, `activities`, `plans`, `sessions`, `operations` persis seperti spec bagian 4; `owner_id default auth.uid()` pada tabel yang ditulis aplikasi; bucket `inputs`.
- Produces (test helpers, hanya hidup di transaksi test): `tests.create_user(email text) returns uuid`, `tests.as_user(uid uuid)`, `tests.as_admin()`, `tests.expect_error(sql text, code text)`.
- `run.mjs`: untuk setiap file di `supabase/tests/sql/*_test.sql`, buka koneksi `SUPABASE_DB_URL`, jalankan `BEGIN`, `_helpers.sql`, file test, lalu `ROLLBACK`; cetak PASS/FAIL per file; exit code 1 jika ada yang gagal.

- [ ] **Step 1: Tulis `_helpers.sql`, `run.mjs`, dan test gagal**

`schema_test.sql` (blok `DO $$ ... $$` dengan `RAISE EXCEPTION` bila assertion gagal):
- user baru → otomatis punya baris `profiles`, `preferences`, `owner_state`.
- update `tasks` dengan `revision` lama → error `REVISION_CONFLICT`; dengan revision benar → revision naik 1.
- `steps.status = 'done'` → `remaining_minutes` menjadi 0; semua langkah done → `tasks.work_status = 'done'`.
- insert dependensi yang membentuk siklus → error `DEPENDENCY_CYCLE`; dependensi lintas tugas → error.
- perubahan `tasks`/`steps`/`activities`/`preferences` menaikkan `owner_state.data_version`.
- dua sesi aktif overlap milik owner sama → exclusion violation; milik owner berbeda → boleh; satu tidak aktif → boleh.
- `activities` dengan `end_at <= start_at` → check violation; update baris `source = 'google'` sebagai user → ditolak.

`rls_test.sql`:
- user B tidak bisa SELECT/UPDATE task, step, activity, proposal, plan, session milik A (0 baris).
- user B tidak bisa INSERT step ke `task_id` milik A (FK komposit / RLS).
- user tidak bisa INSERT/UPDATE `proposals`, `plans`, `sessions`, `sources`, `operations`, `owner_state`.
- user tidak bisa DELETE fisik `tasks`.
- storage: user B tidak bisa SELECT/INSERT objek berprefix `<uid A>/` di bucket `inputs`.

- [ ] **Step 2: Jalankan, pastikan gagal** — `npm run test:sql` → FAIL (tabel belum ada).

- [ ] **Step 3: Tulis tiga migration sesuai spec 4.1–4.3.** Error trigger memakai `raise exception 'REVISION_CONFLICT' using errcode = 'PT409'` (siklus: `'DEPENDENCY_CYCLE'`, `PT422`). Fungsi trigger `security definer` dengan `set search_path = ''`. Ekstensi `btree_gist`. Bucket: `insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values ('inputs','inputs',false,10485760, array['image/jpeg','image/png','application/pdf'])`.

- [ ] **Step 4: Terapkan dan uji**

Run: `npx supabase db push` → migration diterapkan tanpa error.
Run: `npm run test:sql` → `schema_test.sql PASS`, `rls_test.sql PASS`.

- [ ] **Step 5: Commit** — `git commit -m "feat(db): core schema, triggers, RLS and storage policies"`

---

### Task 7: RPC transaksi

**Files:**
- Create: `supabase/migrations/20261008000004_rpc.sql`
- Test: `supabase/tests/sql/rpc_test.sql`

**Interfaces:**
- Consumes: tabel Task 6.
- Produces (semua `security definer`, `set search_path = ''`, `grant execute ... to authenticated`):
  - `confirm_proposal(p_proposal_id uuid, p_payload_hash text, p_draft jsonb, p_operation_id uuid) returns jsonb` → `{"task_id": uuid}` atau `{"activity_id": uuid}`, plus `"warnings": []`.
  - `confirm_plan(p_plan_id uuid, p_operation_id uuid) returns jsonb` → `{"plan_id": uuid, "version": int}`.
  - `reject_plan(p_plan_id uuid) returns void`.
  - `set_session_status(p_session_id uuid, p_status text, p_revision int) returns jsonb` → `{"session_id", "status", "revision"}`.
  - Error: `PROPOSAL_STALE` (`PT409`), `STALE_PLAN` (`PT409`), `OPERATION_REUSED` (`PT409`), `NOT_FOUND` (`PT404`), `INVALID_INPUT` (`PT400`).

- [ ] **Step 1: Tulis test gagal `rpc_test.sql`**

- `confirm_proposal` dengan hash benar → task + 3 steps + 1 dependency tersimpan dengan pemetaan `client_step_id` benar; proposal `confirmed`.
- ulang dengan `operation_id` sama → hasil sama, tidak ada task kedua.
- `operation_id` sama dengan payload berbeda → `OPERATION_REUSED`.
- hash salah / proposal kedaluwarsa / sudah confirmed → `PROPOSAL_STALE`.
- proposal milik user lain → `NOT_FOUND`.
- draft tanpa deadline → task tersimpan dengan `official_deadline` null.
- draft target setelah deadline → `warnings` tidak kosong.
- `confirm_plan`: rencana aktif lama `superseded`, sesinya non-aktif kecuali yang `completed`/`in_progress`; rencana baru `active`.
- `confirm_plan` dengan `base_plan_version` berbeda → `STALE_PLAN`; setelah `tasks` berubah (data_version naik) → `STALE_PLAN`.
- `reject_plan` → status `rejected`, rencana aktif tetap.
- `set_session_status`: `planned → in_progress → completed` berhasil; `completed → planned` → `INVALID_INPUT`; revision lama → `REVISION_CONFLICT`.

- [ ] **Step 2: Jalankan, pastikan gagal** — `npm run test:sql` → `rpc_test.sql FAIL`.
- [ ] **Step 3: Tulis migration RPC.** Idempotensi: `request_hash = md5(p_draft::text || p_payload_hash)` untuk `confirm_proposal`, `md5(p_plan_id::text)` untuk `confirm_plan`. Di `confirm_plan`, nonaktifkan sesi lama sebelum mengaktifkan sesi baru agar exclusion constraint tidak terpicu.
- [ ] **Step 4: Terapkan dan uji** — `npx supabase db push`, lalu `npm run test:sql` → semua PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(db): transactional RPCs for proposals, plans and sessions"`

---

### Task 8: Edge Function `extract`

**Files:**
- Create: `supabase/functions/extract/handler.ts`, `supabase/functions/extract/repo.ts`, `supabase/functions/extract/index.ts`
- Test: `supabase/functions/extract/handler_test.ts`

**Interfaces:**
- Consumes: `parseExtractRequest`, `checkMedia` (Task 5); `extractProposal`, `anthropicMessagesApi`, `PROMPT_VERSION` (Task 4); `canonicalJson`, `sha256Hex`, `ok`, `withErrors`, `ApiError` (Task 5).
- Produces:
  ```ts
  export interface ExtractRepo {
    findOperation(userId: string, operationId: string): Promise<{ requestHash: string; response: unknown } | null>;
    countSourcesSince(userId: string, since: number): Promise<number>;
    hasProcessing(userId: string): Promise<boolean>;
    getTimezone(userId: string): Promise<string>;
    insertSource(userId: string, s: { inputType: string; text: string | null; storagePaths: string[] }): Promise<string>;
    finishSource(sourceId: string, status: "completed" | "failed", errorCode: string | null): Promise<void>;
    markMediaCleaned(sourceId: string): Promise<void>;
    insertProposal(userId: string, p: { sourceId: string; payload: Proposal; payloadHash: string; modelId: string; promptVersion: string; usage: unknown }): Promise<string>;
    saveOperation(userId: string, operationId: string, requestHash: string, response: unknown): Promise<void>;
  }
  export interface ExtractDeps { authUserId(req: Request): Promise<string>; repo: ExtractRepo;
    storage: { download(path: string): Promise<Uint8Array>; remove(paths: string[]): Promise<void> };
    extract(input: ExtractInput): Promise<ExtractResult>; now(): number }
  export function createExtractHandler(deps: ExtractDeps): (req: Request) => Promise<Response>;
  ```
  `repo.ts` mengimplementasikan `ExtractRepo` dengan klien service role; setiap query memfilter `owner_id = userId`. `insertProposal` mengisi `status = 'proposed'`, `intent` dari payload, `expires_at = now() + 24 jam`, dan menyupersede proposal `proposed` lain milik source yang sama. `index.ts` merangkai deps nyata dan `Deno.serve(withErrors(...))`.

- [ ] **Step 1: Tulis test gagal dengan deps tiruan**

- `"teks valid menghasilkan proposal tersimpan dan respons 200"` → body berisi `source_id`, `proposal_id`, `payload_hash`, `proposal`.
- `"operation_id sama dipanggil ulang mengembalikan respons tersimpan tanpa memanggil Claude"` → `extract` dipanggil sekali, `insertSource` sekali.
- `"operation_id sama dengan body berbeda ditolak OPERATION_REUSED"`.
- `"lebih dari 10 input dalam 10 menit ditolak RATE_LIMITED dengan retry_after"`.
- `"sudah ada source processing ditolak RATE_LIMITED"`.
- `"media dihapus dari storage saat Claude gagal"` → `storage.remove` dipanggil, `finishSource(..., "failed", "AI_FAILED")`, respons 502.
- `"media dihapus dari storage saat berhasil"` dan `markMediaCleaned` dipanggil.
- `"tanpa JWT valid ditolak UNAUTHENTICATED"`.
- `"timezone pengguna diteruskan ke extract"`.

- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** `handler.ts` (urutan sesuai spec bagian 5; penghapusan media di `finally`), `repo.ts`, `index.ts`. `requestHash` = `sha256Hex(canonicalJson(body))`.
- [ ] **Step 4: Jalankan** `npm run test:deno` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(api): extract edge function"`

---

### Task 9: Edge Function `plan-propose`

**Files:**
- Create: `supabase/functions/plan-propose/load.ts`, `postpone.ts`, `diff.ts`, `explain.ts`, `handler.ts`, `repo.ts`, `index.ts`
- Test: `supabase/functions/plan-propose/load_test.ts`, `postpone_test.ts`, `diff_test.ts`, `explain_test.ts`, `handler_test.ts`

**Interfaces:**
- Consumes: `planSchedule`, `buildFreeSlots`, `localDayKey`, tipe scheduler (Task 1–2); helper HTTP (Task 5).
- Produces:
  ```ts
  // load.ts — memetakan baris DB ke input mesin
  export interface PlanRows { profile: { timezone: string }; prefs: { study_windows: StudyWindow[]; max_daily_minutes: number; session_minutes: number; break_minutes: number };
    tasks: any[]; steps: any[]; dependencies: { step_id: string; depends_on_id: string }[]; activities: any[]; activeSessions: any[] }
  export function toSchedulerInput(rows: PlanRows, now: number): SchedulerInput; // abaikan deleted_at; busy = activities busy||locked; fixed = sesi aktif in_progress/completed
  // postpone.ts
  export type PostponeCheck = { ok: true; pinned: PinnedSlot } | { ok: false; reason: "outside_study_window" | "overlaps_busy" | "after_deadline" | "daily_cap" | "in_past" };
  export function checkManualSlot(input: SchedulerInput, session: { taskId: string; stepId: string; start: number; end: number }, newStart: number): PostponeCheck;
  // diff.ts
  export interface PlanDiff { added: PlannedSession[]; moved: { from: PlannedSession; to: PlannedSession }[]; removed: PlannedSession[]; affectedTaskIds: string[] }
  export function diffPlans(active: PlannedSession[], proposed: PlannedSession[]): PlanDiff; // dipasangkan per stepId berurutan waktu
  // explain.ts
  export function explainPlan(out: SchedulerOutput, titles: Record<string, string>, timezone: string): string;
  // handler.ts
  export interface PlanRepo { load(userId: string): Promise<PlanRows & { activePlanVersion: number; dataVersion: number; maxVersion: number }>;
    saveProposal(userId: string, plan: { version: number; basePlanVersion: number; baseDataVersion: number; trigger: string; riskSummary: unknown; unscheduled: unknown }, sessions: PlannedSession[]): Promise<string>; }
  export function createPlanProposeHandler(deps: { authUserId(req: Request): Promise<string>; repo: PlanRepo; now(): number }): (req: Request) => Promise<Response>;
  ```
  `saveProposal` menyupersede usulan `proposed` lama dalam operasi yang sama.

- [ ] **Step 1: Tulis test gagal**

- `load_test`: `"tugas terhapus diabaikan"`, `"aktivitas busy atau locked menjadi busy"`, `"aktivitas tidak busy dan tidak locked tidak memblokir"`, `"sesi aktif completed menjadi fixedSessions"`, `"dependensi dipetakan ke dependsOn"`.
- `postpone_test`: tiap `reason` punya satu kasus; slot valid → `ok: true` dengan durasi sama dengan sesi asal.
- `diff_test`: `"sesi sama tidak muncul di diff"`, `"sesi bergeser muncul di moved"`, `"affectedTaskIds unik dan terurut"`.
- `explain_test`: `"menyebut tugas yang kurang waktu beserta menitnya"` → memuat `"kurang 30 menit"`; `"tanpa risiko menyebut semua teralokasi"`; `"tugas tanpa deadline diminta dilengkapi"`.
- `handler_test`:
  - `"tanpa jendela belajar ditolak NO_STUDY_WINDOWS"` (422).
  - `"postpone manual bentrok ditolak SLOT_CONFLICT dengan reason"`.
  - `"postpone auto memblokir slot lama"` → sesi langkah itu tidak lagi berada di interval lama.
  - `"versi usulan = maxVersion + 1 dan base sesuai state"`.
  - `"respons memuat plan_id, sessions, diff, risk_summary, unscheduled, explanation"`.

- [ ] **Step 2: Jalankan, pastikan gagal.**
- [ ] **Step 3: Implementasi** semua file. Teks `explainPlan` bahasa Indonesia, angka menit dan tanggal lokal (`ccc d LLL HH:mm`, locale `id`).
- [ ] **Step 4: Jalankan** `npm run test:deno` → PASS.
- [ ] **Step 5: Commit** — `git commit -m "feat(api): plan-propose edge function with postpone support"`

---

### Task 10: Deploy, smoke test, dan README

**Files:**
- Create: `scripts/smoke-extract.ts`, `supabase/functions/extract/testdata/sample-task.txt`
- Modify: `README.md`, `supabase/config.toml` (`[functions.extract]` dan `[functions.plan-propose]` dengan `verify_jwt = true`)

**Interfaces:**
- Consumes: semua task sebelumnya.

- [ ] **Step 1: Developer mengisi secret** (dijalankan sendiri, tidak lewat asisten):
  `npx supabase secrets set ANTHROPIC_API_KEY=... CLAUDE_MODEL=claude-sonnet-5-5 CLAUDE_EFFORT=medium`
- [ ] **Step 2: Deploy** — `npx supabase functions deploy extract` dan `npx supabase functions deploy plan-propose` → keduanya `Deployed`.
- [ ] **Step 3: Smoke test** — `scripts/smoke-extract.ts` login sebagai user test (token dari `.env`), memanggil `extract` dengan `sample-task.txt`, satu JPG, dan satu PDF; mencetak status, latensi, token usage, dan judul/deadline hasil. Run: `deno run -A scripts/smoke-extract.ts`. Expected: tiga respons 200, latensi dicatat di README bagian "Hasil uji".
- [ ] **Step 4: Lengkapi README:** prasyarat (spec bagian 10), setup `.env`, `supabase link`, `db push`, secrets, deploy, menjalankan `npm run test:deno` dan `npm run test:sql`, daftar endpoint dan RPC, batasan tahap 1.
- [ ] **Step 5: Verifikasi akhir** — `npm run test:deno` dan `npm run test:sql` → semua PASS.
- [ ] **Step 6: Commit** — `git commit -m "chore: deploy config, smoke test and setup docs"`
