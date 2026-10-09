import { DateTime } from "../_shared/deps.ts";
import type { SchedulerOutput } from "../_shared/scheduler/mod.ts";
import { HORIZON_DAYS } from "./load.ts";

/** Plain-language summary built only from scheduler numbers; no AI involved. */
export function explainPlan(out: SchedulerOutput, titles: Record<string, string>, timezone: string): string {
  const name = (id: string) => titles[id] ?? "Tugas";
  const lines: string[] = [];

  for (const r of out.perTask) {
    switch (r.risk) {
      case "deadline_risk":
        lines.push(`${name(r.taskId)}: kurang ${r.unallocatedMinutes} menit sebelum deadline.`);
        break;
      case "target_risk":
        lines.push(`${name(r.taskId)}: target pribadi terlewat, tetapi deadline resmi masih teralokasi.`);
        break;
      case "missing_deadline":
        lines.push(`${name(r.taskId)}: belum dijadwalkan karena deadline belum diisi.`);
        break;
      case "overdue":
        lines.push(`${name(r.taskId)}: deadline sudah lewat dan tugas belum selesai.`);
        break;
    }
  }
  for (const u of out.unscheduled.filter((u) => u.reason === "beyond_horizon")) {
    lines.push(`${name(u.taskId)}: ${u.minutes} menit berada di luar ${HORIZON_DAYS} hari ke depan dan dijadwalkan nanti.`);
  }

  if (lines.length === 0) lines.push("Semua langkah sudah teralokasi sebelum deadline.");

  const first = out.sessions[0];
  if (first) {
    const when = DateTime.fromMillis(first.start, { zone: timezone }).setLocale("id").toFormat("ccc d LLL HH.mm");
    lines.push(`Sesi pertama: ${name(first.taskId)}, ${when}.`);
  }
  lines.push("Durasi adalah perkiraan; perbarui progres agar rencana tetap sesuai.");
  return lines.join("\n");
}
