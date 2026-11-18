import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/design/theme.dart';
import '../../core/errors.dart';
import '../../core/format.dart';
import '../../core/widgets.dart';
import '../../data/models/collab.dart';
import '../../data/providers.dart';
import 'collab_providers.dart';

final _photoUrlProvider = FutureProvider.autoDispose.family<String, String>((ref, path) => ref.watch(collabRepoProvider).photoUrl(path));

/// One conversation per project: the client, the project manager and admins.
/// Messages can be fixed for 5 minutes and are never deleted, so the chat is a record both sides can trust.
class ChatView extends ConsumerStatefulWidget {
  const ChatView({super.key, required this.projectId});
  final int projectId;
  @override
  ConsumerState<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends ConsumerState<ChatView> {
  final _text = TextEditingController();
  bool _sending = false;
  Map<String, String> _names = {};
  Map<String, DateTime> _seen = {};
  int _lastCount = -1;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  /// When new messages arrive: mark them seen, learn new names, refresh "seen" ticks.
  Future<void> _onMessages(List<ChatMessage> rows) async {
    if (rows.length == _lastCount) return;
    _lastCount = rows.length;
    final repo = ref.read(collabRepoProvider);
    try {
      await repo.markSeen(widget.projectId);
      final missing = rows.map((m) => m.authorId).toSet().difference(_names.keys.toSet());
      final names = missing.isEmpty ? <String, String>{} : await repo.names(missing);
      final seen = await repo.seenBy(widget.projectId);
      if (mounted) setState(() => (_names = {..._names, ...names}, _seen = seen));
    } catch (_) {/* ticks and names are nice-to-have */}
  }

  Future<void> _send({String? photoPath}) async {
    final body = _text.text;
    if (body.trim().isEmpty && photoPath == null) return;
    setState(() => _sending = true);
    try {
      await ref.read(collabRepoProvider).send(widget.projectId, body, photoPath: photoPath);
      _text.clear();
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendPhoto() async {
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['jpg', 'jpeg', 'png', 'webp']);
    if (f == null) return;
    if ((await f.length() ?? 0) > 10 * 1024 * 1024) {
      if (mounted) showError(context, 'That photo is over 10 MB. Please send a smaller one.');
      return;
    }
    setState(() => _sending = true);
    try {
      final path = await ref.read(collabRepoProvider).uploadPhoto(widget.projectId, f.name, await f.readAsBytes());
      await _send(photoPath: path);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _edit(ChatMessage m) async {
    final c = TextEditingController(text: m.body);
    final saved = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fix your message'),
        content: SizedBox(width: 420, child: TextField(controller: c, maxLines: 5, minLines: 2, autofocus: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text), child: const Text('Save')),
        ],
      ),
    );
    c.dispose();
    if (saved == null || saved.trim().isEmpty || saved.trim() == m.body) return;
    try {
      await ref.read(collabRepoProvider).edit(m.id, saved);
    } catch (e) {
      if (mounted) showError(context, 'It is too late to change this message. Send a new one instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(profileProvider).value?.id ?? '';
    final async = ref.watch(messagesProvider(widget.projectId));
    ref.listen(messagesProvider(widget.projectId), (_, next) => next.whenData(_onMessages));

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(children: [
        Expanded(
          child: AsyncBody<List<ChatMessage>>(
            value: async,
            onRetry: () => ref.invalidate(messagesProvider(widget.projectId)),
            builder: (rows) {
              if (rows.isEmpty) {
                return const EmptyState('No messages yet. Questions, photos and quick updates go here, and everyone on the project sees them.');
              }
              final myLast = rows.lastWhere((m) => m.authorId == me, orElse: () => rows.first);
              final seenMyLast = myLast.authorId == me && _seen.entries.any((e) => e.key != me && !e.value.isBefore(myLast.createdAt));
              final now = DateTime.now();
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.only(bottom: 8),
                itemCount: rows.length,
                itemBuilder: (context, i) {
                  final m = rows[rows.length - 1 - i];
                  final mine = m.authorId == me;
                  final prev = rows.length - 2 - i >= 0 ? rows[rows.length - 2 - i] : null;
                  final showName = !mine && (prev == null || prev.authorId != m.authorId);
                  return _Bubble(
                    message: m,
                    mine: mine,
                    name: showName ? (_names[m.authorId] ?? 'ICON team') : null,
                    seen: mine && m.id == myLast.id && seenMyLast,
                    onEdit: m.canEdit(me, now) ? () => _edit(m) : null,
                  );
                },
              );
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            IconButton(tooltip: 'Send a photo', onPressed: _sending ? null : _sendPhoto, icon: const Icon(Icons.photo_camera_outlined)),
            Expanded(
              child: TextField(
                controller: _text,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(hintText: 'Write a message', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(tooltip: 'Send', onPressed: _sending ? null : () => _send(), icon: const Icon(Icons.send)),
          ]),
        ),
      ]),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({required this.message, required this.mine, required this.name, required this.seen, required this.onEdit});
  final ChatMessage message;
  final bool mine, seen;
  final String? name;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final m = message;
    final fg = mine ? Colors.white : Brand.ink;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: EdgeInsets.only(top: name != null ? 12 : 4, left: mine ? 48 : 0, right: mine ? 0 : 48),
          child: Column(crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
            if (name != null) Padding(padding: const EdgeInsets.only(left: 4, bottom: 2), child: Text(name!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black54))),
            GestureDetector(
              onLongPress: onEdit,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: mine ? Brand.ink : Colors.white,
                  border: mine ? null : Border.all(color: Brand.line),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (m.photoPath != null)
                    ref.watch(_photoUrlProvider(m.photoPath!)).when(
                          data: (url) => InkWell(
                            onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                            child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(url, width: 260, fit: BoxFit.cover)),
                          ),
                          loading: () => const SizedBox(width: 260, height: 160, child: Center(child: CircularProgressIndicator())),
                          error: (_, _) => Text('Photo could not load', style: TextStyle(color: fg)),
                        ),
                  if (m.body.isNotEmpty)
                    Padding(padding: EdgeInsets.only(top: m.photoPath != null ? 8 : 0), child: SelectableText(m.body, style: TextStyle(color: fg, height: 1.35))),
                ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
              child: Text(
                [
                  dateTime(m.createdAt),
                  if (m.editedAt != null) 'edited',
                  if (seen) 'Seen',
                  if (onEdit != null) 'hold to fix',
                ].join(' · '),
                style: const TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
