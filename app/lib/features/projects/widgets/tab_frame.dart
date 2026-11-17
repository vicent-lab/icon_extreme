import 'package:material_ui/material_ui.dart';

/// Every project tab has the same shape: an "Add" button on top, the list below.
class TabFrame extends StatelessWidget {
  const TabFrame({super.key, required this.addLabel, required this.onAdd, required this.child});
  final String addLabel;
  final VoidCallback onAdd;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.add), label: Text(addLabel))),
          const SizedBox(height: 12),
          Expanded(child: child),
        ]),
      );
}

/// Date pickers start empty; log and expense dates must exist, so an empty value means "today" (the database default).
Map<String, dynamic> dropNullDates(Map<String, dynamic> d) =>
    {...d}..removeWhere((k, v) => v == null && (k == 'log_date' || k == 'spent_on'));
