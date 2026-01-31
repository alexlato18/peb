class MusicTrack {
  final String id;
  final String title;
  final List<String> artists;
  final String spotifyUrl; // open.spotify.com/track/...
  final String coverUrl;   // imagen
  final int? releaseYear;

  const MusicTrack({
    required this.id,
    required this.title,
    required this.artists,
    required this.spotifyUrl,
    required this.coverUrl,
    required this.releaseYear,
  });
}

class PlayerScore {
  final String name;
  int points;

  PlayerScore({required this.name, this.points = 0});
}
