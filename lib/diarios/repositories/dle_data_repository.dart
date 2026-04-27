import '../data/loldle_data.dart';
import '../data/pokedle_data.dart';
import '../models/loldle_entry.dart';
import '../models/pokedle_entry.dart';

class DleDataRepository {
  const DleDataRepository();

  List<LoldleEntry> get lolEntries => loldleEntries;
  List<PokedleEntry> get pokemonEntries => pokedleEntries;

  List<LoldleEntry> searchLolByPrefix(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final result = lolEntries
        .where((e) => e.displayName.toLowerCase().startsWith(q))
        .toList();

    result.sort((a, b) => a.displayName.compareTo(b.displayName));
    return result.take(12).toList();
  }

  List<PokedleEntry> searchPokemonByPrefix(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final result = pokemonEntries
        .where((e) => e.displayName.toLowerCase().startsWith(q))
        .toList();

    result.sort((a, b) => a.displayName.compareTo(b.displayName));
    return result.take(12).toList();
  }

  LoldleEntry? findLolById(String id) {
    try {
      return lolEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  PokedleEntry? findPokemonById(String id) {
    try {
      return pokemonEntries.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }
}