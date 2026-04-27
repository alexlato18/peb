import 'package:flutter/material.dart';
import '../data/spanish_card.dart';
import '../data/spanish_deck.dart';
import '../widgets/spanish_suit_icon.dart';

class HorseRaceGameScreen extends StatefulWidget {
  const HorseRaceGameScreen({
    super.key,
    required this.playerNames,
  });

  final List<String> playerNames;

  @override
  State<HorseRaceGameScreen> createState() => _HorseRaceGameScreenState();
}

class _HorseRaceGameScreenState extends State<HorseRaceGameScreen> {
  static const int finishPosition = 8;
  static const int hiddenTrackCount = 7;

  late final List<_HorseBetEntry> _bets;
  late SpanishDeck _deck;

  bool _bettingPhase = true;
  SpanishCard? _lastCard;
  SpanishSuit? _winnerSuit;

  late final Map<SpanishSuit, SpanishCard> _horseCards;
  late final List<SpanishCard> _trackCards;

  final Map<int, bool> _revealedTrackMeters = {};
  final Map<SpanishSuit, int> _horsePositions = {};

  @override
  void initState() {
    super.initState();
    _bets = widget.playerNames
        .map((name) => _HorseBetEntry(playerName: name))
        .toList();

    _setupDeckAndBoard();
  }

