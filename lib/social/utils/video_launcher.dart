import 'package:url_launcher/url_launcher.dart';

class VideoLauncher {
  static Future<void> openExternal(String url) async {
    final uri = Uri.parse(url);

    final ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      throw Exception('No se pudo abrir el vídeo.');
    }
  }
}