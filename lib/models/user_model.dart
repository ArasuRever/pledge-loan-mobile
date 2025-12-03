class User {
  final int id;
  final String username;
  final String role;
  final int? branchId; // Added branchId

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
      branchId: json['branchId'], // Map from JSON
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