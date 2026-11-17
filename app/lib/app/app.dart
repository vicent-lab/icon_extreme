import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/design/theme.dart';
import '../data/providers.dart';
import 'router.dart';

class IconApp extends ConsumerWidget {
  const IconApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Someone who followed a "reset password" link must choose a new password before anything else.
    ref.listen(authStateProvider, (_, next) {
      if (next.value?.event == AuthChangeEvent.passwordRecovery) router.go('/set-password');
    });
    return MaterialApp.router(
      title: 'ICON Construction',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
