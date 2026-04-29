import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:peb/poker/widgets/poker_card.dart';
import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../models/poker_state.dart';
import '../services/poker_engine.dart';
import '../services/poker_repo.dart';
import '../widgets/chat_panel.dart';
import '../widgets/poker_table.dart';

class PokerRoomScreen extends StatefulWidget {
  const PokerRoomScreen({
    super.key,
    required this.roomId,
    required this.currentProfile,
    required this.profileRepository,
  });

  final String roomId;
  final Profile currentProfile;
  final ProfileRepository profileRepository;

  @override
  State<PokerRoomScreen> createState() => _PokerRoomScreenState();
}

class _PokerRoomScreenState extends State<PokerRoomScreen> {
  late final PokerRepo repo;

  @override
  void initState() {
    super.initState();
    repo = PokerRepo(FirebaseFirestore.instance);
  }

  @override
  Widget build(BuildContext context) {
    final myId = widget.currentProfile.id;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: repo.roomRef(widget.roomId).snapshots(),
      builder: (context, snapRoom) {
        if (snapRoom.hasError) {
          return Scaffold(body: Center(child: Text("Error sala: ${snapRoom.error}")));
        }
        if (!snapRoom.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapRoom.data!.exists) {
          return const Scaffold(body: Center(child: Text("La sala no existe.")));
        }

        final roomData = snapRoom.data!.data() ?? {};
        final hostId = (roomData["hostProfileId"] ?? "") as String;
        final isHost = hostId == myId;
        final inviteCode = (roomData["inviteCode"] ?? "") as String;

        if (isHost) {
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await repo.ensureStateExists(
              roomId: widget.roomId,
              hostProfileId: myId,
            );
            await repo.syncPlayersFromRoomToState(
              roomId: widget.roomId,
              hostProfileId: myId,
            );
          });
        }

