import 'package:material_ui/material_ui.dart';

import '../../core/design/theme.dart';
import '../../core/install/install.dart';
import '../../core/widgets.dart';

/// "Install ICON" card. Hidden once the app is installed or the person closes it.
class InstallCard extends StatefulWidget {
  const InstallCard({super.key});
  @override
  State<InstallCard> createState() => _InstallCardState();
}

class _InstallCardState extends State<InstallCard> {
  static bool _closed = false; // stays closed until the app is reopened
  late InstallState _state = installState();

  Future<void> _install() async {
    final ok = await installNow();
    if (!mounted) return;
    setState(() => _state = installState());
    if (ok) showOk(context, 'Installed. Open ICON from your home screen.');
  }

  void _iosSteps() => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Add ICON to your iPhone'),
          content: const Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Step(1, 'Open this page in Safari.'),
            _Step(2, 'Tap the Share button (the square with an arrow pointing up).'),
            _Step(3, 'Scroll down and tap "Add to Home Screen", then "Add".'),
            SizedBox(height: 8),
            Text('Open ICON from your home screen afterwards. Notifications only work from there.', style: TextStyle(color: Colors.black54, fontSize: 13)),
          ]),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
        ),
      );

  void _otherSteps() => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Install ICON'),
          content: const Text('Open your browser menu (the three dots) and choose "Install app" or "Add to Home screen". '
              'Chrome and Edge work best.'),
          actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
        ),
      );

  @override
  Widget build(BuildContext context) {
    if (_closed || _state == InstallState.installed) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        color: Brand.ink,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(children: [
            const BrandMark(size: 36, showName: false),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Install ICON on this device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                SizedBox(height: 2),
                Text('Opens like an app, and can alert you to updates and messages.', style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
            const SizedBox(width: 8),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Brand.gold, foregroundColor: Brand.ink),
              onPressed: switch (_state) {
                InstallState.ready => _install,
                InstallState.ios => _iosSteps,
                _ => _otherSteps,
              },
              child: Text(_state == InstallState.ready ? 'Install' : 'How'),
            ),
            IconButton(
              tooltip: 'Not now',
              onPressed: () => setState(() => _closed = true),
              icon: const Icon(Icons.close, color: Colors.white70),
            ),
          ]),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step(this.n, this.text);
  final int n;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          CircleAvatar(radius: 12, backgroundColor: Brand.ink, child: Text('$n', style: const TextStyle(color: Colors.white, fontSize: 12))),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ]),
      );
}
