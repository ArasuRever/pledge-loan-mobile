// lib/models/customer_model.dart
class Customer {
  final int id;
  final String name;
  final String phoneNumber;
  final String? address;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
    );
  }
}