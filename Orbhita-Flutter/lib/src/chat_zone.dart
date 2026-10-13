import 'package:flutter/material.dart';

import 'chat_parts.dart';
import 'chat_top.dart';
import 'composer.dart';

/// Bottom conversation + composer area (`.oc-chat-zone`).
class ChatZone extends StatelessWidget {
  const ChatZone({
    super.key,
    required this.narrow,
    required this.chats,
    required this.scroll,
    required this.controller,
    required this.attachment,
    required this.recording,
    required this.menuOpen,
    required this.onChanged,
    required this.onSubmit,
    required this.onSuggest,
    required this.onReview,
    required this.onClearAttachment,
    required this.onToggleMenu,
    required this.onPickFile,
    required this.onUseSample,
    required this.onToggleRecording,
    required this.onFinishVoice,
  });

  final bool narrow;
  final List<ChatItem> chats;
  final ScrollController scroll;
  final TextEditingController controller;
  final String? attachment;
  final bool recording;
  final bool menuOpen;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;
  final VoidCallback onSuggest;
  final ValueChanged<ChatItem> onReview;
  final VoidCallback onClearAttachment;
  final VoidCallback onToggleMenu;
  final VoidCallback onPickFile;
  final VoidCallback onUseSample;
  final VoidCallback onToggleRecording;
  final VoidCallback onFinishVoice;

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.of(context).size.height * 0.45;
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Padding(
            padding: EdgeInsets.fromLTRB(narrow ? 14 : 32, narrow ? 15 : 22, narrow ? 14 : 32, narrow ? 10 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (chats.isNotEmpty)
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxH),
                    child: Semantics(
                      liveRegion: true,
                      child: ListView(
                        controller: scroll,
                        shrinkWrap: true,
                        padding: EdgeInsets.zero,
                        children: [
                          for (var i = 0; i < chats.length; i++)
                            Padding(
                              padding: EdgeInsets.only(top: i == 0 ? 0 : 16),
                              child: ChatPair(chat: chats[i], onReview: () => onReview(chats[i])),
                            ),
                        ],
                      ),
                    ),
                  ),
                ChatTop(narrow: narrow, onSuggest: onSuggest),
                Composer(
                  controller: controller,
                  attachment: attachment,
                  recording: recording,
                  menuOpen: menuOpen,
                  narrow: narrow,
                  onChanged: onChanged,
                  onSubmit: onSubmit,
                  onClearAttachment: onClearAttachment,
                  onToggleMenu: onToggleMenu,
                  onPickFile: onPickFile,
                  onUseSample: onUseSample,
                  onToggleRecording: onToggleRecording,
                  onFinishVoice: onFinishVoice,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
