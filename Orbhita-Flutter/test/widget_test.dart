import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbhita/main.dart';
import 'package:orbhita/src/model.dart';
import 'package:orbhita/src/plan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Load the asset-backed model once, outside any testWidgets FakeAsync zone,
  // so every test shares the same fully resolved instance.
  late Model m;
  setUpAll(() async {
    m = await Model.load();
  });

  test('model has 48 screens and field defaults', () {
    expect(m.screens.length, 48);
    expect(m.defaults['studyStart'], '19:30');
    expect(m.defaults['m1'], '45');
  });

  test('example plan matches the original algorithm', () {
    final p = examplePlan(m.defaults, 'initial', false);
    expect(p.total, 150);
    expect(p.sessionCount, greaterThan(0));
    expect(p.unallocated, 0);
  });

  testWidgets('landing -> calendar -> menu -> flow', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(OrbhitaApp(model: m));
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    await tester.tap(find.text('Continue with Google'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender & asisten'), findsOneWidget);
    expect(find.text('Oktober '), findsNothing);

    await tester.tap(find.bySemanticsLabel('Buka menu'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard Profil'), findsOneWidget);
    await tester.tap(find.text('Dashboard Profil'));
    await tester.pumpAndSettle();
    expect(find.text('Halo, mahasiswa.'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);

    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();
    expect(find.text('Kembali'), findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
}
