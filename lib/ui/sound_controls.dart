import 'package:flutter/material.dart';

import '../core/color_ext.dart';
import '../core/sound.dart';
import '../core/synth.dart';

/// Interruptor "Sonido" para la ventana de pausa.
class SoundSwitch extends StatelessWidget {
  const SoundSwitch({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Sound.instance.enabled,
        builder: (context, on, _) => SizedBox(
          width: 220,
          child: SwitchListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            secondary: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: const Color(0xFF1B3A7A)),
            title: const Text('Sonido', style: TextStyle(fontWeight: FontWeight.w700)),
            value: on,
            onChanged: (v) async {
              await Sound.instance.setEnabled(v);
              if (v) Sound.instance.play(Sfx.click);
            },
          ),
        ),
      );
}

/// Botón redondo de altavoz para el menú.
class SoundButton extends StatelessWidget {
  const SoundButton({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: Sound.instance.enabled,
        builder: (context, on, _) => Material(
          color: Colors.white.o(0.92),
          shape: const CircleBorder(),
          elevation: 3,
          child: IconButton(
            tooltip: on ? 'Silenciar' : 'Activar sonido',
            icon: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded, color: const Color(0xFF1B3A7A)),
            onPressed: () async {
              await Sound.instance.toggle();
              if (Sound.instance.enabled.value) Sound.instance.play(Sfx.click);
            },
          ),
        ),
      );
}
