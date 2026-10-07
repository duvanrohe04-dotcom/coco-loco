import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import '../core/progress.dart';
import '../core/session.dart';
import '../game/characters.dart';
import '../game/level.dart';
import '../ui/animated_background.dart';
import '../ui/character_avatar.dart';
import '../ui/outlined_text.dart';

/// Perfil del jugador activo: nombre, personaje, estadísticas y gestión de la cuenta.
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD64545)), onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
          ],
        ),
      ) ??
      false;

  Future<void> _rename(BuildContext context, Profile p) async {
    final ctrl = TextEditingController(text: p.name);
    String? error;
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Cambiar nombre'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            maxLength: Session.maxName,
            decoration: InputDecoration(errorText: error, border: const OutlineInputBorder()),
            onSubmitted: (_) {
              error = session.validateName(ctrl.text, except: p);
              error == null ? Navigator.pop(ctx, ctrl.text) : setState(() {});
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(
              onPressed: () {
                error = session.validateName(ctrl.text, except: p);
                error == null ? Navigator.pop(ctx, ctrl.text) : setState(() {});
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (name != null) session.rename(p, name);
  }

  void _leave(BuildContext context) => Navigator.of(context).popUntil((r) => r.isFirst);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBackground(
          theme: themes[1],
          child: SafeArea(
            child: ListenableBuilder(
              listenable: Listenable.merge([session, progress, selectedCharacter]),
              builder: (context, _) {
                final p = session.current;
                if (p == null) return const SizedBox.shrink();
                return Stack(children: [
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Column(children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.o(0.94),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [BoxShadow(color: Colors.black.o(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                            ),
                            child: Column(children: [
                              CharacterAvatar(p.character, width: 110, happy: 0),
                              const SizedBox(height: 8),
                              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                Flexible(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1B3A7A)))),
                                if (!p.remote) IconButton(tooltip: 'Cambiar nombre', onPressed: () => _rename(context, p), icon: const Icon(Icons.edit_rounded)),
                              ]),
                              if (p.remote)
                                const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                  Icon(Icons.cloud_done_rounded, size: 18, color: Color(0xFF3F7FD6)),
                                  SizedBox(width: 6),
                                  Text('Cuenta en línea · progreso guardado en la nube', style: TextStyle(fontSize: 12, color: Colors.black54)),
                                ]),
                              const SizedBox(height: 12),
                              Row(children: [
                                _Stat(icon: Icons.star_rounded, color: const Color(0xFFFFB800), value: '${progress.totalStars}/${levels.length * 3}', label: 'Estrellas'),
                                _Stat(icon: Icons.flag_rounded, color: const Color(0xFF3FA66B), value: '${progress.levelsCompleted}/${levels.length}', label: 'Niveles'),
                                _Stat(icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF6B3D), value: '${progress.bestStreak}', label: 'Mejor racha'),
                              ]),
                              const SizedBox(height: 18),
                              const Align(alignment: Alignment.centerLeft, child: Text('Personaje', style: TextStyle(fontWeight: FontWeight.w800))),
                              const SizedBox(height: 10),
                              CharacterChooser(selected: p.character, onChanged: (c) => selectedCharacter.value = c),
                            ]),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                session.signOut();
                                _leave(context);
                              },
                              icon: const Icon(Icons.swap_horiz_rounded),
                              label: const Text('Cambiar de jugador'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(children: [
                            if (!p.remote) ...[
                              Expanded(
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(backgroundColor: Colors.white.o(0.9)),
                                  onPressed: () async {
                                    if (await _confirm(context, '¿Reiniciar progreso?', 'Se borrarán las estrellas y rachas de ${p.name}.', 'Reiniciar')) progress.reset();
                                  },
                                  child: const Text('Reiniciar progreso'),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFD64545), backgroundColor: Colors.white.o(0.9)),
                                onPressed: () async {
                                  final body = p.remote
                                      ? 'Se borrará la cuenta ${p.name} del servidor, con todo su progreso, y no podrás recuperarla.'
                                      : 'Se borrará ${p.name} y todo su progreso. No se puede deshacer.';
                                  if (!await _confirm(context, p.remote ? '¿Eliminar cuenta?' : '¿Eliminar perfil?', body, 'Eliminar')) return;
                                  final error = await session.delete(p);
                                  if (!context.mounted) return;
                                  if (error != null) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                                  } else {
                                    _leave(context);
                                  }
                                },
                                child: const Text('Eliminar perfil'),
                              ),
                            ),
                          ]),
                        ]),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 8,
                    top: 8,
                    child: Row(children: [
                      Material(
                        color: Colors.black.o(0.3),
                        shape: const CircleBorder(),
                        child: IconButton(tooltip: 'Volver', icon: const Icon(Icons.arrow_back_rounded, color: Colors.white), onPressed: () => Navigator.pop(context)),
                      ),
                      const SizedBox(width: 10),
                      const OutlinedText('Mi perfil', size: 26),
                    ]),
                  ),
                ]);
              },
            ),
          ),
        ),
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.color, required this.value, required this.label});

  final IconData icon;
  final Color color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(children: [
          Icon(icon, color: color, size: 30),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1B3A7A))),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ]),
      );
}
