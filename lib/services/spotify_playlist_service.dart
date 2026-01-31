import 'package:cloud_functions/cloud_functions.dart';
import 'package:peb/models/music_game_models.dart';

class SpotifyPlaylistService {
  SpotifyPlaylistService(FirebaseFunctions instance);

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'europe-west1');

  Future<List<MusicTrack>> fetchTracksFromPlaylist(String playlistUrl) async {
    final callable = _functions.httpsCallable(
      'spotifyGetPlaylistTracks',
      options: HttpsCallableOptions(
        timeout: const Duration(minutes: 5),
      ),
    );

    final result = await callable.call({'playlistUrl': playlistUrl});

    final List rawTracks = result.data['tracks'] as List;

    return rawTracks.map((e) {
      return MusicTrack(
        id: e['id'],
        title: e['title'],
        artists: List<String>.from(e['artists'] ?? const []),
        spotifyUrl: e['spotifyUrl'] ?? '',
        coverUrl: e['coverUrl'] ?? '',
        releaseYear: e['releaseYear'],
      );
    }).toList();
  }
}
