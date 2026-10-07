import 'package:flutter/material.dart';

import 'core/session.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await session.load();
  runApp(const CocosApp());
}

class CocosApp extends StatelessWidget {
  const CocosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Coco Loco',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3F7FD6)),
        // Sin sesión se muestra el login; al entrar o salir, la pantalla cambia sola.
        home: ListenableBuilder(
          listenable: session,
          builder: (context, _) {
            final p = session.current;
            return p == null ? const LoginPage() : MenuPage(key: ValueKey(p.id));
          },
        ),
      );
}
