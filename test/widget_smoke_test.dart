import 'package:coco_loco/game/level.dart';
import 'package:coco_loco/pages/game_page.dart';
import 'package:coco_loco/pages/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _pumpSeconds(WidgetTester tester, double seconds) async {
  for (var i = 0; i < seconds * 30; i++) {
    await tester.pump(const Duration(milliseconds: 33));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el menú se dibuja con los 20 niveles', (tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: MenuPage()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
    expect(find.text('COCO LOCO'), findsWidgets);
    expect(find.text('JEFE'), findsWidgets);
  });

  testWidgets('perder y pulsar Reintentar abre un nivel nuevo que sigue funcionando', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: GamePage(level: levels[0])));
    // Sin mover al personaje se pierden las vidas.
    for (var i = 0; i < 90 && find.text('Reintentar').evaluate().isEmpty; i++) {
      await _pumpSeconds(tester, 1);
    }
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.tap(find.text('Reintentar'));
    await _pumpSeconds(tester, 1); // transición: conviven la pantalla vieja y la nueva
    await _pumpSeconds(tester, 4);
    expect(tester.takeException(), isNull);
    expect(find.text('Reintentar'), findsNothing);
    expect(find.byType(GamePage), findsOneWidget);
  });

  for (final n in [1, 5, 10, 20]) {
    testWidgets('el nivel $n arranca y se juega unos segundos sin errores', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: GamePage(level: levels[n - 1])));
      await _pumpSeconds(tester, 6);
      expect(tester.takeException(), isNull);
      // Arrastrar al personaje no debe romper nada.
      await tester.drag(find.byType(GamePage), const Offset(150, 0));
      await _pumpSeconds(tester, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
