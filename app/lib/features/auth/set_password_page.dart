import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/theme.dart';
import '../../core/errors.dart';
import '../../core/widgets.dart';

/// Choose a password: used after an invitation and after "forgot password".
class SetPasswordPage extends StatefulWidget {
  const SetPasswordPage({super.key});
  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _form = GlobalKey<FormState>();
  final _pw = TextEditingController();
  final _again = TextEditingController();
  bool _busy = false, _show = false;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  String? _strength(String? v) {
    final t = v ?? '';
    if (t.length < 10) return 'Use at least 10 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(t) || !RegExp(r'\d').hasMatch(t)) return 'Use letters and at least one number';
    return null;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.auth.updateUser(UserAttributes(password: _pw.text, data: {'password_set': true}));
      if (mounted) {
        showOk(context, 'Password saved.');
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, friendlyError(e));
      }
    }
  }

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
                child: Form(
                  key: _form,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(
                      width: 40, height: 40, alignment: Alignment.center,
                      decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.key, color: Brand.gold, size: 20),
                    ),
                    const SizedBox(height: 20),
                    Text('Choose a password', style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('You will use it with your email to sign in.', style: t.bodyMedium),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _pw,
                      obscureText: !_show,
                      autofillHints: const [AutofillHints.newPassword],
                      decoration: InputDecoration(
                        labelText: 'New password',
                        helperText: 'At least 10 characters, with letters and a number',
                        suffixIcon: IconButton(
                          tooltip: _show ? 'Hide password' : 'Show password',
                          icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _show = !_show),
                        ),
                      ),
                      validator: _strength,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _again,
                      obscureText: !_show,
                      decoration: const InputDecoration(labelText: 'Type it again'),
                      validator: (v) => v == _pw.text ? null : 'The two passwords are not the same',
                      onFieldSubmitted: (_) => _save(),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save password'),
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
