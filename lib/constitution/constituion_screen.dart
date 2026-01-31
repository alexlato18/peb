import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

class ConstitutionScreen extends StatefulWidget {
  const ConstitutionScreen({super.key});

  @override
  State<ConstitutionScreen> createState() => _ConstitutionScreenState();
}

class _ConstitutionScreenState extends State<ConstitutionScreen> {
  bool _loading = false;
  String? _status;

  Future<void> _openConstitution() async {
    setState(() {
      _loading = true;
      _status = 'Descargando Constitución...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/constitucion.pdf');

      // (Opcional) Si ya existe, no lo vuelvas a bajar
      if (!await file.exists()) {
        final ref = FirebaseStorage.instance.ref('groups/peb/files/constitucion.pdf');
        await ref.writeToFile(file);
      }

      setState(() => _status = 'Abriendo PDF...');

      final result = await OpenFilex.open(file.path);

      if (!mounted) return;

      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo abrir: ${result.message}')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  Future<void> _forceRedownload() async {
    setState(() {
      _loading = true;
      _status = 'Forzando descarga...';
    });

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/constitucion.pdf');
      if (await file.exists()) await file.delete();

      final ref = FirebaseStorage.instance.ref('groups/peb/files/constitucion.pdf');
      await ref.writeToFile(file);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Descargado de nuevo ✅')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _status = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Constitución')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.menu_book_outlined, size: 56),
                const SizedBox(height: 12),
                const Text(
                  'Constitución',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Se abrirá con el visor de PDF de tu dispositivo.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                if (_status != null) ...[
                  Text(_status!, textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                ],

                FilledButton.icon(
                  onPressed: _loading ? null : _openConstitution,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf),
                  label: Text(_loading ? 'Cargando...' : 'Abrir Constitución'),
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: _loading ? null : _forceRedownload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Forzar descarga'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
