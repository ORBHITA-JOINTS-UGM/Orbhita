const dayNames = ['Minggu', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];
const months = [
  'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
  'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
];

const typeLabel = {
  'google': 'Google · hanya baca',
  'manual': 'Kegiatan manual',
  'session': 'Sesi ORBHITA',
};

class CalEvent {
  const CalEvent(this.day, this.start, this.end, this.title, this.detail, this.type, this.route);
  final int day;
  final String start;
  final String end;
  final String title;
  final String detail;
  final String type;
  final String route;
}

const events = <CalEvent>[
  CalEvent(12, '07:10', '08:50', 'Technopreneurship', 'Kuliah · FIKLAB-201', 'google', 'external-event'),
  CalEvent(12, '15:30', '18:00', 'Jaringan Komputer', 'Kuliah · FIKLAB-401', 'google', 'external-event'),
  CalEvent(13, '09:40', '11:20', 'Supply Chain Management', 'Kuliah · FIKLAB-203', 'google', 'external-event'),
  CalEvent(13, '13:00', '14:40', 'Etika Profesi TI', 'Kuliah · Online', 'google', 'external-event'),
  CalEvent(14, '07:10', '09:40', 'Audit Sistem Informasi', 'Kuliah · FIK-302', 'google', 'external-event'),
  CalEvent(14, '13:00', '14:40', 'Pemrograman Web', 'Kuliah · FIKLAB-201', 'google', 'external-event'),
  CalEvent(14, '14:40', '15:30', 'Praktikum Web', 'Praktikum · FIKLAB-201', 'google', 'external-event'),
  CalEvent(14, '17:00', '18:00', 'Rapat proyek', 'Kegiatan yang ditambahkan sendiri', 'manual', 'activity'),
  CalEvent(14, '19:30', '19:55', 'Baca instruksi audit', 'Sesi 1 · langkah 01', 'session', 'task'),
  CalEvent(14, '20:00', '20:20', 'Petakan temuan', 'Sesi 2 · langkah 01', 'session', 'task'),
  CalEvent(15, '07:10', '09:40', 'Sistem Informasi Manajemen', 'Kuliah · FIKLAB-203', 'google', 'external-event'),
  CalEvent(15, '09:40', '11:20', 'Sistem Operasi', 'Kuliah', 'google', 'external-event'),
  CalEvent(15, '19:30', '20:40', 'Susun analisis & bukti', '3 sesi · langkah 02 · jeda 5 menit', 'session', 'task'),
  CalEvent(15, '20:45', '21:35', 'Rapikan laporan', '2 sesi · langkah 03 · jeda 5 menit', 'session', 'task'),
];

int minuteOf(String s) => int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3));

/// Per-type colours: (border bar, background, text) for cell/week events.
class EvColors {
  const EvColors(this.bar, this.bg, this.fg);
  final int bar;
  final int bg;
  final int fg;
}

const evColors = {
  'google': EvColors(0xFF789BB4, 0xFFE8F0F5, 0xFF335F7C),
  'manual': EvColors(0xFFC6A78F, 0xFFF2E9E2, 0xFF896343),
  'session': EvColors(0xFF6C977B, 0xFFE8F1EB, 0xFF456D54),
};
