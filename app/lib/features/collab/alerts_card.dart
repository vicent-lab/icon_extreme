import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config.dart';
import '../../core/design/tokens.dart';
import '../../core/errors.dart';
import '../../core/install/push.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';

/// Phone alerts on this device, plus quiet hours. Alerts always also land in the bell.
class AlertsCard extends ConsumerStatefulWidget {
  const AlertsCard({super.key});
  @override
  ConsumerState<AlertsCard> createState() => _AlertsCardState();
}

class _AlertsCardState extends ConsumerState<AlertsCard> {
  PushState? _state;
  int? _from, _to;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await pushState();
    (int?, int?) q = (20, 7);
    try {
      q = await ref.read(collabRepoProvider).quietHours();
    } catch (_) {}
    if (mounted) setState(() => (_state = s, _from = q.$1, _to = q.$2));
  }

  Future<void> _turnOn() async {
    setState(() => _busy = true);
    final r = await pushEnable(vapidPublicKey);
    try {
      if (r.startsWith('error:')) {
        if (mounted) showError(context, r.contains('blocked') ? 'Alerts are blocked. Allow notifications for this site in your browser settings, then try again.' : 'This device could not turn on alerts.');
      } else {
        await ref.read(collabRepoProvider).saveDevice(r);
        if (mounted) showOk(context, 'Alerts are on for this device.');
      }
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _turnOff() async {
    setState(() => _busy = true);
    final endpoint = await pushDisable();
    try {
      if (endpoint.isNotEmpty) await ref.read(collabRepoProvider).forgetDevice(endpoint);
    } catch (_) {}
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveQuiet(int? from, int? to) async {
    setState(() => (_from = from, _to = to));
    try {
      await ref.read(collabRepoProvider).setQuietHours(from, to);
    } catch (e) {
      if (mounted) showError(context, friendlyError(e));
    }
  }

  String _hour(int h) => '${h % 12 == 0 ? 12 : h % 12}:00 ${h < 12 ? 'am' : 'pm'}';

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final quietOn = _from != null && _to != null;
    final (text, color) = switch (s) {
      PushState.on => ('On for this device', Tone.done),
      PushState.off => ('Off for this device', Tone.idle),
      PushState.blocked => ('Blocked in your browser settings', Tone.problem),
      PushState.needsInstall => ('Install ICON on your home screen first', Tone.active),
      PushState.unsupported => ('This browser cannot show alerts', Tone.idle),
      null => ('Checking...', Tone.idle),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Phone alerts', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          const Text('Get an alert for new messages, updates and approvals. Everything also stays in the bell.', style: TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 12),
          StatusChip(text, color: color),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (s == PushState.off) FilledButton(onPressed: _busy ? null : _turnOn, child: const Text('Turn on alerts')),
            if (s == PushState.on) ...[
              OutlinedButton(
                onPressed: _busy
                    ? null
                    : () async {
                        try {
                          await ref.read(collabRepoProvider).testAlert();
                          if (context.mounted) showOk(context, 'Test sent. It should arrive in a few seconds.');
                        } catch (e) {
                          if (context.mounted) showError(context, friendlyError(e));
                        }
                      },
                child: const Text('Send me a test alert'),
              ),
              TextButton(onPressed: _busy ? null : _turnOff, child: const Text('Turn off on this device')),
            ],
          ]),
          const Divider(height: 32),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quiet hours'),
            subtitle: Text(quietOn ? 'No alerts from ${_hour(_from!)} to ${_hour(_to!)} (Kampala time)' : 'Alerts can arrive at any time'),
            value: quietOn,
            onChanged: (v) => _saveQuiet(v ? 20 : null, v ? 7 : null),
          ),
          if (quietOn)
            Wrap(spacing: 16, crossAxisAlignment: WrapCrossAlignment.center, children: [
              const Text('From'),
              DropdownButton<int>(value: _from, items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(_hour(h)))], onChanged: (v) => _saveQuiet(v, _to)),
              const Text('to'),
              DropdownButton<int>(value: _to, items: [for (var h = 0; h < 24; h++) DropdownMenuItem(value: h, child: Text(_hour(h)))], onChanged: (v) => _saveQuiet(_from, v)),
            ]),
        ]),
      ),
    );
  }
}
