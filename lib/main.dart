import 'dart:async';

import 'package:flutter/material.dart';

import 'core/session.dart';
import 'core/sound.dart';
import 'pages/login_page.dart';
import 'pages/menu_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Se pinta algo de inmediato; los datos guardados se cargan después (ver _Boot).
  runApp(const _Boot());
}

final _theme = ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF3F7FD6));

/// Carga los perfiles guardados mostrando una pantalla de carga. Si algo falla o tarda demasiado,
/// lo dice en pantalla (en vez de quedarse en blanco) y deja reintentar o continuar sin guardar.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  late Future<void> _init = _start();
  bool _skip = false;

  // Perfiles guardados y preferencia de sonido, a la vez.
  Future<void> _start() => Future.wait([session.load(), Sound.instance.init()]).timeout(const Duration(seconds: 8));

  void _retry() => setState(() => _init = _start());

  @override
  Widget build(BuildContext context) {
    if (_skip) return const CocosApp();
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.done && !snap.hasError) return const CocosApp();
        return MaterialApp(
          title: 'Coco Loco',
          debugShowCheckedModeBanner: false,
          theme: _theme,
          home: _BootScreen(
            error: snap.hasError ? '${snap.error}' : null,
            onRetry: _retry,
            onContinue: () => setState(() => _skip = true),
          ),
        );
      },
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen({required this.error, required this.onRetry, required this.onContinue});

  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF9A86), Color(0xFFFFE0A3), Color(0xFF4AA8E8)]),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text(
                    'COCO LOCO',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1, shadows: [Shadow(blurRadius: 8, color: Color(0xFF1C3F7A))]),
                  ),
                  const SizedBox(height: 24),
                  if (error == null) ...[
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 12),
                    const Text('Cargando…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(16)),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        const Text('No se pudieron cargar tus datos guardados', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 8),
                        Text(error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
                        TextButton(onPressed: onContinue, child: const Text('Continuar sin guardar')),
                      ]),
                    ),
                  ],
                ]),
              ),
            ),
          ),
        ),
      );
}

class CocosApp extends StatelessWidget {
  const CocosApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Coco Loco',
        debugShowCheckedModeBanner: false,
        theme: _theme,
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