        return StreamBuilder<PokerState?>(
          stream: repo.watchState(widget.roomId),
          builder: (context, snapState) {
            if (snapState.hasError) {
              return Scaffold(body: Center(child: Text("Error state: ${snapState.error}")));
            }
            if (!snapState.hasData) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final s = snapState.data;
            if (s == null) {
              return const Scaffold(body: Center(child: Text("No existe state/current.")));
            }

            final roomPlayerIds = (roomData["playerIds"] as List?)?.cast<String>() ?? <String>[];
            final isInState = s.players.any((p) => p.profileId == myId);

            if (!isInState) {
              final alreadyJoinedRoom = roomPlayerIds.contains(myId);
              return Scaffold(
                appBar: AppBar(title: const Text("Poker")),
                body: Center(
                  child: alreadyJoinedRoom
                      ? const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text("Esperando a que el host te añada a la partida…"),
                          ],
                        )
                      : FilledButton.icon(
                          onPressed: () async {
                            try {
                              await repo.joinRoom(roomId: widget.roomId, profileId: myId);
                            } catch (e) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error al unirte: $e")),
                              );
                            }
                          },
                          icon: const Icon(Icons.login),
                          label: const Text("Unirme a la sala"),
                        ),
                ),
              );
            }

            final me = s.players.firstWhere((p) => p.profileId == myId);
            final myTurn = s.turnProfileId == myId;
            final toCall =
                (s.currentBet - me.betThisStreet) < 0 ? 0 : (s.currentBet - me.betThisStreet);

            final maxRaiseTo = me.betThisStreet + me.stack;

            return StreamBuilder<List<String>>(
              stream: repo.watchMyHand(widget.roomId, myId),
              builder: (context, snapHand) {
                final myHand = snapHand.data ?? const <String>[];

                return Scaffold(
                  appBar: AppBar(
                    title: const Text("Poker"),
                    actions: [
                      IconButton(
                        tooltip: "Copiar código de invitación",
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: inviteCode.isEmpty
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(text: inviteCode),
                                );

                                if (!mounted) return;

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Código de invitación copiado: $inviteCode"),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                      ),
                      if (isHost)
                        IconButton(
                          tooltip: "Cerrar sala",
                          icon: const Icon(Icons.stop_circle_outlined),
                          onPressed: () async {
                            await repo.closeRoom(
                              roomId: widget.roomId,
                              hostProfileId: myId,
                            );
                            if (!mounted) return;
                            Navigator.pop(context);
                          },
                        ),
                    ],
                  ),
                  body: SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: PokerTable(
                              state: s,
                              myProfileId: myId,
                            ),
                          ),
                        ),
                        _LocalHandPanel(
                          myHand: myHand,
                          playerName: widget.currentProfile.name,
                          stack: me.stack,
                          betThisStreet: me.betThisStreet,
                        ),
                        if (me.stack == 0) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                            child: FilledButton.icon(
                              onPressed: () async {
                                try {
                                  await repo.rebuyPlayer(
                                    roomId: widget.roomId,
                                    profileId: myId,
                                  );
                                } catch (e) {
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Error al reabastecer: $e")),
                                  );
                                }
                              },
                              icon: const Icon(Icons.restart_alt),
                              label: const Text("Reabastecer fichas"),
                            ),
                          ),
                        ],
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                s.lastActionText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontStyle: FontStyle.italic),
                              ),
                              if (s.phase == PokerPhase.showdown &&
                                  s.showdownText.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  s.showdownText,
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ],
                              if (s.phase == PokerPhase.showdown &&
                                  s.showdownLines.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: s.showdownLines
                                        .map(
                                          (line) => Padding(
                                            padding: const EdgeInsets.only(bottom: 4),
                                            child: Text(line),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _ActionBar(
                            phase: s.phase,
                            isHost: isHost,
                            myTurn: myTurn,
                            meReady: me.ready,
                            toCall: toCall,
                            currentBet: s.currentBet,
                            maxRaiseTo: maxRaiseTo,
                            onReady: () async {
                              try {
                                await repo.setReady(
                                  roomId: widget.roomId,
                                  profileId: myId,
                                  ready: !me.ready,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error Ready: $e")),
                                );
                              }
                            },
                            onStart: () async {
                              try {
                                await repo.hostStartHand(
                                  roomId: widget.roomId,
                                  hostProfileId: myId,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error al empezar mano: $e")),
                                );
                              }
                            },
                            onFold: () async {
                              try {
                                await repo.submitAction(
                                  roomId: widget.roomId,
                                  actorProfileId: myId,
                                  action: PokerAction(ActionType.fold),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error FOLD: $e")),
                                );
                              }
                            },
                            onCheckOrCall: () async {
                              try {
                                await repo.submitAction(
                                  roomId: widget.roomId,
                                  actorProfileId: myId,
                                  action: PokerAction(
                                    toCall == 0 ? ActionType.check : ActionType.call,
                                  ),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error acción: $e")),
                                );
                              }
                            },
                            onRaise: () async {
                              final raiseTo = await _askRaiseTo(
                                context,
                                s.currentBet,
                                maxRaiseTo,
                              );
                              if (raiseTo == null) return;

                              try {
                                await repo.submitAction(
                                  roomId: widget.roomId,
                                  actorProfileId: myId,
                                  action: PokerAction(ActionType.raise, raiseTo: raiseTo),
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error RAISE: $e")),
                                );
                              }
                            },
                            onNextHand: () async {
                              try {
                                await repo.hostStartHand(
                                  roomId: widget.roomId,
                                  hostProfileId: myId,
                                );
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text("Error siguiente mano: $e")),
                                );
                              }
                            },
                          ),
                        ),
                        SizedBox(
                          height: 150,
                          child: Container(
                            margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: Theme.of(context).colorScheme.surfaceContainerLowest,
                            ),
                            child: ChatPanel(
                              roomId: widget.roomId,
                              myProfileId: myId,
                              myDisplayName: widget.currentProfile.name,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<int?> _askRaiseTo(
    BuildContext context,
    int currentBet,
    int maxRaiseTo,
  ) async {
    if (maxRaiseTo <= currentBet) {
      return null;
    }

    final c = TextEditingController(text: maxRaiseTo.toString());

    return showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Subir"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Apuesta actual: $currentBet"),
            Text("Puedes subir como máximo hasta: $maxRaiseTo"),
            const SizedBox(height: 8),
            TextField(
              controller: c,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Subir hasta",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(c.text.trim());
              if (v == null) return;

              if (v <= currentBet) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("La subida debe superar la apuesta actual"),
                  ),
                );
                return;
              }

              if (v > maxRaiseTo) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("No puedes subir más de $maxRaiseTo")),
                );
                return;
              }

              Navigator.pop(context, v);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.phase,
    required this.isHost,
    required this.myTurn,
    required this.meReady,
    required this.toCall,
    required this.currentBet,
    required this.maxRaiseTo,
    required this.onReady,
    required this.onStart,
    required this.onFold,
    required this.onCheckOrCall,
    required this.onRaise,
    required this.onNextHand,
  });

  final PokerPhase phase;
  final bool isHost;
  final bool myTurn;
  final bool meReady;
  final int toCall;
  final int currentBet;
  final int maxRaiseTo;

  final VoidCallback onReady;
  final VoidCallback onStart;
  final VoidCallback onFold;
  final VoidCallback onCheckOrCall;
  final VoidCallback onRaise;
  final VoidCallback onNextHand;

  @override
  Widget build(BuildContext context) {
    if (phase == PokerPhase.waiting) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: Row(
          children: [
            Expanded(
              child: FilledButton.tonal(
                onPressed: onReady,
                child: Text(meReady ? "Quitar Ready" : "Ready"),
              ),
            ),
            const SizedBox(width: 8),
            if (isHost)
              Expanded(
                child: FilledButton(
                  onPressed: onStart,
                  child: const Text("Empezar mano"),
                ),
              ),
          ],
        ),
      );
    }

    if (phase == PokerPhase.showdown) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
        child: isHost
            ? FilledButton(
                onPressed: onNextHand,
                child: const Text("Siguiente mano"),
              )
            : const SizedBox.shrink(),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: FilledButton(
              onPressed: myTurn ? onFold : null,
              child: const Text("FOLD"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonal(
              onPressed: myTurn ? onCheckOrCall : null,
              child: Text(toCall == 0 ? "CHECK" : "CALL $toCall"),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonal(
              onPressed: (myTurn && maxRaiseTo > currentBet) ? onRaise : null,
              child: const Text("RAISE"),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalHandPanel extends StatelessWidget {
  const _LocalHandPanel({
    required this.myHand,
    required this.playerName,
    required this.stack,
    required this.betThisStreet,
  });

  final List<String> myHand;
  final String playerName;
  final int stack;
  final int betThisStreet;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 0, 8, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outline.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  playerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Stack: $stack    Bet: $betThisStreet",
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Row(
            children: [
              SizedBox(
                width: 58,
                child: PokerCardView(
                  faceUp: myHand.isNotEmpty,
                  cardId: myHand.isNotEmpty ? myHand[0] : null,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 58,
                child: PokerCardView(
                  faceUp: myHand.length > 1,
                  cardId: myHand.length > 1 ? myHand[1] : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}