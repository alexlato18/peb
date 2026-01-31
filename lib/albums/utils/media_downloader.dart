import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaDownloader {
  MediaDownloader._();

  static Future<String> downloadToDevice({
    required String url,
    required String fileName,
    void Function(int received, int total)? onProgress,
  }) async {
    final dir = await _getDownloadDir();
    await dir.create(recursive: true);

    final safeName = fileName.trim().isEmpty ? 'peb_media' : fileName;
    final targetPath = p.join(dir.path, safeName);

    final dio = Dio();
    await dio.download(
      url,
      targetPath,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        receiveTimeout: const Duration(minutes: 3),
      ),
    );

    return targetPath;
  }

  static Future<Directory> _getDownloadDir() async {
    if (Platform.isAndroid) {
      // Descargas "reales" en Android
      return Directory('/storage/emulated/0/Download/PEB');
    }
    // iOS / macOS / others
    final docs = await getApplicationDocumentsDirectory();
    return Directory(p.join(docs.path, 'PEB'));
  }
}
