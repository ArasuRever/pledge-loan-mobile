class User {
  final int id;
  final String username;
  final String role; // 'admin', 'manager', 'staff'
  final int? branchId;
  final String? branchName; // <--- ADDED: To store assigned branch name

  User({
    required this.id,
    required this.username,
    required this.role,
    this.branchId,
    this.branchName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      role: json['role'],
      // Handle potential differences in backend casing
      branchId: json['branchId'] ?? json['branch_id'],
      branchName: json['branchName'] ?? json['branch_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'role': role,
      'branchId': branchId,
      'branchName': branchName,
    };
  }

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isStaff => role == 'staff';
}