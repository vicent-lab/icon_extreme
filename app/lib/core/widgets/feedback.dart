import 'package:material_ui/material_ui.dart';

void showError(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error));

void showOk(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message)));

/// A calm "nothing here yet" message that tells the person what to do next.
class EmptyState extends StatelessWidget {
  const EmptyState(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))),
      );
}
