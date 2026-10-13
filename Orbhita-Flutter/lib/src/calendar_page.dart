import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'cal_data.dart';
import 'cal_overlays.dart';
import 'cal_sidebar.dart';
import 'cal_topbar.dart';
import 'cal_zone.dart';
import 'chat_parts.dart';
import 'chat_zone.dart';
import 'flow_app.dart';
import 'landing.dart';
import 'model.dart';
import 'review_menu.dart';
import 'theme.dart';

/// Root screen: landing -> calendar + assistant, with overlays and the flow.
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, required this.model});
  final Model model;

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  bool loggedOut = true;
  int month = 9;
  int year = 2026;
  int day = 14;
  String view = 'month';
  final List<ChatItem> chats = [];
  final ScrollController chatScroll = ScrollController();
  final TextEditingController message = TextEditingController();
  String? attachment;
  bool menu = false;
  String? drawer;
  CalEvent? detail;
  bool recording = false;
  String notice = '';
  bool sidebar = false;
  bool showReview = false;
  String sent = '';

  @override
  void dispose() {
    chatScroll.dispose();
    message.dispose();
    super.dispose();
  }

  bool get demo => year == 2026 && month == 9;
  int get totalDays => DateTime(year, month + 2, 0).day;
  int get weekday => DateTime(year, month + 1, day).weekday % 7;
  List<CalEvent> get dayEvents =>
      demo ? events.where((e) => e.day == day).toList() : const <CalEvent>[];

  void move(int d) {
    var m = month + d;
    var y = year;
    if (m > 11) {
      m = 0;
      y++;
    }
    if (m < 0) {
      m = 11;
      y--;
    }
    setState(() {
      month = m;
      year = y;
      day = 1;
      notice = '';
    });
  }

  void open(String r) {
    setState(() {
      if (r == 'login') {
        loggedOut = true;
      } else {
        drawer = r;
      }
      sidebar = false;
      menu = false;
      showReview = false;
    });
  }

  void say(String s) => setState(() => notice = s);

  void submit() {
    final text = message.text.trim();
    if (text.isEmpty && attachment == null) {
      say('Tulis instruksi atau tambahkan PDF/gambar terlebih dahulu.');
      return;
    }
    setState(() {
      sent = text.isNotEmpty ? text : 'Tinjau lampiran $attachment';
      chats.add(ChatItem(text.isNotEmpty ? text : 'Tinjau lampiran ini.', attachment));
      message.clear();
      attachment = null;
      menu = false;
      notice = 'Draf dan jadwal hanya disimpan setelah konfirmasi.';
    });
    Future.delayed(const Duration(milliseconds: 80), () {
      if (chatScroll.hasClients) {
        chatScroll.animateTo(
          chatScroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> pickFile() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (f == null) return;
    final ext = f.name.split('.').last.toLowerCase();
    if (!['pdf', 'png', 'jpg', 'jpeg'].contains(ext)) {
      say('Pilih PDF, JPG, atau PNG.');
      return;
    }
    final size = f.lengthSync() ?? await f.length() ?? 0;
    if (size > 10 * 1024 * 1024) {
      say('Ukuran maksimal 10 MB.');
      return;
    }
    setState(() {
      attachment = f.name;
      menu = false;
      notice = 'Lampiran dipilih.';
    });
  }

  void sendVoice() {
    setState(() {
      recording = false;
      message.text =
          'Buat laporan audit sistem informasi, sertakan tiga temuan dan referensi. Deadline Jumat 16 Oktober pukul 23.59.';
      notice = 'Transkrip ditambahkan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loggedOut) {
      return Landing(onContinue: () => setState(() => loggedOut = false));
    }
    return Stack(
      children: [
        _body(),
        if (detail != null)
          Positioned.fill(
            child: EventDetail(
              event: detail!,
              dateLine: '${detail!.day} ${months[month]} $year · ${detail!.start}–${detail!.end}',
              onClose: () => setState(() => detail = null),
              onOpen: () {
                final r = detail!.route;
                setState(() => detail = null);
                open(r);
              },
            ),
          ),
        if (drawer != null) Positioned.fill(child: _drawer()),
      ],
    );
  }

  Widget _sentBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEF3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 90),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(sent, style: T(10, color: const Color(0xFF426B85))),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  attachment != null
                      ? 'Lampiran: $attachment'
                      : 'Pesan contoh · belum menjadi tugas tersimpan',
                  style: T(8, color: const Color(0xFF7D97A8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawer() {
    return ColoredBox(
      color: C.cream,
      child: Column(
        children: [
          if (sent.isNotEmpty && drawer == 'processing') _sentBanner(),
          Expanded(
            child: FlowApp(
              key: ValueKey(drawer),
              model: widget.model,
              start: drawer!,
              initialMessage: message.text.isNotEmpty ? message.text : sent,
              onClose: () => setState(() => drawer = null),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    return LayoutBuilder(builder: (context, box) {
      final narrow = box.maxWidth <= 680;
      final tight = box.maxWidth <= 950;
      final sideW = narrow ? (box.maxWidth * 0.88).clamp(0.0, 320.0) : (tight ? 238.0 : 270.0);
      final side = CalSidebar(
        width: sideW,
        showClose: narrow,
        day: day,
        month: month,
        totalDays: totalDays,
        weekdayOfDay: weekday,
        dayEvents: dayEvents,
        onClose: () => setState(() => sidebar = false),
        onDay: (d) => setState(() => day = d),
        onOpen: open,
        onDetail: (e) => setState(() => detail = e),
      );
      return ColoredBox(
        color: Colors.white,
        child: Stack(
          children: [
            Row(children: [if (!narrow) side, Expanded(child: _main(narrow, tight))]),
            if (narrow && sidebar) ...[
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => sidebar = false),
                  child: const SizedBox.expand(),
                ),
              ),
              Positioned(top: 0, bottom: 0, left: 0, child: Material(elevation: 12, child: side)),
            ],
          ],
        ),
      );
    });
  }


  Widget _zone(bool narrow) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (showReview && n is ScrollStartNotification) {
          setState(() => showReview = false);
        }
        return false;
      },
      child: CalZone(
        year: year,
        month: month,
        day: day,
        view: view,
        narrow: narrow,
        dayEvents: dayEvents,
        onToday: () => setState(() {
          year = 2026;
          month = 9;
          day = 14;
        }),
        onView: (v) => setState(() => view = v),
        onMove: move,
        onAdd: () => open('activity'),
        onDay: (d) => setState(() => day = d),
        onEvent: (d, e) => setState(() {
          day = d;
          detail = e;
        }),
        onMore: (d) => setState(() {
          day = d;
          sidebar = true;
        }),
        onAgenda: () => setState(() => sidebar = true),
      ),
    );
  }

  Widget _chat(bool narrow) {
    return ChatZone(
      narrow: narrow,
      chats: chats,
      scroll: chatScroll,
      controller: message,
      attachment: attachment,
      recording: recording,
      menuOpen: menu,
      onChanged: (_) => setState(() {}),
      onSubmit: submit,
      onSuggest: () => setState(() {
        message.text = 'Bantu susun langkah untuk laporan audit sistem informasi.';
        notice = 'Instruksi ditambahkan; tekan kirim untuk meninjau draf.';
      }),
      onReview: (c) {
        setState(() => sent = c.text);
        open('draft');
      },
      onClearAttachment: () => setState(() => attachment = null),
      onToggleMenu: () => setState(() => menu = !menu),
      onPickFile: pickFile,
      onUseSample: () => setState(() {
        attachment = 'instruksi-audit.pdf · contoh';
        menu = false;
      }),
      onToggleRecording: () => setState(() => recording = !recording),
      onFinishVoice: sendVoice,
    );
  }

  Widget _main(bool narrow, bool tight) {
    return Stack(
      children: [
        Column(
          children: [
            CalTopbar(
              narrow: narrow,
              tight: tight,
              onSidebar: () => setState(() => sidebar = true),
              onMenu: () => setState(() => showReview = !showReview),
            ),
            Expanded(child: _zone(narrow)),
            _chat(narrow),
          ],
        ),
        if (showReview) Positioned(
          right: 27,
          top: 70,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width - 54),
            child: ReviewMenu(onOpen: open),
          ),
        ),
      ],
    );
  }
}

