import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'media_viewer_screen.dart';

import '../../data/profile_repository.dart';
import '../../models/profile.dart';
import '../data/event_repository.dart';
import '../data/photo_repository.dart';
import '../models/event_album.dart';
import '../models/photo_item.dart';

class EventDetailScreen extends StatefulWidget {
  const EventDetailScreen({
    super.key,
    required this.event,
    required this.eventRepository,
    required this.photoRepository,
    required this.profileRepository,
    required this.currentProfile,
  });

  final EventAlbum event;
  final EventRepository eventRepository;
  final PhotoRepository photoRepository;
  final ProfileRepository profileRepository;
  final Profile currentProfile;
  

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}
bool _onlyTaggedMine = false;

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool get _isHighRole =>
      ['DIOS', 'ADMIN', 'ORGANIZADOR'].contains(widget.currentProfile.role);

  bool get _isAdminOrGod =>
      ['DIOS', 'ADMIN'].contains(widget.currentProfile.role);

  bool get _isCreator => widget.event.createdBy == widget.currentProfile.id;

  bool get _canManageParticipants => _isCreator || _isHighRole;
  final Set<String> _filterTaggedProfileIds = {};
  Future<void> _openPeopleFilter() async {
  final profiles = await widget.profileRepository.watchProfiles().first;
  final temp = <String>{..._filterTaggedProfileIds};

  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setStateDialog) {
        return AlertDialog(
          title: const Text('Filtrar por personas'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in profiles)
                  CheckboxListTile(
                    value: temp.contains(p.id),
                    title: Text(p.name),
                    subtitle: Text(p.role),
                    onChanged: (v) {
                      setStateDialog(() {
                        if (v == true) {
                          temp.add(p.id);
                        } else {
                          temp.remove(p.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                temp.clear();
                setStateDialog(() {});
              },
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    ),
  );

  if (ok != true) return;

  setState(() {
    _filterTaggedProfileIds
      ..clear()
      ..addAll(temp);
  });
}

  Future<void> _uploadMenu(String eventId) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Subir fotos'),
              onTap: () => Navigator.pop(context, 'images'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Subir vídeo'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (choice == null) return;

    final picker = ImagePicker();

    if (choice == 'images') {
  final files = await picker.pickMultiImage(imageQuality: 85);
  if (files.isEmpty) return;

  int ok = 0;
  int fail = 0;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Subiendo ${files.length} fotos...')),
  );

  for (final f in files) {
    try {
      await widget.photoRepository.uploadMedia(
        eventId: eventId,
        file: File(f.path),
        uploaderProfileId: widget.currentProfile.id,
        originalFileName: f.name,
        mimeType: f.mimeType,
      );
      ok++;
    } catch (e) {
      fail++;
      // opcional: log
      debugPrint('Error subiendo ${f.name}: $e');
    }
  }

  if (!mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('Subida completada: $ok OK · $fail fallos')),
  );
}


    if (choice == 'video') {
      final v = await picker.pickVideo(source: ImageSource.gallery);
      if (v == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subiendo vídeo...')),
      );

      await widget.photoRepository.uploadMedia(
        eventId: eventId,
        file: File(v.path),
        uploaderProfileId: widget.currentProfile.id,
        originalFileName: v.name,
        mimeType: v.mimeType,
      );
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subida completada')),
    );
  }

  Future<void> _confirmDeleteEvent(String eventId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar evento'),
        content: const Text(
          'Se eliminará el evento y sus registros de fotos.\n'
          'En MVP, esto no borra miles de fotos de golpe (si hay muchas). ¿Seguro?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar')),
        ],
      ),
    );

    if (ok != true) return;

    await widget.eventRepository.deleteEventWithPhotos(eventId: eventId);

    if (mounted) Navigator.pop(context);
  }

  Future<void> _openAddParticipants(EventAlbum event) async {
    final profiles = await widget.profileRepository.watchProfiles().first;

    final selectable =
        profiles.where((p) => !event.participantIds.contains(p.id)).toList();
    if (selectable.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay perfiles nuevos para añadir')),
      );
      return;
    }

    final selected = <String>{};

    final result = await showDialog<bool>(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Añadir participantes'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final p in selectable)
                      CheckboxListTile(
                        value: selected.contains(p.id),
                        onChanged: (v) {
                          setStateDialog(() {
                            if (v == true) {
                              selected.add(p.id);
                            } else {
                              selected.remove(p.id);
                            }
                          });
                        },
                        title: Text(p.name),
                        subtitle: Text(p.role),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar')),
                FilledButton(
                  onPressed:
                      selected.isEmpty ? null : () => Navigator.pop(context, true),
                  child: const Text('Añadir'),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != true || selected.isEmpty) return;

    await widget.eventRepository.addParticipants(
      eventId: event.id,
      participantIds: selected.toList(),
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Participantes añadidos')),
    );
  }

  /// ✅ IDEA 1: borrar solo desde UI para uploader o DIOS (el resto no ve el botón)
  Future<void> _confirmDeleteMedia({
    required String eventId,
    required PhotoItem item,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar'),
        content: Text(
          item.mediaType == 'VIDEO'
              ? '¿Eliminar este vídeo del álbum?'
              : '¿Eliminar esta foto del álbum?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await widget.photoRepository.deletePhoto(eventId: eventId, photo: item);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elemento eliminado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<EventAlbum>(
      stream: widget.eventRepository.watchEvent(widget.event.id),
      builder: (context, snapEvent) {
        if (snapEvent.hasError) {
          return Scaffold(
            body: Center(child: Text('Error: ${snapEvent.error}')),
          );
        }
        if (!snapEvent.hasData) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.event.name)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        
        final event = snapEvent.data!;
        final dateStr = DateFormat('dd/MM/yyyy').format(event.date);
        final isPrivate = event.visibility == 'PRIVATE';
        final Stream<List<PhotoItem>> photosStream = _onlyTaggedMine
        ? widget.photoRepository.watchTaggedPhotos(
            event.id,
            widget.currentProfile.id,
            limit: 150,
          )
        : widget.photoRepository.watchPhotos(event.id, limit: 150);

        return Scaffold(
          appBar: AppBar(
            title: Text(event.name),
            actions: [
              if (_canManageParticipants)
                IconButton(
                  tooltip: 'Añadir participantes',
                  icon: const Icon(Icons.group_add),
                  onPressed: () => _openAddParticipants(event),
                ),
              if (_isAdminOrGod)
                IconButton(
                  tooltip: 'Eliminar evento',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDeleteEvent(event.id),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _uploadMenu(event.id),
            icon: const Icon(Icons.cloud_upload),
            label: const Text('Subir'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .primary
                              .withOpacity(0.15),
                          child: Icon(isPrivate ? Icons.lock : Icons.public),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$dateStr · ${isPrivate ? "Privado" : "Público"}'),
                              const SizedBox(height: 3),
                              Text(
                                'Participantes: ${event.participantIds.length}',
                                style: TextStyle(color: Colors.white.withOpacity(0.75)),
                              ),
                            ],
                          ),
                        ),
                        if (event.countsForGala)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withOpacity(0.7),
                              ),
                            ),
                            child: const Text('Gala'),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _openPeopleFilter,
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: Text(
                            _filterTaggedProfileIds.isEmpty
                                ? 'Filtrar por personas'
                                : 'Filtro: ${_filterTaggedProfileIds.length} seleccionadas',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (_filterTaggedProfileIds.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        IconButton(
                          tooltip: 'Limpiar filtro',
                          onPressed: () => setState(() => _filterTaggedProfileIds.clear()),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                ),

              Expanded(
  child: Builder(
    builder: (context) {
      // ✅ Stream base:
      // - sin filtro -> todas
      // - con filtro -> query por el primero (y luego AND en cliente)
      final Stream<List<PhotoItem>> photosStream = _filterTaggedProfileIds.isEmpty
          ? widget.photoRepository.watchPhotos(event.id, limit: 150)
          : widget.photoRepository.watchTaggedPhotos(
              event.id,
              _filterTaggedProfileIds.first,
              limit: 150,
            );

      return StreamBuilder<List<PhotoItem>>(
        stream: photosStream,
        builder: (context, snapPhotos) {
          if (snapPhotos.hasError) {
            return Center(child: Text('Error: ${snapPhotos.error}'));
          }
          if (!snapPhotos.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final all = snapPhotos.data!;

          // ✅ AND: deben estar TODAS las personas seleccionadas
          final photos = _filterTaggedProfileIds.isEmpty
              ? all
              : all
                  .where((it) => _filterTaggedProfileIds.every(
                        (pid) => it.taggedProfileIds.contains(pid),
                      ))
                  .toList();

          if (photos.isEmpty) {
            return Center(
              child: Text(
                _filterTaggedProfileIds.isEmpty
                    ? 'Aún no hay fotos en este álbum.'
                    : 'No hay fotos que cumplan el filtro.',
              ),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: photos.length,
            itemBuilder: (context, i) {
  final p = photos[i];

  final canDelete = (p.uploadedBy == widget.currentProfile.id) ||
      (widget.currentProfile.role == 'DIOS');

  return Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaViewerScreen(
              items: photos,
              initialIndex: i,
              title: event.name,
              eventId: event.id,
              currentProfile: widget.currentProfile,
              profileRepository: widget.profileRepository,
              photoRepository: widget.photoRepository,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 👇 IMPORTANTÍSIMO: la preview NO debe capturar taps
            IgnorePointer(
              child: Hero(
                tag: 'media_${p.id}',
                child: Image.network(
                  p.downloadURL,
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // 👇 Overlay de play, también NO captura taps
            if (p.mediaType == 'VIDEO')
              IgnorePointer(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.play_arrow,
                      size: 34,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            // ✅ Botón borrar SÍ captura taps (por eso NO va dentro de IgnorePointer)
            if (canDelete)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 34,
                      minHeight: 34,
                    ),
                    onPressed: () => _confirmDeleteMedia(
                      eventId: event.id,
                      item: p,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
},

          );
        },
      );
    },
  ),
),

            ],
          ),
        );
      },
    );
  }
}