  Future<void> _showAddPlayerDialog() async {
  final nameCtrl = TextEditingController();
  final drinksCtrl = TextEditingController();
  SpanishSuit? selectedSuit;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Añadir jugador'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del jugador',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: drinksCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Número de tragos',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SpanishSuit>(
                    value: selectedSuit,
                    isExpanded: true,
                    items: _horseCards.keys
                        .map(
                          (suit) => DropdownMenuItem(
                            value: suit,
                            child: Text(_suitLabel(suit)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedSuit = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Palo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final amount = int.tryParse(drinksCtrl.text.trim());

                  if (name.isEmpty || amount == null || amount < 0 || selectedSuit == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Completa bien todos los campos'),
                      ),
                    );
                    return;
                  }

                  final alreadyExists = _bets.any(
                    (b) => b.playerName.toLowerCase() == name.toLowerCase(),
                  );

                  if (alreadyExists) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ya existe un jugador con ese nombre'),
                      ),
                    );
                    return;
                  }

                  setState(() {
                    _bets.add(
                      _HorseBetEntry(
                        playerName: name,
                        amount: amount,
                        suit: selectedSuit,
                      ),
                    );
                  });

                  Navigator.pop(dialogContext);
                },
                child: const Text('Añadir'),
              ),
            ],
          );
        },
      );
    },
  );
}

  void _setupDeckAndBoard() {
  final fullDeck = SpanishDeck.shuffled40();
  final allCards = fullDeck.cardsSnapshot;

  final horseCardsList = <SpanishCard>[
    for (final suit in SpanishSuit.values)
      allCards.firstWhere(
        (c) => c.suit == suit && c.value == 11,
      ),
  ];

  final remainingCards = allCards.where((card) {
    return !(card.value == 11 && SpanishSuit.values.contains(card.suit));
  }).toList()
    ..shuffle();

  _deck = SpanishDeck.fromCards(remainingCards);

  _horseCards = {
    for (final card in horseCardsList) card.suit: card,
  };

  _trackCards = [];
  for (int i = 0; i < hiddenTrackCount; i++) {
    final card = _deck.draw();
    if (card == null) {
      throw Exception('No se pudieron preparar las cartas ocultas de pista.');
    }
    _trackCards.add(card);
  }

  _horsePositions
    ..clear()
    ..addEntries(
      _horseCards.keys.map((suit) => MapEntry(suit, 0)),
    );

  _revealedTrackMeters
    ..clear()
    ..addEntries(
      List.generate(hiddenTrackCount, (i) => MapEntry(i + 1, false)),
    );
}

  void _startRace() {
    final hasInvalidBet = _bets.any(
      (b) => b.amount == null || b.amount! < 0 || b.suit == null,
    );

    if (hasInvalidBet) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todas las apuestas')),
      );
      return;
    }

    setState(() {
      _bettingPhase = false;
    });
  }

  void _drawNextCard() {
    if (_bettingPhase || _winnerSuit != null) return;

    final card = _deck.draw();
    if (card == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No quedan cartas en el mazo')),
      );
      return;
    }

    if (_horsePositions.containsKey(card.suit)) {
      _horsePositions[card.suit] = (_horsePositions[card.suit] ?? 0) + 1;
    }

    setState(() {
      _lastCard = card;
    });

    _checkHiddenTrackCards();
    _checkWinner();
  }

  void _checkHiddenTrackCards() {
    for (int meter = 1; meter <= hiddenTrackCount; meter++) {
      if (_revealedTrackMeters[meter] == true) continue;

      final allReached = _horsePositions.values.every((pos) => pos >= meter);
      if (!allReached) continue;

      final hiddenCard = _trackCards[meter - 1];
      final affectedSuit = hiddenCard.suit;

      _revealedTrackMeters[meter] = true;

      if (_horsePositions.containsKey(affectedSuit)) {
        final current = _horsePositions[affectedSuit] ?? 0;
        final updated = meter.isOdd ? current + 1 : current - 1;
        _horsePositions[affectedSuit] = updated < 0 ? 0 : updated;
      }
    }
  }

  void _checkWinner() {
    for (final entry in _horsePositions.entries) {
      if (entry.value >= finishPosition) {
        _finishRace(entry.key);
        return;
      }
    }
  }
  
  void _finishRace(SpanishSuit winnerSuit) {
    _winnerSuit = winnerSuit;

    final winners = _bets.where((b) => b.suit == winnerSuit).toList();

    final results = winners
        .map((w) => '${w.playerName} reparte ${((w.amount ?? 0) * 2)} tragos')
        .toList();

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('¡Carrera terminada!'),
        content: winners.isEmpty
            ? Text('Ha ganado ${_suitLabel(winnerSuit)}, pero nadie apostó por ese palo.')
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ganador: ${_suitLabel(winnerSuit)}'),
                  const SizedBox(height: 12),
                  ...results.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $r'),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            child: const Text('Nueva partida'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      _bettingPhase = true;
      _lastCard = null;
      _winnerSuit = null;

      for (final bet in _bets) {
        bet.amount = null;
        bet.suit = null;
      }

      _setupDeckAndBoard();
    });
  }

  String _suitLabel(SpanishSuit suit) {
    switch (suit) {
      case SpanishSuit.oros:
        return 'Oros';
      case SpanishSuit.copas:
        return 'Copas';
      case SpanishSuit.espadas:
        return 'Espadas';
      case SpanishSuit.bastos:
        return 'Bastos';
    }
  }

  Color _suitColor(SpanishSuit suit) {
  switch (suit) {
    case SpanishSuit.oros:
      return const Color.fromARGB(255, 226, 222, 3);
    case SpanishSuit.copas:
      return const Color(0xFFB0352F);
    case SpanishSuit.espadas:
      return const Color.fromARGB(255, 31, 32, 31);
    case SpanishSuit.bastos:
      return const Color.fromARGB(255, 2, 107, 7);
  }
}

  String _trackCardLabel(int meter) {
    if (_revealedTrackMeters[meter] == true) {
      final card = _trackCards[meter - 1];
      return '${card.valueLabel} de ${card.suitLabel}';
    }
    return 'Oculta';
  }

  @override
  Widget build(BuildContext context) {
    final remaining = _deck.remaining;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Carrera de caballos'),
        actions: [
          IconButton(
            tooltip: 'Añadir jugador',
            icon: const Icon(Icons.person_add_alt_1),
            onPressed: _showAddPlayerDialog,
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _bettingPhase ? _buildBettingPhase() : _buildRacePhase(remaining),
          ),
        ),
      ),
    );
  }

  Widget _buildBettingPhase() {
    return ListView(
      children: [
        Text(
          'Fase de apuestas',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Cada jugador elige cuántos tragos apuesta y a qué palo.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        ..._bets.map((bet) {
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    bet.playerName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: bet.amount?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Apuesta',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      bet.amount = int.tryParse(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SpanishSuit>(
                    value: bet.suit,
                    isExpanded: true,
                    items: _horseCards.keys
                        .map(
                          (suit) => DropdownMenuItem(
                            value: suit,
                            child: Text(_suitLabel(suit)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        bet.suit = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Palo',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _startRace,
            child: const Text('Aceptar apuestas'),
          ),
        ),
      ],
    );
  }

  Widget _buildRacePhase(int remaining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Carrera en marcha',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          'Cartas restantes: $remaining',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        if (_lastCard != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Última carta: ${_lastCard.toString()}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        const SizedBox(height: 12),

        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(hiddenTrackCount, (index) {
                  final meter = index + 1;
                  final revealed = _revealedTrackMeters[meter] == true;

                  return Container(
                    width: 92,
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: revealed
                          ? Colors.amber.withOpacity(0.16)
                          : Colors.grey.withOpacity(0.10),
                      border: Border.all(
                        color: revealed ? Colors.amber.shade700 : Colors.grey.shade400,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        const SizedBox(height: 6),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Metro $meter',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (revealed) ...[
                              SpanishSuitIcon(
                                suit: _trackCards[meter - 1].suit,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _trackCards[meter - 1].valueLabel,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ] else ...[
                              const Icon(Icons.visibility_off, size: 20),
                              const SizedBox(height: 6),
                              const Text(
                                'Oculta',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 11),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
        ),

        Expanded(
          child: ListView(
            children: _horseCards.entries.map((entry) {
              final suit = entry.key;
              final horseCard = entry.value;
              final pos = _horsePositions[suit] ?? 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SpanishSuitIcon(
                            suit: suit,
                            size: 26,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_suitLabel(suit)} · ${horseCard.valueLabel}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text('$pos / $finishPosition'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: List.generate(finishPosition + 1, (index) {
                            final isHorse = index == pos;
                            final isGoal = index == finishPosition;

                            return Container(
                              width: 44,
                              height: 44,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: isGoal
                                    ? Colors.amber.withOpacity(0.25)
                                    : Colors.grey.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isHorse
                                      ? _suitColor(suit)
                                      : Colors.grey.shade400,
                                  width: isHorse ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: isHorse
                                    ? const Text(
                                        '🐎',
                                        style: TextStyle(fontSize: 20),
                                      )
                                    : isGoal
                                        ? const Icon(Icons.flag)
                                        : Text('$index'),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _winnerSuit == null ? _drawNextCard : null,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Sacar carta'),
          ),
        ),
      ],
    );
  }
}

class _HorseBetEntry {
  _HorseBetEntry({
    required this.playerName,
    this.amount,
    this.suit,
  });

  final String playerName;
  int? amount;
  SpanishSuit? suit;
}
