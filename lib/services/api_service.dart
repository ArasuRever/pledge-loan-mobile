// lib/services/api_service.dart
import 'package:flutter/material.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // For File
import 'package:http_parser/http_parser.dart'; // For MediaType
// Import all of your models
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';

class ApiService {
  final String _baseUrl = 'https://pledge-loan-api-as.onrender.com/api';

  // Helper function to get the saved token
  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('jwt_token');
  }

  // Helper to create authenticated headers
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
      List<Customer> customers =
      body.map((dynamic item) => Customer.fromJson(item)).toList();
      return customers;
    } else {
      throw Exception('Failed to load customers: ${response.body}');
    }
  }

  // --- 2. ADD THIS NEW FUNCTION ---
  Future<Customer> getCustomerDetails(int customerId) async {
    final headers = await _getAuthHeaders();

    final response = await http.get(
      Uri.parse('$_baseUrl/customers/$customerId'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      return Customer.fromJson(jsonDecode(response.body));
    } else {
      debugPrint('Failed to load customer details. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to load customer details: ${response.body}');
    }
  }

  // --- 3. ADD THIS NEW FUNCTION (Fixes the first error) ---
  Future<List<CustomerLoan>> getCustomerLoans(int customerId) async {
    final headers = await _getAuthHeaders();

    final response = await http.get(
      Uri.parse('$_baseUrl/customers/$customerId/loans'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      List<CustomerLoan> loans =
      body.map((dynamic item) => CustomerLoan.fromJson(item)).toList();
      return loans;
    } else {
      debugPrint('Failed to load customer loans. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to load customer loans: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> addCustomer({
    required String name,
    required String phoneNumber,
    required String address,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/customers'),
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      debugPrint('Failed to add customer. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to add customer: ${response.body}');
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
      List<Loan> loans =
      body.map((dynamic item) => Loan.fromJson(item)).toList();
      return loans;
    } else {
      debugPrint('Failed to load loans. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
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
      debugPrint('Failed to load loan details. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to load loan details. Status code: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> createLoan({
    required Map<String, String> loanData,
    File? imageFile, // Add imageFile parameter
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Must use MultipartRequest because the backend uses multer
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/loans'), // /api/loans
    );

    request.headers['Authorization'] = 'Bearer $token';

    // Add all the text fields
    request.fields.addAll(loanData);

    // --- ADD THE IMAGE FILE (if it exists) ---
    if (imageFile != null) {
      request.files.add(
        await http.MultipartFile.fromPath(
          'itemPhoto', // This MUST match your backend's upload.single('itemPhoto')
          imageFile.path,
          contentType: MediaType('image', 'jpeg'), // Or 'png'
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

  Future<Map<String, dynamic>> updateLoan({
    required int loanId,
    required Map<String, String> loanData,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/loans/$loanId'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      debugPrint('Failed to update loan. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      String errorMessage = 'Failed to update loan.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) {
          errorMessage = errorBody['error'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
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
      debugPrint('Failed to add payment. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to add payment: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> settleLoan({
    required int loanId,
    String? discountAmount,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/settle'),
      headers: headers,
      body: jsonEncode({
        'discountAmount': discountAmount ?? '0',
      }),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      debugPrint('Failed to settle loan. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      String errorMessage = 'Failed to settle loan.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) {
          errorMessage = errorBody['error'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
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
      debugPrint('Failed to add principal. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      String errorMessage = 'Failed to add principal.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) {
          errorMessage = errorBody['error'];
        }
      } catch (_) {}
      throw Exception(errorMessage);
    }
  }
}