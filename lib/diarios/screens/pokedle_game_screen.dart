import 'package:flutter/material.dart';
import 'package:peb/diarios/models/daily_game_models.dart';
import 'package:peb/diarios/repositories/daily_games_repository.dart';
import '../repositories/dle_data_repository.dart';
import 'dle_daily_game_screen.dart';

class PokedleGameScreen extends StatelessWidget {
  const PokedleGameScreen({
    super.key,
    required this.currentProfileId,
    required this.repository,
  });

  final String currentProfileId;
  final DailyGamesRepository repository;

  @override
  Widget build(BuildContext context) {
    const dataRepo = DleDataRepository();

    return DleDailyGameScreen(
      gameId: DailyGameId.pokedle,
      title: 'Pokedle',
      currentProfileId: currentProfileId,
      repository: repository,
      searchByPrefix: dataRepo.searchPokemonByPrefix,
      submitGuess: repository.submitPokedleGuess,
      numericLabel: 'Generacion',
      groupALabel: 'Tipo',
      groupBLabel: 'Fase evolutiva',
      groupCLabel: 'Color',
    );
  }
}