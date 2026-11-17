/// Roles mirror the `app_role` enum in the database.
/// IMPORTANT: this only decides what to SHOW. The database (RLS) decides what is ALLOWED.
enum AppRole {
  superAdmin('super_admin', 'Super admin'),
  admin('admin', 'Admin'),
  projectManager('project_manager', 'Project manager'),
  editor('editor', 'Editor'),
  support('support', 'Support'),
  client('client', 'Client');

  const AppRole(this.db, this.label);
  final String db;
  final String label;

  static AppRole parse(String? v) =>
      AppRole.values.firstWhere((r) => r.db == v, orElse: () => AppRole.client);

  bool get isStaff => this != AppRole.client;
  bool get isAdmin => this == AppRole.admin || this == AppRole.superAdmin;
}

enum Section { dashboard, leads, projects, services, team, testimonials, blog, users, settings }

/// Which roles may open which section (same rules as the RLS policies).
const Map<Section, Set<AppRole>> sectionAccess = {
  Section.dashboard: {AppRole.superAdmin, AppRole.admin, AppRole.projectManager, AppRole.editor, AppRole.support},
  Section.leads: {AppRole.superAdmin, AppRole.admin, AppRole.projectManager, AppRole.support},
  Section.projects: {AppRole.superAdmin, AppRole.admin, AppRole.projectManager, AppRole.editor},
  Section.services: {AppRole.superAdmin, AppRole.admin, AppRole.editor},
  Section.team: {AppRole.superAdmin, AppRole.admin, AppRole.editor},
  Section.testimonials: {AppRole.superAdmin, AppRole.admin, AppRole.editor},
  Section.blog: {AppRole.superAdmin, AppRole.admin, AppRole.editor},
  Section.users: {AppRole.superAdmin, AppRole.admin},
  Section.settings: {AppRole.superAdmin, AppRole.admin},
};

bool canOpen(AppRole role, Section s) => sectionAccess[s]!.contains(role);
