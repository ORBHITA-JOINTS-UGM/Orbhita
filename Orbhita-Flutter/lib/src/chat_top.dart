import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// "Mau mulai dari tugas yang mana?" assistant prompt row.
class ChatTop extends StatelessWidget {
  const ChatTop({super.key, required this.narrow, required this.onSuggest});

  final bool narrow;
  final VoidCallback onSuggest;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        children: [
          Container(
            width: narrow ? 22 : 30,
            height: narrow ? 22 : 30,
            decoration: BoxDecoration(
              color: const Color(0xFFECF2F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Orbit(height: narrow ? 10 : 12.6)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mau mulai dari tugas yang mana?',
                    style: T(narrow ? 10 : 11, w: FontWeight.w700)),
                if (!narrow)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Ketik instruksi, kirim PDF, atau ceritakan lewat suara.',
                      style: T(9, color: const Color(0xFF7F93A0)),
                    ),
                  ),
              ],
            ),
          ),
          if (!narrow)
            Pressable(
              onTap: onSuggest,
              color: Colors.white,
              radius: 16,
              border: Border.all(color: const Color(0xFFDCE5EB)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Susun langkah', style: T(9, color: C.muted)),
                  const SizedBox(width: 6),
                  const OIcon('spark', size: 14, color: C.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
