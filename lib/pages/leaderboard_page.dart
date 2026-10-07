import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/color_ext.dart';
import '../core/session.dart';
import '../game/characters.dart';
import '../game/level.dart';
import '../ui/animated_background.dart';
import '../ui/character_avatar.dart';
import '../ui/outlined_text.dart';

/// Ranking global por estrellas (requiere el backend).
class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  late Future<List<LeaderboardEntry>> _future = Api.leaderboard();

  void _retry() => setState(() => _future = Api.leaderboard());

  @override
  Widget build(BuildContext context) => Scaffold(
        body: AnimatedBackground(
          theme: themes[1],
          child: SafeArea(
            child: Stack(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.o(0.94),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [BoxShadow(color: Colors.black.o(0.25), blurRadius: 16, offset: const Offset(0, 6))],
                      ),
                      child: FutureBuilder<List<LeaderboardEntry>>(
                        future: _future,
                        builder: (context, snap) {
                          if (snap.connectionState != ConnectionState.done) {
                            return const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()));
                          }
                          if (snap.hasError) {
                            return Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('${snap.error}', textAlign: TextAlign.center),
                                const SizedBox(height: 12),
                                FilledButton(onPressed: _retry, child: const Text('Reintentar')),
                              ]),
                            );
                          }
                          final players = snap.data!;
                          if (players.isEmpty) {
                            return const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aún no hay jugadores en el ranking.\n¡Sé el primero!', textAlign: TextAlign.center)));
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: players.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, i) => _Row(rank: i + 1, entry: players[i], isMe: session.current?.remote == true && session.current!.name.toLowerCase() == players[i].username.toLowerCase()),
                          );
                        },
                      ),
                    ),
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
                  const OutlinedText('Ranking', size: 26),
                ]),
              ),
            ]),
          ),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.rank, required this.entry, required this.isMe});

  final int rank;
  final LeaderboardEntry entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final character = Character.values.firstWhere((c) => c.name == entry.character, orElse: () => Character.mochi);
    final medal = const {1: Color(0xFFFFB800), 2: Color(0xFFA9B4C2), 3: Color(0xFFCD7F32)}[rank];
    return Container(
      color: isMe ? const Color(0xFFFFF4CC) : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      child: Row(children: [
        SizedBox(
          width: 32,
          child: medal != null ? Icon(Icons.emoji_events_rounded, color: medal) : Text('$rank', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.black54)),
        ),
        const SizedBox(width: 8),
        CharacterAvatar(character, width: 38),
        const SizedBox(width: 12),
        Expanded(child: Text(entry.username, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
        const Icon(Icons.star_rounded, color: Color(0xFFFFB800), size: 20),
        Text(' ${entry.stars}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(width: 10),
        const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B3D), size: 18),
        Text('${entry.bestStreak}', style: const TextStyle(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
