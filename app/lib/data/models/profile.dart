import '../../core/roles.dart';
import 'parse.dart';

/// Where a person stands with the platform.
enum Access {
  active, // can use the app
  pending, // signed in but nobody has approved them yet
  suspended, // was approved once, switched off by an admin
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.approvedAt,
  });

  final String id, fullName;
  final String? email, phone;
  final AppRole role;
  final bool isActive;
  final DateTime? approvedAt;

  Access get access => isActive ? Access.active : (approvedAt == null ? Access.pending : Access.suspended);
  String get displayName => fullName.trim().isNotEmpty ? fullName.trim() : (email ?? 'Unnamed');

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: str(m['id']),
        fullName: str(m['full_name']),
        email: strOrNull(m['email']),
        phone: strOrNull(m['phone']),
        role: AppRole.parse(strOrNull(m['role'])),
        isActive: boolOf(m['is_active']),
        approvedAt: dateOrNull(m['approved_at']),
      );
}
