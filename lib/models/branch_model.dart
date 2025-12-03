class Branch {
  final int id;
  final String branchName;
  final String branchCode;
  final String? address;
  final String? phoneNumber;
  final int isActive; // 1 = Active, 0 = Inactive
  final String? licenseNumber;

  Branch({
    required this.id,
    required this.branchName,
    required this.branchCode,
    this.address,
    this.phoneNumber,
    required this.isActive,
    this.licenseNumber,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'],
      branchName: json['branch_name'],
      branchCode: json['branch_code'],
      address: json['address'],
      phoneNumber: json['phone_number'],
      isActive: json['is_active'] is bool
          ? (json['is_active'] ? 1 : 0)
          : (json['is_active'] ?? 1),
      licenseNumber: json['license_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'branch_name': branchName,
      'branch_code': branchCode,
      'address': address,
      'phone_number': phoneNumber,
      'is_active': isActive,
      'license_number': licenseNumber,
    };
  }
}