// lib/services/api_service.dart
import 'package:flutter/material.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For jsonDecode
import 'dart:io'; // <-- 1. FIX: ADDED THIS IMPORT FOR 'File'
import 'package:http_parser/http_parser.dart'; // <-- 2. FIX: ADDED THIS IMPORT FOR 'MediaType'

// Import all of your models
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/models/customer_loan_model.dart';
import 'package:pledge_loan_mobile/models/user_model.dart';

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
      List<CustomerLoan> loans =
      body.map((dynamic item) => CustomerLoan.fromJson(item)).toList();
      return loans;
    } else {
      throw Exception('Failed to load customer loans: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> addCustomer({
    required String name,
    required String phoneNumber,
    required String address,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/customers'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
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

  Future<Map<String, dynamic>> createLoan(
      {required Map<String, String> loanData, File? imageFile}) async {
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
          contentType: MediaType('image', 'jpeg'), // <-- 'MediaType' is now found
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
    if (token == null) throw Exception('Not authenticated');
    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/loans/$loanId'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
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
      String errorMessage = 'Failed to settle loan.';
      try {
        final errorBody = jsonDecode(response.body);
        if (errorBody['error'] != null) errorMessage = errorBody['error'];
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
      List<User> users =
      body.map((dynamic item) => User.fromJson(item)).toList();
      return users;
    } else {
      throw Exception('Failed to load staff list: ${response.body}');
    }
  }

  Future<Map<String, dynamic>> createStaff({
    required String username,
    required String password,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/users/staff'),
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create staff: ${response.body}');
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
      throw Exception('Failed to delete staff: ${response.body}');
    }
  }
}