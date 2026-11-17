import 'package:material_ui/material_ui.dart';

import '../design/tokens.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.label, {super.key, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Tone.idle;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(Radii.pill),
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}
