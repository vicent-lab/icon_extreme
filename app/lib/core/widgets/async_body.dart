import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Shows loading / error (with retry) / data, so no screen is ever blank or stuck.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.onRetry, required this.builder});
  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T data) builder;

  @override
  Widget build(BuildContext context) => value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not load this. You may not have permission, or you are offline.'),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
          ]),
        ),
        data: builder,
      );
}
