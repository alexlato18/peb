import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/tag_admin_repository.dart';
import '../data/tag_style_repository.dart';
import '../models/profile.dart';
import '../widgets/tag_chip.dart';
import 'tag_style_editor_sheet.dart';

class TagsAdminScreen extends StatefulWidget {
  const TagsAdminScreen({
    super.key,
    required this.currentRole,
    required this.repo,
  });

  final String currentRole; // "COMUN", "ADMIN", "ORGANIZADOR", "DIOS"
  final TagAdminRepository repo;

  @override
  State<TagsAdminScreen> createState() => _TagsAdminScreenState();
}

class _TagsAdminScreenState extends State<TagsAdminScreen> {
  bool get _isAdminPlus =>
      widget.currentRole == "ADMIN" ||
      widget.currentRole == "ORGANIZADOR" ||
      widget.currentRole == "DIOS";

  late final TagStyleRepository _styleRepo;

  @override
  void initState() {
    super.initState();
    _styleRepo = TagStyleRepository(FirebaseFirestore.instance);
  }
  Future<void> confirmDeleteTag(String tag, List<Profile> profiles) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar tag'),
      content: Text(
        '¿Seguro que quieres eliminar el tag "$tag"?\n\n'
        'Se eliminará de todos los usuarios y no se puede deshacer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );

  if (confirm != true) return;

  try {
    await widget.repo.removeTagEverywhere(
      tag: tag,
      profiles: profiles,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tag "$tag" eliminado ✅')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al eliminar el tag: $e')),
    );
  }
}
  Future<void> _createNewTag() async {
  final ctrl = TextEditingController();

  final name = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nuevo tag'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'Nombre del tag',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => Navigator.of(ctx).pop(ctrl.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
          child: const Text('Crear'),
        ),
      ],
    ),
  );
  

  final tag = (name ?? '').trim();
  if (tag.isEmpty) return;

  // Opcional: normaliza
  final normalized = tag.toUpperCase();

  try {
    await _styleRepo.addGlobalTag(normalized);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tag "$normalized" creado ✅')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('No se pudo crear el tag: $e')),
    );
  }
}

  @override
  Widget build(BuildContext context) {
    if (!_isAdminPlus) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de tags')),
        body: const Center(child: Text('No tienes permisos.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de tags'),
        actions: [
          IconButton(
            tooltip: 'Crear tag',
            onPressed: _createNewTag,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<Profile>>(
        stream: widget.repo.watchProfiles(),
        builder: (context, snapProfiles) {
          if (!snapProfiles.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final profiles = snapProfiles.data!;
          return StreamBuilder<Map<String, TagStyle>>(
  stream: _styleRepo.watchStyles(),
  builder: (context, snapStyles) {
    final styles = snapStyles.data ?? const <String, TagStyle>{};

          return StreamBuilder<List<String>>(
            stream: _styleRepo.watchAllTags(),
            builder: (context, snapAllTags) {
              final globalTags = snapAllTags.data ?? const <String>[];

              final tagsSet = <String>{...globalTags};

              for (final p in profiles) {
                for (final t in p.tags) {
                  final clean = t.trim();
                  if (clean.isNotEmpty) tagsSet.add(clean);
                }
              }

              final tags = tagsSet.toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

              if (tags.isEmpty) {
                return const Center(child: Text('No hay tags todavía.'));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final tag = tags[i];
                  final membersCount = profiles.where((p) => p.tags.contains(tag)).length;
                  final style = styles[tag] ?? TagStyle.fallback;

                  return ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    title: Row(
                      children: [
                        TagChip(label: tag, style: style),
                        const SizedBox(width: 12),
                        Expanded(child: Text('$membersCount usuario(s)')),
                      ],
                    ),
                    trailing: const Icon(Icons.more_horiz),
                    onTap: () => _openTagActions(
                      context: context,
                      tag: tag,
                      profiles: profiles,
                    ),
                  );
                },
              );
            },
          );
        },
      );
        },
      ),
    );
  }

  void _openTagActions({
    required BuildContext context,
    required String tag,
    required List<Profile> profiles,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.group),
              title: const Text('Editar miembros'),
              onTap: () {
                Navigator.of(sheetCtx).pop();
                _openTagEditor(tag, profiles);
              },
            ),
            ListTile(
              leading: const Icon(Icons.palette),
              title: const Text('Editar estilo'),
              onTap: () async {
                Navigator.of(sheetCtx).pop();

                final latest = await _styleRepo.getStyleOnce(tag);
                if (!mounted) return;

                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => TagStyleEditorSheet(
                    tag: tag,
                    initial: latest,
                    onSave: (style) => _styleRepo.upsertStyle(tag, style),
                    onReset: () => _styleRepo.deleteStyle(tag),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reset estilo'),
              subtitle: const Text('Vuelve al estilo por defecto'),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await _styleRepo.deleteStyle(tag);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Estilo de "$tag" reseteado ✅')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text(
                'Eliminar tag',
                style: TextStyle(color: Colors.red),
              ),
              subtitle: const Text('Se eliminará de todos los usuarios'),
              onTap: () async {
                Navigator.of(sheetCtx).pop();
                await confirmDeleteTag(tag, profiles);
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _openTagEditor(String tag, List<Profile> profiles) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _TagMembersSheet(
        tag: tag,
        profiles: profiles,
        repo: widget.repo,
      ),
    );
  }
}

class _TagMembersSheet extends StatefulWidget {
  const _TagMembersSheet({
    required this.tag,
    required this.profiles,
    required this.repo,
  });

  final String tag;
  final List<Profile> profiles;
  final TagAdminRepository repo;

  @override
  State<_TagMembersSheet> createState() => _TagMembersSheetState();
}

class _TagMembersSheetState extends State<_TagMembersSheet> {
  final _searchCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tag = widget.tag;

    final members = widget.profiles.where((p) => p.tags.contains(tag)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = q.isEmpty
        ? members
        : members.where((p) => p.name.toLowerCase().contains(q)).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: AbsorbPointer(
          absorbing: _busy,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Miembros: $tag',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Añadir usuarios',
                    onPressed: () => _pickAndAddUsers(tag: tag),
                    icon: const Icon(Icons.person_add_alt_1),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'Buscar dentro del tag',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('No hay usuarios (o no coinciden con la búsqueda).'),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      return ListTile(
                        title: Text(p.name),
                        subtitle: Text(p.role),
                        trailing: IconButton(
                          tooltip: 'Quitar',
                          onPressed: () => _removeMember(profileId: p.id, tag: tag),
                          icon: const Icon(Icons.close),
                        ),
                      );
                    },
                  ),
                ),
              if (_busy) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeMember({
    required String profileId,
    required String tag,
  }) async {
    setState(() => _busy = true);
    try {
      await widget.repo.removeTagFromProfile(profileId: profileId, tag: tag);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickAndAddUsers({required String tag}) async {
    final candidates = widget.profiles.where((p) => !p.tags.contains(tag)).toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos los usuarios ya tienen este tag.')),
      );
      return;
    }

    final selected = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) => _MultiPickProfilesDialog(
        title: 'Añadir usuarios a "$tag"',
        profiles: candidates,
      ),
    );

    if (selected == null || selected.isEmpty) return;

    setState(() => _busy = true);
    try {
      await widget.repo.applyMembersDelta(
        tag: tag,
        addToProfileIds: selected,
        removeFromProfileIds: const {},
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _MultiPickProfilesDialog extends StatefulWidget {
  const _MultiPickProfilesDialog({
    required this.title,
    required this.profiles,
  });

  final String title;
  final List<Profile> profiles;

  @override
  State<_MultiPickProfilesDialog> createState() => _MultiPickProfilesDialogState();
}

class _MultiPickProfilesDialogState extends State<_MultiPickProfilesDialog> {
  final _searchCtrl = TextEditingController();
  final Set<String> _selected = {};

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = q.isEmpty
        ? widget.profiles
        : widget.profiles.where((p) => p.name.toLowerCase().contains(q)).toList();

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Buscar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final p = list[i];
                  final checked = _selected.contains(p.id);
                  return CheckboxListTile(
                    value: checked,
                    onChanged: (v) {
                      setState(() {
                        if (v == true) {
                          _selected.add(p.id);
                        } else {
                          _selected.remove(p.id);
                        }
                      });
                    },
                    title: Text(p.name),
                    subtitle: Text(p.role),
                    controlAffinity: ListTileControlAffinity.leading,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pop(_selected),
          child: Text('Añadir (${_selected.length})'),
        ),
      ],
    );
  }
}
