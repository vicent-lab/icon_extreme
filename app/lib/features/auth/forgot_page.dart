import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors.dart';
import '../../core/widgets.dart';

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});
  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final _email = TextEditingController();
  bool _busy = false, _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim().toLowerCase();
    if (!email.contains('@')) {
      showError(context, 'Type the email address you use to sign in.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email, redirectTo: kIsWeb ? Uri.base.origin : null);
    } catch (e) {
      // Do not reveal whether the address has an account. Only real faults are shown.
      if (e is! AuthException && mounted) showError(context, friendlyError(e));
    }
    if (mounted) setState(() { _busy = false; _sent = true; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Forgot your password?', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    if (_sent)
                      const Text('If that address has an account, a reset link is on its way. It can take a few minutes. '
                          'If nothing arrives, ask your ICON contact to send you a new invitation link.')
                    else ...[
                      const Text('Type your email and we will send you a link to choose a new one.'),
                      const SizedBox(height: 18),
                      TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email')),
                      const SizedBox(height: 18),
                      FilledButton(onPressed: _busy ? null : _send, child: const Text('Send reset link')),
                    ],
                    const SizedBox(height: 12),
                    TextButton(onPressed: () => context.go('/login'), child: const Text('Back to sign in')),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
