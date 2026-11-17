import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/theme.dart';

/// The page an invitation link opens. It trades the one-time code in the link for a signed-in
/// session, then asks the person to choose a password.
class AcceptPage extends StatefulWidget {
  const AcceptPage({super.key, required this.tokenHash, required this.type});
  final String? tokenHash, type;
  @override
  State<AcceptPage> createState() => _AcceptPageState();
}

class _AcceptPageState extends State<AcceptPage> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _accept();
  }

  Future<void> _accept() async {
    final hash = widget.tokenHash;
    if (hash == null || hash.isEmpty) {
      setState(() => _error = 'This invitation link is incomplete. Ask for a new one.');
      return;
    }
    try {
      await Supabase.instance.client.auth.verifyOTP(
        tokenHash: hash,
        type: widget.type == 'recovery' ? OtpType.recovery : OtpType.invite,
      );
      if (mounted) context.go('/set-password');
    } on AuthException {
      if (mounted) setState(() => _error = 'This invitation link has expired or was already used. Ask your ICON contact for a new one.');
    } catch (_) {
      if (mounted) setState(() => _error = 'Cannot reach the server. Check your internet and open the link again.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _error == null
                  ? const Column(mainAxisSize: MainAxisSize.min, children: [
                      CircularProgressIndicator(color: Brand.ink),
                      SizedBox(height: 16),
                      Text('Opening your invitation...'),
                    ])
                  : Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(onPressed: () => context.go('/login'), child: const Text('Go to sign in')),
                    ]),
            ),
          ),
        ),
      );
}
