//
class Customer {
  final int id;
  final String name;
  final String phoneNumber;
  final String? address;
  final String? imageUrl;
  // KYC
  final String? idProofType;
  final String? idProofNumber;
  final String? nomineeName;
  final String? nomineeRelation;
  // --- NEW STATS ---
  final int activeLoanCount;
  final int overdueLoanCount;
  final int paidLoanCount;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.address,
    this.imageUrl,
    this.idProofType,
    this.idProofNumber,
    this.nomineeName,
    this.nomineeRelation,
    // --- NEW ---
    this.activeLoanCount = 0,
    this.overdueLoanCount = 0,
    this.paidLoanCount = 0,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phone_number'],
      address: json['address'],
      imageUrl: json['customer_image_url'],
      idProofType: json['id_proof_type'],
      idProofNumber: json['id_proof_number'],
      nomineeName: json['nominee_name'],
      nomineeRelation: json['nominee_relation'],
      // --- MAP NEW FIELDS ---
      activeLoanCount: json['active_loan_count'] ?? 0,
      overdueLoanCount: json['overdue_loan_count'] ?? 0,
      paidLoanCount: json['paid_loan_count'] ?? 0,
    );
  }
}