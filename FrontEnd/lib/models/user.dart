enum UserRole { admin, organizer, customer }

class AppUser {
  final int id;
  final String email;
  final String? displayName;
  final UserRole role;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'] ?? '',
      displayName: json['display_name'],
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.customer,
      ),
    );
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isOrganizer => role == UserRole.organizer;
  bool get isCustomer => role == UserRole.customer;
}
