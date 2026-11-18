import 'package:material_ui/material_ui.dart';

/// The ICON eye logo. One place, so every screen shows the same mark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 36, this.showName = true, this.light = false});
  final double size;
  final bool showName, light;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.22),
          child: Image.asset('assets/logo.png', width: size, height: size, semanticLabel: 'ICON'),
        ),
        if (showName) ...[
          const SizedBox(width: 10),
          Text('ICON',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: light ? Colors.white : null,
                  )),
        ],
      ]);
}
