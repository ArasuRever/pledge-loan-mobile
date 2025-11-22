// lib/services/api_service.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';

import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';
import 'package:pledge_loan_mobile/models/user_model.dart';
import 'package:pledge_loan_mobile/models/recycle_bin_model.dart';
import 'package:pledge_loan_mobile/models/loan_history_model.dart';
import 'package:pledge_loan_mobile/models/financial_report_model.dart';
import 'package:pledge_loan_mobile/models/business_settings_model.dart';

class ApiService {
  // Ensure this URL matches your live server
  final String _baseUrl = 'https://pledge-loan-api-as.onrender.com/api';

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  Future<Map<String, String>> _getAuthHeaders() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('role');
  }

  // --- Dashboard ---
  Future<Map<String, dynamic>> getDashboardStats() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/stats'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats: ${response.body}');
    }
  }

  // --- Customers ---
  Future<List<Customer>> getCustomers() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/customers'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Customer.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load customers: ${response.body}');
    }
  }

  Future<Customer> getCustomerDetails(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/customers/$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return Customer.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load customer details: ${response.body}');
    }
  }

  Future<List<CustomerLoan>> getCustomerLoans(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/customers/$customerId/loans'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => CustomerLoan.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load customer loans: ${response.body}');
    }
  }

  // --- CUSTOMER CREATION (Hardened) ---
  Future<Map<String, dynamic>> addCustomer({
    required String name,
    required String phoneNumber,
    required String address,
    String? idProofType,
    String? idProofNumber,
    String? nomineeName,
    String? nomineeRelation,
    File? photoFile,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/customers'));
    request.headers['Authorization'] = 'Bearer $token';

    // Core Fields - Ensure they are Strings
    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;

    // Optional Fields - Only add if NOT null and NOT empty
    if (idProofType != null && idProofType.isNotEmpty) request.fields['id_proof_type'] = idProofType;
    if (idProofNumber != null && idProofNumber.isNotEmpty) request.fields['id_proof_number'] = idProofNumber;
    if (nomineeName != null && nomineeName.isNotEmpty) request.fields['nominee_name'] = nomineeName;
    if (nomineeRelation != null && nomineeRelation.isNotEmpty) request.fields['nominee_relation'] = nomineeRelation;

    // Photo Upload
    if (photoFile != null && await photoFile.exists()) {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
        // Let http package auto-detect content type to be safe
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        // Parse backend error message
        String msg = 'Failed to add customer';
        try {
          final err = jsonDecode(response.body);
          if (err['error'] != null) msg = err['error'];
        } catch (_) { msg = response.body; }
        throw Exception('$msg (Status: ${response.statusCode})');
      }
    } catch (e) {
      throw Exception('Connection Error: $e');
    }
  }

  // --- NEW: Update Customer (For Edit Profile) ---
  Future<Map<String, dynamic>> updateCustomer({
    required int id,
    required String name,
    required String phoneNumber,
    required String address,
    String? idProofType,
    String? idProofNumber,
    String? nomineeName,
    String? nomineeRelation,
    File? photoFile,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/customers/$id'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;
    if (idProofType != null) request.fields['id_proof_type'] = idProofType;
    if (idProofNumber != null) request.fields['id_proof_number'] = idProofNumber;
    if (nomineeName != null) request.fields['nominee_name'] = nomineeName;
    if (nomineeRelation != null) request.fields['nominee_relation'] = nomineeRelation;

    if (photoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path, contentType: MediaType('image', 'jpeg')));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update customer: ${response.body}');
    }
  }

  // --- Loans ---
  Future<List<Loan>> getLoans() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/loans'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Loan.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load loans. Status code: ${response.statusCode}');
    }
  }

  Future<LoanDetail> getLoanDetails(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/loans/$loanId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return LoanDetail.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load loan details. Status code: ${response.statusCode}');
    }
  }

  Future<List<LoanHistoryItem>> getLoanHistory(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/loans/$loanId/history'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => LoanHistoryItem.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load loan history: ${response.body}');
    }
  }

  // Note: loanData Map should now include 'gross_weight', 'net_weight', 'purity', 'appraised_value'
  Future<Map<String, dynamic>> createLoan({required Map<String, String> loanData, File? imageFile}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/loans'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'itemPhoto',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create loan: ${response.body}');
    }
  }

  //
  // Updated to support Image Upload on Edit
  Future<Map<String, dynamic>> updateLoan({
    required int loanId,
    required Map<String, String> loanData,
    File? imageFile, // <--- Added parameter
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/loans/$loanId'));
    request.headers['Authorization'] = 'Bearer $token';

    // Add text fields
    request.fields.addAll(loanData);

    // Add file if provided
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'itemPhoto', // Must match backend field name
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update loan: ${response.body}');
    }
  }

  // --- Transactions / Actions ---
  Future<List<dynamic>> addPayment({
    required int loanId,
    required String amount,
    required String paymentType,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: headers,
      body: jsonEncode({
        'loan_id': loanId,
        'amount_paid': amount,
        'payment_type': paymentType,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to add payment: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> settleLoan({
    required int loanId,
    String? discountAmount,
    String? settlementAmount, // <--- Added Parameter
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/settle'),
      headers: headers,
      body: jsonEncode({
        'discountAmount': discountAmount ?? '0',
        'settlementAmount': settlementAmount ?? '0', // <--- Pass to Backend
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to settle loan.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) errorMessage = errorBody['error'];
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // - Add this method
  Future<Map<String, dynamic>> renewLoan({
    required int oldLoanId,
    required String interestPaid,
    required String newBookLoanNumber,
    required String newInterestRate,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$oldLoanId/renew'),
      headers: headers,
      body: jsonEncode({
        'interestPaid': interestPaid,
        'newBookLoanNumber': newBookLoanNumber,
        'newInterestRate': newInterestRate,
      }),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      // Handle specific backend errors (like "New Book Loan Number already exists")
      String msg = 'Failed to renew loan.';
      try {
        final body = jsonDecode(response.body);
        msg = body['error'] ?? msg;
      } catch (_) {}
      throw Exception(msg);
    }
  }

  Future<Map<String, dynamic>> addPrincipal({
    required int loanId,
    required String amount,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/add-principal'),
      headers: headers,
      body: jsonEncode({
        'additionalAmount': amount,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      String errorMessage = 'Failed to add principal.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) errorMessage = errorBody['error'];
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }

  // --- Staff Functions ---
  Future<List<User>> getStaff() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/users'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => User.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load staff list: ${response.body}');
    }
  }

  // Updated to support generic 'create' with roles
  Future<Map<String, dynamic>> createStaff({
    required String username,
    required String password,
    String role = 'staff',
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/users/create'), // Changed from /staff to /create
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': role,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create user: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> changeStaffPassword({
    required int userId,
    required String newPassword,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/users/change-password'),
      headers: headers,
      body: jsonEncode({
        'userId': userId,
        'newPassword': newPassword,
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to change password: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> deleteStaff(int userId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to delete user: ${response.body}');
    }
  }

  // --- RECYCLE BIN ---
  Future<RecycleBinData> getRecycleBinData() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/recycle-bin/deleted'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return RecycleBinData.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load recycle bin data: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> softDeleteCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/customers/$customerId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to delete customer');
    }
  }

  Future<Map<String, dynamic>> softDeleteLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/loans/$loanId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to delete loan');
    }
  }

  Future<Map<String, dynamic>> restoreCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/customers/$customerId/restore'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to restore customer');
    }
  }

  Future<Map<String, dynamic>> restoreLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/restore'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to restore loan');
    }
  }

  // --- PERMANENT DELETE ---
  Future<Map<String, dynamic>> permanentDeleteCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/customers/$customerId/permanent-delete'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to permanently delete customer.');
    }
  }

  Future<Map<String, dynamic>> permanentDeleteLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(
      Uri.parse('$_baseUrl/loans/$loanId/permanent-delete'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final errorBody = jsonDecode(response.body);
      throw Exception(errorBody['error'] ?? 'Failed to permanently delete loan.');
    }
  }

  // --- FINANCIAL REPORT ---
  Future<FinancialReport> getFinancialReport(String startDate, String endDate) async {
    final headers = await _getAuthHeaders();
    final uri = Uri.parse('$_baseUrl/reports/financial-summary').replace(queryParameters: {
      'startDate': startDate,
      'endDate': endDate,
    });
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return FinancialReport.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load financial report: ${response.body}');
    }
  }

  // --- DayBook ---
  Future<Map<String, dynamic>> getDayBook(String date) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/reports/day-book?date=$date'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load Day Book: ${response.body}');
    }
  }

  Future<BusinessSettings> getBusinessSettings() async {
    // Note: We don't use _getAuthHeaders because this might be called before login
    final response = await http.get(Uri.parse('$_baseUrl/settings'));

    if (response.statusCode == 200) {
      return BusinessSettings.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load settings');
    }
  }

  // 2. Update Settings (Admin Only)
  Future<BusinessSettings> updateBusinessSettings({
    required String businessName,
    required String address,
    required String phoneNumber, // Combined string of up to 3 numbers
    required String licenseNumber,
    File? logoFile,
    String? existingLogoUrl,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/settings'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['business_name'] = businessName;
    request.fields['address'] = address;
    request.fields['phone_number'] = phoneNumber;
    request.fields['license_number'] = licenseNumber;
    if (existingLogoUrl != null) {
      request.fields['existingLogoUrl'] = existingLogoUrl;
    }

    if (logoFile != null) {
      request.files.add(await http.MultipartFile.fromPath(
        'logo', // Matches backend field name
        logoFile.path,
        contentType: MediaType('image', 'jpeg'), // Or png, detected auto usually
      ));
    }

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return BusinessSettings.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to update settings: ${response.body}');
    }
  }
}