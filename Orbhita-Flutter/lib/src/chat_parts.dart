import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

class ChatItem {
  const ChatItem(this.text, this.attachment);
  final String text;
  final String? attachment;
}

/// User bubble + ORBHITA reply with the "Tinjau draf" button.
class ChatPair extends StatelessWidget {
  const ChatPair({super.key, required this.chat, required this.onReview});

  final ChatItem chat;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    const small = Color(0xFF688498);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFEDF2F5),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(chat.text, style: T(13)),
                  if (chat.attachment != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const OIcon('file', size: 14, color: small),
                          const SizedBox(width: 5),
                          Flexible(child: Text(chat.attachment!, style: T(10, color: small))),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Orbit(height: 17),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ORBHITA', style: T(12, w: FontWeight.w700)),
                    Padding(
                      padding: const EdgeInsets.only(top: 6, bottom: 12),
                      child: Text(
                        'Gua bantu ubah instruksi jadi langkah yang bisa ditinjau. '
                        'Hasilnya telah disiapkan; isi pesan dan lampiran belum dianalisis otomatis.',
                        style: T(12, h: 1.8),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Pressable(
                        onTap: onReview,
                        color: C.blue,
                        radius: 10,
                        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Tinjau draf', style: T(11, color: Colors.white)),
                            const SizedBox(width: 10),
                            const OIcon('chevron', size: 15, color: Colors.white),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Konfirmasi tugas dulu, lalu tinjau dan konfirmasi jadwal.',
                        style: T(9, color: small),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
