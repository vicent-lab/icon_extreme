import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/form_kit.dart';
import '../../core/providers.dart';
import '../../core/widgets.dart';

/// The company details the website shows (footer, contact page...). Only admins reach this page,
/// and the database also refuses anyone else.
class _Setting {
  const _Setting(this.key, this.label, {this.hint, this.multiline = false});
  final String key, label;
  final String? hint;
  final bool multiline;
}

const _settings = [
  _Setting('company_name', 'Company name'),
  _Setting('tagline', 'Short tagline'),
  _Setting('phone', 'Phone', hint: '+256 ...'),
  _Setting('whatsapp', 'WhatsApp number', hint: '+256 ...'),
  _Setting('email', 'Email'),
  _Setting('address', 'Office address', multiline: true),
  _Setting('opening_hours', 'Opening hours', hint: 'Mon to Fri, 8:00 to 17:00'),
  _Setting('facebook_url', 'Facebook link'),
  _Setting('instagram_url', 'Instagram link'),
  _Setting('linkedin_url', 'LinkedIn link'),
  _Setting('about_short', 'About us (short)', multiline: true),
];

final settingsProvider = FutureProvider.autoDispose<Map<String, String>>((ref) async {
  final rows = await ref.watch(supabaseProvider).from('company_settings').select('key, value');
  return {for (final r in rows) '${r['key']}': '${r['value']}'};
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => PageFrame(
        title: 'Company settings',
        subtitle: 'These details can appear on the website. Only administrators can change them.',
        child: AsyncBody<Map<String, String>>(
          value: ref.watch(settingsProvider),
          onRetry: () => ref.invalidate(settingsProvider),
          builder: (values) => _SettingsForm(initial: values),
        ),
      );
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});
  final Map<String, String> initial;
  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final Map<String, TextEditingController> _c = {
    for (final s in _settings) s.key: TextEditingController(text: widget.initial[s.key] ?? ''),
  };
  bool _busy = false;

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      final rows = [
        for (final s in _settings)
          if (_c[s.key]!.text.trim() != (widget.initial[s.key] ?? ''))
            {'key': s.key, 'value': _c[s.key]!.text.trim(), 'is_public': true},
      ];
      if (rows.isEmpty) {
        if (mounted) showOk(context, 'Nothing changed.');
      } else {
        await ref.read(supabaseProvider).from('company_settings').upsert(rows, onConflict: 'key');
        ref.invalidate(settingsProvider);
        if (mounted) showOk(context, 'Saved.');
      }
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.only(bottom: 32), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              for (final s in _settings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: TextField(
                    controller: _c[s.key],
                    minLines: s.multiline ? 3 : 1,
                    maxLines: s.multiline ? 6 : 1,
                    decoration: InputDecoration(labelText: s.label, hintText: s.hint),
                  ),
                ),
              if (_busy) const LinearProgressIndicator(),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(onPressed: _busy ? null : _save, child: const Text('Save changes')),
              ),
            ]),
          ),
        ),
      ]);
}
