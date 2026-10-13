import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'composer_parts.dart';
import 'icons.dart';
import 'theme.dart';

/// Rounded message composer: attachment chip, text/recording, toolbar.
class Composer extends StatelessWidget {
  const Composer({
    super.key,
    required this.controller,
    required this.attachment,
    required this.recording,
    required this.menuOpen,
    required this.narrow,
    required this.onChanged,
    required this.onSubmit,
    required this.onClearAttachment,
    required this.onToggleMenu,
    required this.onPickFile,
    required this.onUseSample,
    required this.onToggleRecording,
    required this.onFinishVoice,
  });

  final TextEditingController controller;
  final String? attachment;
  final bool recording;
  final bool menuOpen;
  final bool narrow;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onClearAttachment;
  final VoidCallback onToggleMenu;
  final VoidCallback onPickFile;
  final VoidCallback onUseSample;
  final VoidCallback onToggleRecording;
  final VoidCallback onFinishVoice;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(
              narrow ? 12 : 14, narrow ? 11 : 12, narrow ? 12 : 14, narrow ? 8 : 9),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            border: Border.all(color: const Color(0xFFDCE3E8)),
            borderRadius: BorderRadius.circular(narrow ? 18 : 21),
            boxShadow: const [
              BoxShadow(color: Color(0x0A1B3C53), blurRadius: 14, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (attachment != null)
                AttachmentChip(name: attachment!, onClear: onClearAttachment),
              if (recording)
                RecordingRow(onFinish: onFinishVoice, onCancel: onToggleRecording)
              else
                _input(),
              _toolbar(),
            ],
          ),
        ),
        if (menuOpen)
          Positioned(
            left: -5,
            bottom: 42 + (narrow ? 8 : 9),
            child: AttachMenu(onPick: onPickFile, onSample: onUseSample),
          ),
      ],
    );
  }

  Widget _input() {
    final size = narrow ? 13.0 : 14.0;
    return Focus(
      onKeyEvent: (node, ev) {
        if (ev is KeyDownEvent &&
            ev.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          onSubmit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: narrow ? 48 : 55, maxHeight: 120),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          minLines: 2,
          maxLines: 5,
          maxLength: 10000,
          style: T(size, h: 1.6),
          cursorColor: C.ink,
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            counterText: '',
            contentPadding: const EdgeInsets.fromLTRB(0, 2, 0, 5),
            hintText: 'Tanyakan tugasmu atau tambahkan jadwal...',
            hintStyle: T(size, color: const Color(0xFF7A8E9C), h: 1.6),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(Widget icon, String label, VoidCallback onTap, {Color? bg}) => Semantics(
        button: true,
        label: label,
        child: Pressable(
          onTap: onTap,
          color: bg,
          radius: 20,
          child: SizedBox(width: 40, height: 40, child: Center(child: icon)),
        ),
      );

  Widget _toolbar() {
    const grey = Color(0xFF5E7C91);
    return Row(
      children: [
        _iconBtn(const OIcon('plus', size: 22, color: grey), 'Tambahkan PDF atau gambar',
            onToggleMenu),
        const SizedBox(width: 10),
        Text('ORBHITA', style: T(10, color: const Color(0xFF5E7B90), w: FontWeight.w700)),
        if (!narrow)
          Text(' · tugas & kegiatan', style: T(10, color: const Color(0xFF8A9EAC))),
        const Spacer(),
        _iconBtn(
          OIcon('mic', size: 20, color: recording ? const Color(0xFF984E44) : grey),
          'Input suara contoh',
          onToggleRecording,
          bg: recording ? const Color(0xFFF3E5E2) : null,
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'Kirim pesan',
          child: Pressable(
            onTap: onSubmit,
            color: C.blue,
            radius: 20,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Center(child: OIcon('send', size: 20, color: Colors.white)),
            ),
          ),
        ),
      ],
    );
  }
}
