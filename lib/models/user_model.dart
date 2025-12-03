class User {
  final int id;
  final String username;
  final String role; // 'admin', 'manager', 'staff'
  final int? branchId;

  User({
    required this.id,
    required this.username,
    required this.role,
    this.branchId,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      // Handles both camelCase (Login) and snake_case (DB/Staff List) formats
      branchId: json['branchId'] ?? json['branch_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'branchId': branchId,
    };
  }

  // Role checks
  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff'; // <--- Added this
}