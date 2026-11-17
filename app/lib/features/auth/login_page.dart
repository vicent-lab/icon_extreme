import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/theme.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _show = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      // The router moves us on automatically once the session exists.
    } on AuthException {
      // Same message for "no such user" and "wrong password" so nobody can probe for accounts.
      setState(() => _error = 'The email or password was not recognised.');
    } catch (_) {
      setState(() => _error = 'Cannot reach the server. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Where Google sends the person back to. Must be listed in Supabase > Authentication > URL Configuration.
  static const _mobileRedirect = 'com.iconconstruction.icon://login-callback/';

  Future<void> _google() async {
    if (_busy) return;
    setState(() { _busy = true; _error = null; });
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : _mobileRedirect,
        // Always show Google's account chooser, so you can switch accounts after signing out.
        queryParams: const {'prompt': 'select_account'},
      );
      // On web the page leaves for Google and comes back signed in. Nothing more to do here.
    } catch (_) {
      if (mounted) setState(() => _error = 'Google sign-in could not start. Try again, or use your email.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() { _email.dispose(); _password.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: AutofillGroup(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.apartment, color: Brand.gold),
                      ),
                      const SizedBox(width: 12),
                      Text('ICON Construction', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    ]),
                    const SizedBox(height: 28),
                    Text('Sign in', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('Use the account ICON invited you with.', style: t.bodyMedium),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _password,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.password],
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _show ? 'Hide password' : 'Show password',
                          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _show = !_show),
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: () => context.go('/forgot'), child: const Text('Forgot password?')),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _google,
                      icon: const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Continue with Google'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Row(children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('or')),
                      Expanded(child: Divider()),
                    ]),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Sign in'),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
