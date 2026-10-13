import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbhita/main.dart';
import 'package:orbhita/src/flow_app.dart';
import 'package:orbhita/src/model.dart';
import 'package:orbhita/src/theme.dart';
import 'package:orbhita/src/widgets_basic.dart';

/// Runs [body] while recording every FlutterError (layout overflow, build
/// errors, ...) instead of letting the first one abort the test.
Future<List<String>> _collect(Future<void> Function() body) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final head = details.exceptionAsString().split('\n').first;
    final where = RegExp(r'lib/src/\w+\.dart:\d+')
        .firstMatch(details.toString())
        ?.group(0);
    errors.add(where == null ? head : '$head @ $where');
  };
  try {
    await body();
  } catch (e) {
    errors.add('THROWN: ${e.toString().split('\n').first}');
  } finally {
    FlutterError.onError = previous;
  }
  return errors;
}

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: Scaffold(body: child),
    );

void _size(WidgetTester tester, Size s) {
  tester.view.physicalSize = s;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _sizes = <String, Size>{
  'small-phone 320x640': Size(320, 640),
  'phone 390x844': Size(390, 844),
  'desktop 1280x900': Size(1280, 900),
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Model model;
  setUpAll(() async {
    model = await Model.load();
  });

  for (final entry in _sizes.entries) {
    testWidgets('every flow screen renders without errors @ ${entry.key}',
        (tester) async {
      _size(tester, entry.value);
      final failures = <String>[];
      for (final id in model.screens.keys) {
        final errors = await _collect(() async {
          await tester.pumpWidget(_host(FlowApp(
            key: UniqueKey(),
            model: model,
            start: id,
          )));
          await tester.pump(const Duration(milliseconds: 200));
        });
        for (final e in errors) {
          failures.add('[$id] $e');
        }
      }
      expect(failures, isEmpty, reason: failures.join('\n'));
    });
  }

  testWidgets('every action button works on every screen @ phone 390x844',
      (tester) async {
    _size(tester, const Size(390, 844));
    final failures = <String>[];
    var taps = 0;
    for (final screen in model.screens.values) {
      for (var i = 0; i < screen.actions.length; i++) {
        final label = screen.actions[i]['label'] as String;
        final errors = await _collect(() async {
          await tester.pumpWidget(_host(FlowApp(
            key: UniqueKey(),
            model: model,
            start: screen.id,
          )));
          await tester.pump(const Duration(milliseconds: 100));
          final finder = find.widgetWithText(OButton, label);
          if (finder.evaluate().isEmpty) {
            if (screen.id != 'login' && screen.id != 'home') {
              failures.add('[${screen.id}] action "$label" not rendered');
            }
            return;
          }
          await tester.ensureVisible(finder.first);
          await tester.pump(const Duration(milliseconds: 50));
          await tester.tap(finder.first);
          taps++;
          await tester.pump(const Duration(milliseconds: 300));
        });
        for (final e in errors) {
          failures.add('[${screen.id}] "$label": $e');
        }
      }
    }
    expect(taps, greaterThan(0));
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('every navigation target and back link points to an existing screen',
      () {
    final bad = <String>[];
    for (final s in model.screens.values) {
      if (s.back != null && !model.screens.containsKey(s.back)) {
        bad.add('[${s.id}] back -> ${s.back}');
      }
      for (final a in s.actions) {
        final t = a['target'] as String?;
        if (t == null || !model.screens.containsKey(t)) {
          bad.add('[${s.id}] action "${a['label']}" -> $t');
        }
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  for (final entry in _sizes.entries) {
    testWidgets('calendar page interactions @ ${entry.key}', (tester) async {
      _size(tester, entry.value);
      final semantics = tester.ensureSemantics();
      final errors = await _collect(() async {
        await tester.pumpWidget(OrbhitaApp(key: UniqueKey(), model: model));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Continue with Google'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Kalender & asisten'), findsOneWidget);

        for (final label in const [
          'Buat Tugas Baru',
          'Pengaturan & Profil',
          'Pengingat & Notifikasi',
        ]) {
          await tester.tap(find.bySemanticsLabel('Buka menu'));
          await tester.pump(const Duration(milliseconds: 200));
          expect(find.text('MENU UTAMA'), findsOneWidget);
          await tester.tap(find.text(label));
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pumpWidget(OrbhitaApp(key: UniqueKey(), model: model));
          await tester.pump(const Duration(milliseconds: 100));
          await tester.tap(find.text('Continue with Google'));
          await tester.pump(const Duration(milliseconds: 300));
        }

        await tester.tap(find.bySemanticsLabel('Buka menu'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.text('Keluar'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Continue with Google'), findsOneWidget);
      });
      semantics.dispose();
      expect(errors, isEmpty, reason: errors.join('\n'));
    });
  }
}
