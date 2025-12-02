class User {
  final int id;
  final String username;
  final String role; // 'admin', 'manager', 'staff'
  final int? branchId; // New field

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
      // Handle case where branchId might be null or missing
      branchId: json['branchId'],
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

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
}