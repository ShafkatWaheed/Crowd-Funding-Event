enum UserRole { admin, organizer, customer, sponsor }

class AppUser {
  final int id;
  final String email;
  final String? displayName;
  final String? phone;
  final UserRole role;
  final String? address;
  final String? birthday;
  final int? yearsOfExperience;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.phone,
    required this.role,
    this.address,
    this.birthday,
    this.yearsOfExperience,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'],
      email: json['email'] ?? '',
      displayName: json['display_name'],
      phone: json['phone'],
      role: UserRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => UserRole.customer,
      ),
      address: json['address'],
      birthday: json['birthday'],
      yearsOfExperience: json['years_of_experience'],
    );
  }

  /// Preferred display: name if available, otherwise generic fallback.
  String get displayLabel => displayName ?? 'User';

  /// First initial for avatar.
  String get initial => displayLabel.substring(0, 1).toUpperCase();

  /// Mask email: show first 2 chars + *** + @domain
  String get maskedEmail {
    if (email.isEmpty) return '?';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    final visible = local.length >= 2 ? local.substring(0, 2) : local;
    return '$visible***@$domain';
  }

  bool get isAdmin => role == UserRole.admin;
  bool get isOrganizer => role == UserRole.organizer;
  bool get isCustomer => role == UserRole.customer;
  bool get isSponsor => role == UserRole.sponsor;
}
