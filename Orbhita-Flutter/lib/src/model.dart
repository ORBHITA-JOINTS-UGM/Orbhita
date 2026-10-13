import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One screen of the data-driven ORBHITA flow.
class ScreenDef {
  ScreenDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.blocks,
    required this.actions,
    required this.back,
    required this.nav,
    required this.fr,
    required this.group,
  });

  final String id;
  final String title;
  final String subtitle;
  final List<Map<String, dynamic>> blocks;
  final List<Map<String, dynamic>> actions;
  final String? back;
  final String? nav;
  final String fr;
  final String group;

  factory ScreenDef.fromJson(Map<String, dynamic> j) => ScreenDef(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        subtitle: (j['subtitle'] ?? '') as String,
        blocks: ((j['blocks'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        actions: ((j['actions'] ?? []) as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        back: j['back'] as String?,
        nav: j['nav'] as String?,
        fr: (j['fr'] ?? '') as String,
        group: (j['group'] ?? '') as String,
      );
}

class Model {
  Model(this.screens, this.defaults);

  final Map<String, ScreenDef> screens;

  /// Default value of every keyed field/checkbox (later screens win, as in the
  /// original `Object.fromEntries`).
  final Map<String, dynamic> defaults;

  static Future<Model> load() async {
    final raw = await rootBundle.loadString('assets/data/model.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final screens = <String, ScreenDef>{};
    final defaults = <String, dynamic>{};
    for (final s in (json['screens'] as List)) {
      final def = ScreenDef.fromJson(Map<String, dynamic>.from(s as Map));
      screens[def.id] = def;
      for (final b in def.blocks) {
        final key = b['key'];
        if (key != null) {
          defaults[key as String] = b['type'] == 'check' ? b['selected'] : b['value'];
        }
      }
    }
    return Model(screens, defaults);
  }
}
