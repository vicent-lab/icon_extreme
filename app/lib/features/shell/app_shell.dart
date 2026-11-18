import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/design/theme.dart';
import '../../core/roles.dart';
import '../../core/widgets.dart';
import '../../data/providers.dart';
import '../collab/notification_bell.dart';

class _Item {
  const _Item(this.section, this.path, this.label, this.icon);
  final Section section;
  final String path, label;
  final IconData icon;
}

class _Group {
  const _Group(this.title, this.items);
  final String title;
  final List<_Item> items;
}

/// Grouped navigation (instead of one flat list of 11 links). Items a role can't open are removed.
const _groups = [
  _Group('Overview', [_Item(Section.dashboard, '/', 'Dashboard', Icons.space_dashboard_outlined)]),
  _Group('Sales & projects', [
    _Item(Section.leads, '/leads', 'Leads', Icons.inbox_outlined),
    _Item(Section.projects, '/projects', 'Projects', Icons.construction_outlined),
  ]),
  _Group('Website content', [
    _Item(Section.services, '/services', 'Services', Icons.handyman_outlined),
    _Item(Section.team, '/team', 'Team', Icons.groups_outlined),
    _Item(Section.testimonials, '/testimonials', 'Testimonials', Icons.format_quote_outlined),
    _Item(Section.blog, '/blog', 'Blog', Icons.article_outlined),
  ]),
  _Group('Admin', [
    _Item(Section.users, '/users', 'Users & roles', Icons.admin_panel_settings_outlined),
    _Item(Section.settings, '/settings', 'Company settings', Icons.settings_outlined),
  ]),
];

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.location});
  final Widget child;
  final String location;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).value;
    final role = profile?.role ?? AppRole.client;
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final nav = _NavList(role: role, location: location, onTap: (p) {
      context.go(p);
      if (!wide) Navigator.of(context).maybePop();
    });
    final user = _UserTile(name: profile?.displayName ?? '', role: role);

    final drawerBody = Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 8, 12),
        child: Row(children: [const BrandMark(), const Spacer(), if (wide) const NotificationBell(path: '/notifications')]),
      ),
      Expanded(child: nav),
      const Divider(),
      user,
    ]);

    if (wide) {
      return Scaffold(
        body: Row(children: [
          SizedBox(width: 248, child: ColoredBox(color: Colors.white, child: drawerBody)),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ]),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const BrandMark(size: 30), backgroundColor: Colors.white, actions: const [NotificationBell(path: '/notifications'), SizedBox(width: 8)]),
      drawer: Drawer(child: drawerBody),
      body: child,
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({required this.role, required this.location, required this.onTap});
  final AppRole role;
  final String location;
  final void Function(String) onTap;

  bool _selected(String path) => path == '/' ? location == '/' : location.startsWith(path);

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final g in _groups) {
      final items = g.items.where((i) => canOpen(role, i.section)).toList();
      if (items.isEmpty) continue;
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Text(g.title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1, color: Colors.black54)),
      ));
      for (final i in items) {
        final sel = _selected(i.path);
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 1),
          child: ListTile(
            dense: true,
            selected: sel,
            selectedTileColor: Brand.concrete,
            selectedColor: Brand.ink,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            leading: Icon(i.icon, size: 20),
            title: Text(i.label, style: TextStyle(fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
            onTap: () => onTap(i.path),
          ),
        ));
      }
    }
    return ListView(children: children);
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.name, required this.role});
  final String name;
  final AppRole role;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: () => context.go('/profile'),
        title: Text(name.isEmpty ? 'Signed in' : name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${role.label} · My profile'),
        trailing: IconButton(
          tooltip: 'Sign out',
          icon: const Icon(Icons.logout),
          onPressed: () => Supabase.instance.client.auth.signOut(),
        ),
      );
}
