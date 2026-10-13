import 'package:flutter/material.dart';

import 'theme.dart';

/// Dark toast shown above the nav bar.
class Toast extends StatelessWidget {
  const Toast({super.key, required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 15,
      right: 15,
      bottom: 82,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.fromLTRB(15, 15, 32, 15),
          decoration: BoxDecoration(
            color: C.ink,
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 22, offset: Offset(0, 8)),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Text(message, style: T(12, color: Colors.white)),
              Positioned(
                right: -22,
                top: -5,
                child: Semantics(
                  button: true,
                  label: 'Tutup pesan',
                  child: GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: Text('×', style: T(18, color: Colors.white, h: 1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
