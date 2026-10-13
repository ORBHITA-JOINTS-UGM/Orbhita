import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Pulsing red dot shown while "recording".
class PulseDot extends StatefulWidget {
  const PulseDot({super.key});

  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.35).animate(_c),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(color: Color(0xFFB26B5E), shape: BoxShape.circle),
      ),
    );
  }
}

/// Attachment chip above the text input.
class AttachmentChip extends StatelessWidget {
  const AttachmentChip({super.key, required this.name, required this.onClear});
  final String name;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    const fg = Color(0xFF567A92);
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFE8EFF3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const OIcon('file', size: 16, color: fg),
              const SizedBox(width: 7),
              Flexible(
                child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: T(10, color: fg)),
              ),
              const SizedBox(width: 7),
              Semantics(
                button: true,
                label: 'Hapus lampiran',
                child: GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Text('×', style: T(16, color: const Color(0xFF63849A), h: 1)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fake recording state row.
class RecordingRow extends StatelessWidget {
  const RecordingRow({super.key, required this.onFinish, required this.onCancel});
  final VoidCallback onFinish;
  final VoidCallback onCancel;

  Widget _btn(String t, VoidCallback f, {String? label}) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: f,
          color: Colors.white,
          radius: 7,
          border: Border.all(color: const Color(0xFFDDC9C0)),
          padding: const EdgeInsets.all(9),
          child: Text(t, style: T(11, color: const Color(0xFF855746))),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 42),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const PulseDot(),
          Text('Rekaman contoh · mikrofon tidak diakses',
              style: T(11, color: const Color(0xFF936351))),
          _btn('Selesai & lihat transkrip', onFinish),
          _btn('×', onCancel, label: 'Batalkan rekaman'),
        ],
      ),
    );
  }
}

/// Popup menu opened by the "+" button.
class AttachMenu extends StatelessWidget {
  const AttachMenu({super.key, required this.onPick, required this.onSample});
  final VoidCallback onPick;
  final VoidCallback onSample;

  Widget _item(String icon, String t, VoidCallback f) => Pressable(
        onTap: f,
        radius: 7,
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 20,
          child: Row(
            children: [
              OIcon(icon, size: 17, color: C.ink),
              const SizedBox(width: 9),
              Text(t, style: T(11)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 226,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE3E8)),
        borderRadius: BorderRadius.circular(13),
        boxShadow: const [
          BoxShadow(color: Color(0x1A1B3C53), blurRadius: 28, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _item('file', 'Pilih PDF / gambar', onPick),
          _item('spark', 'Gunakan PDF', onSample),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Text('PDF ≤20 halaman/10 MB · JPG/PNG', style: T(11, h: 1.5)),
          ),
        ],
      ),
    );
  }
}
