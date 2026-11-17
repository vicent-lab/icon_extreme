import 'package:material_ui/material_ui.dart';

import '../design/theme.dart';

/// The ICON mark. One place, so swapping in the real logo later changes every screen at once.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Brand.ink, borderRadius: BorderRadius.circular(size / 4)),
          child: Icon(Icons.apartment, color: Brand.gold, size: size * 0.56),
        ),
        const SizedBox(width: 10),
        Text('ICON', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]);
}
