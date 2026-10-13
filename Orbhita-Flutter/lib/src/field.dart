import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'theme.dart';

String _p2(int n) => n.toString().padLeft(2, '0');

/// Labelled input (`.orb-field`). `kind` is one of text, number, time,
/// datetime-local, textarea.
class OField extends StatefulWidget {
  const OField({
    super.key,
    required this.label,
    required this.kind,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String kind;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<OField> createState() => _OFieldState();
}

class _OFieldState extends State<OField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);

  bool get _picker => widget.kind == 'time' || widget.kind == 'datetime-local';

  @override
  void didUpdateWidget(covariant OField old) {
    super.didUpdateWidget(old);
    if (widget.value != _c.text) {
      _c.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final cur = widget.value;
    if (widget.kind == 'time') {
      final parts = cur.split(':');
      final init = TimeOfDay(
        hour: int.tryParse(parts.first) ?? 0,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      );
      final t = await showTimePicker(context: context, initialTime: init);
      if (t != null) widget.onChanged('${_p2(t.hour)}:${_p2(t.minute)}');
      return;
    }
    final now = DateTime.now();
    final init = DateTime.tryParse(cur) ?? now;
    final d = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
    );
    if (t == null) return;
    widget.onChanged('${d.year.toString().padLeft(4, '0')}-${_p2(d.month)}-${_p2(d.day)}'
        'T${_p2(t.hour)}:${_p2(t.minute)}');
  }

  String get _display {
    if (widget.kind == 'datetime-local') return widget.value.replaceFirst('T', '  ');
    return widget.value;
  }

  @override
  Widget build(BuildContext context) {
    final area = widget.kind == 'textarea';
    final style = T(12, h: 1.6);
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: Color(0xFFCBD7DF)),
    );
    final focus = OutlineInputBorder(
      borderRadius: BorderRadius.circular(11),
      borderSide: const BorderSide(color: C.muted, width: 2),
    );
    final deco = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(12),
      border: border,
      enabledBorder: border,
      focusedBorder: focus,
      counterText: '',
    );

    Widget input;
    if (_picker) {
      input = Pressable(
        onTap: _pick,
        color: Colors.white,
        radius: 11,
        border: Border.all(color: const Color(0xFFCBD7DF)),
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 22),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(_display, style: style),
          ),
        ),
      );
    } else if (area) {
      input = SizedBox(
        height: 142,
        child: TextField(
          controller: _c,
          maxLength: 10000,
          maxLines: null,
          expands: true,
          textAlignVertical: TextAlignVertical.top,
          style: style,
          decoration: deco,
          onChanged: widget.onChanged,
        ),
      );
    } else {
      final num = widget.kind == 'number';
      input = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: TextField(
          controller: _c,
          style: style,
          keyboardType: num ? TextInputType.number : TextInputType.text,
          inputFormatters: num
              ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.eE+\-]'))]
              : null,
          decoration: deco,
          onChanged: widget.onChanged,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: T(11, w: FontWeight.w700)),
        const SizedBox(height: 6),
        input,
      ],
    );
  }
}
