import 'package:material_ui/material_ui.dart';

/// Page frame: title on top, content below, same padding everywhere (keeps screens uncluttered).
class PageFrame extends StatelessWidget {
  const PageFrame({super.key, required this.title, this.subtitle, this.actions = const [], required this.child});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    final header = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: t.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
      if (subtitle != null)
        Padding(padding: const EdgeInsets.only(top: 2), child: Text(subtitle!, style: t.bodyMedium?.copyWith(color: Colors.black54))),
    ]);
    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 16 : 28, narrow ? 16 : 28, narrow ? 16 : 28, 0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (narrow) ...[
          header,
          if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 8, runSpacing: 8, children: actions)),
        ] else
          Row(children: [Expanded(child: header), ...actions]),
        const SizedBox(height: 20),
        Expanded(child: child),
      ]),
    );
  }
}
