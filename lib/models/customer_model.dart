// lib/models/customer_model.dart
class Customer {
  final int id;
  final String name;
  final String phoneNumber;
  final String? address;
  // --- NEW KYC FIELDS ---
  final String? idProofType;
  final String? idProofNumber;
  final String? nomineeName;
  final String? nomineeRelation;
  final String? imageUrl; // Added support for image URL if you use it

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address,
    this.idProofType,
    this.idProofNumber,
    this.nomineeName,
    this.nomineeRelation,
    this.imageUrl,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      // --- MAP NEW FIELDS ---
      idProofType: json['id_proof_type'],
      idProofNumber: json['id_proof_number'],
      nomineeName: json['nominee_name'],
      nomineeRelation: json['nominee_relation'],
      imageUrl: json['customer_image_url'],
    );
  }
}