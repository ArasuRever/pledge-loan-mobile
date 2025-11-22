// lib/models/business_settings_model.dart
class BusinessSettings {
  final String businessName;
  final String address;
  final String phoneNumber;
  final String licenseNumber;
  final String? logoUrl;
  final String navbarDisplayMode;

  BusinessSettings({
    required this.businessName,
    required this.address,
    required this.phoneNumber,
    required this.licenseNumber,
    this.logoUrl,
    this.navbarDisplayMode = 'both',
  });

  factory BusinessSettings.fromJson(Map<String, dynamic> json) {
    return BusinessSettings(
      businessName: json['business_name'] ?? 'Sri Kubera Bankers',
      address: json['address'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      licenseNumber: json['license_number'] ?? '',
      logoUrl: json['logo_url'],
      navbarDisplayMode: json['navbar_display_mode'] ?? 'both',
    );
  }
}