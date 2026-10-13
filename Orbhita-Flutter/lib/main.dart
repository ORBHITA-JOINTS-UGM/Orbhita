import 'package:flutter/material.dart';

import 'src/calendar_page.dart';
import 'src/model.dart';
import 'src/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final model = await Model.load();
  runApp(OrbhitaApp(model: model));
}

class OrbhitaApp extends StatelessWidget {
  const OrbhitaApp({super.key, required this.model});

  final Model model;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ORBHITA',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      themeMode: ThemeMode.light,
      home: Scaffold(body: CalendarPage(model: model)),
    );
  }
}
