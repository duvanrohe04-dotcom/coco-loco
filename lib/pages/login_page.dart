import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/color_ext.dart';
import '../core/session.dart';
import '../game/characters.dart';
import '../game/level.dart';
import '../ui/animated_background.dart';
import '../ui/character_avatar.dart';
import '../ui/outlined_text.dart';

enum _View { list, online, local }

/// Pantalla de entrada: perfiles guardados, cuenta en línea o perfil local nuevo.
/// Al iniciar sesión, `main.dart` cambia solo al menú.
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _name = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  Character _pick = Character.mochi;
  late _View _view = session.profiles.isNotEmpty ? _View.list : (onlineEnabled ? _View.online : _View.local);
  bool _register = false;
  bool _hidePass = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _go(_View v, {Profile? prefill}) => setState(() {
        _view = v;
        _error = null;
        _pass.clear();
        if (prefill != null) _user.text = prefill.name;
      });

  void _submitLocal() {
    final error = session.validateName(_name.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    session.create(_name.text, _pick);
  }

  Future<void> _submitOnline() async {
    final user = _user.text.trim();
    if (!RegExp(r'^[A-Za-z0-9_]{3,16}$').hasMatch(user)) {
      setState(() => _error = 'Usuario de 3 a 16 letras, números o _');
      return;
    }
    if (_pass.text.length < 8) {
      setState(() => _error = 'La contraseña debe tener al menos 8 caracteres');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await session.signInOnline(user, _pass.text, register: _register);
    if (!mounted) return; // si entró bien, esta pantalla ya se reemplazó
    setState(() {
      _busy = false;
      _error = error;
    });
  }

  void _openProfile(Profile p) {
    if (p.remote && !session.hasToken(p)) {
      _go(_View.online, prefill: p); // sesión caducada: pide la contraseña
    } else {
      session.signIn(p);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBackground(
          theme: themes[1],
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const OutlinedText('COCO LOCO', size: 44),
                    const OutlinedText('atrapa los verbos en inglés', size: 18),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.o(0.94),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.o(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: switch (_view) {
                        _View.list => _profileList(),
                        _View.online => _onlineForm(),
                        _View.local => _localForm(),
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      onlineEnabled
                          ? 'Con cuenta en línea tu progreso viaja contigo.'
                          : 'Los perfiles se guardan solo en este dispositivo.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(blurRadius: 4)]),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _title(String text) => Text(text, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1B3A7A)));

  Widget _profileList() => Column(mainAxisSize: MainAxisSize.min, children: [
        _title('¿Quién juega?'),
        const SizedBox(height: 12),
        for (final p in session.profiles)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: const Color(0xFFEFF4FB),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openProfile(p),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    CharacterAvatar(p.character, width: 44),
                    const SizedBox(width: 14),
                    Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                    if (p.remote) const Padding(padding: EdgeInsets.only(right: 6), child: Icon(Icons.cloud_done_rounded, color: Color(0xFF3F7FD6), size: 22)),
                    const Icon(Icons.play_arrow_rounded, color: Color(0xFF1B3A7A), size: 30),
                  ]),
                ),
              ),
            ),
          ),
        const SizedBox(height: 4),
        Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
          if (onlineEnabled)
            OutlinedButton.icon(onPressed: () => _go(_View.online), icon: const Icon(Icons.cloud_outlined), label: const Text('Cuenta en línea')),
          if (session.canCreate)
            OutlinedButton.icon(onPressed: () => _go(_View.local), icon: const Icon(Icons.add_rounded), label: const Text('Nuevo jugador')),
        ]),
      ]);

  Widget _onlineForm() => AutofillGroup(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _title(_register ? 'Crear cuenta' : 'Iniciar sesión'),
          const SizedBox(height: 14),
          TextField(
            controller: _user,
            enabled: !_busy,
            autofocus: true,
            maxLength: 16,
            autofillHints: const [AutofillHints.username],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Usuario', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_rounded)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _pass,
            enabled: !_busy,
            obscureText: _hidePass,
            autofillHints: [_register ? AutofillHints.newPassword : AutofillHints.password],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _busy ? null : _submitOnline(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: _register ? 'Mínimo 8 caracteres' : null,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                tooltip: _hidePass ? 'Mostrar contraseña' : 'Ocultar contraseña',
                icon: Icon(_hidePass ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                onPressed: () => setState(() => _hidePass = !_hidePass),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFD64545), fontWeight: FontWeight.w700)),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _submitOnline,
              child: _busy
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                  : Text(_register ? 'Crear cuenta y jugar' : 'Entrar'),
            ),
          ),
          TextButton(
            onPressed: _busy ? null : () => setState(() {
              _register = !_register;
              _error = null;
            }),
            child: Text(_register ? 'Ya tengo cuenta' : 'No tengo cuenta: crear una'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _go(session.profiles.isNotEmpty ? _View.list : _View.local),
            child: Text(session.profiles.isNotEmpty ? 'Volver' : 'Jugar sin cuenta (solo en este dispositivo)'),
          ),
        ]),
      );

  Widget _localForm() => Column(mainAxisSize: MainAxisSize.min, children: [
        _title(session.profiles.isEmpty && !onlineEnabled ? '¡Bienvenido!' : 'Nuevo jugador'),
        const SizedBox(height: 14),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: Session.maxName,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submitLocal(),
          decoration: InputDecoration(
            labelText: 'Tu nombre o apodo',
            errorText: _error,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.person_rounded),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Elige tu personaje', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        CharacterChooser(selected: _pick, onChanged: (c) => setState(() => _pick = c)),
        const SizedBox(height: 18),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: _submitLocal, child: const Text('Crear y jugar'))),
        if (session.profiles.isNotEmpty)
          TextButton(onPressed: () => _go(_View.list), child: const Text('Volver'))
        else if (onlineEnabled)
          TextButton(onPressed: () => _go(_View.online), child: const Text('Mejor entrar con cuenta en línea')),
      ]);
}
