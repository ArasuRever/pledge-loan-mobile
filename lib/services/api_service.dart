import 'package:flutter/material.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For jsonDecode
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';
import 'package:pledge_loan_mobile/models/transaction_model.dart';
import 'package:pledge_loan_mobile/models/loan_detail_model.dart';

class ApiService {
  final String _baseUrl = 'https://pledge-loan-api-as.onrender.com/api';

  // Helper function to get the saved token
  // Uses 'jwt_token' to match your main.dart file
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

  // Your main.dart handles the actual login,
  // but we need this logout function.
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('role');
  }

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

  Future<Map<String, dynamic>> createLoan(Map<String, String> loanData) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$_baseUrl/loans'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to create loan: ${response.body}');
    }
  }

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
      Uri.parse('$_baseUrl/loans/$loanId'), // Calls /api/loans/:id
      headers: headers,
    );

    if (response.statusCode == 200) {
      // The LoanDetail model is designed to parse the entire response
      return LoanDetail.fromJson(jsonDecode(response.body));
    } else {
      debugPrint('Failed to load loan details. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      throw Exception('Failed to load loan details. Status code: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> addPayment({
    required int loanId,
    required String amount,
    required String paymentType,
    String? details,
  }) async {
    final headers = await _getAuthHeaders();

    // Calls /api/transactions
    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: headers,
      body: jsonEncode({
        'loan_id': loanId,
        'amount_paid': amount,
        'payment_type': paymentType,
        'details': details ?? '$paymentType payment'
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

    // Calls /api/loans/:id/settle
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/settle'),
      headers: headers,
      body: jsonEncode({
        'discountAmount': discountAmount ?? '0',
      }),
    );

    if (response.statusCode == 200) {
      // Successful settlement returns 200 OK
      return jsonDecode(response.body);
    } else {
      debugPrint('Failed to settle loan. Status: ${response.statusCode}');
      debugPrint('Response body: ${response.body}');
      // Try to parse the error message from the backend
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

    // Calls /api/loans/:id/add-principal
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/add-principal'),
      headers: headers,
      body: jsonEncode({
        'additionalAmount': amount,
      }),
    );

    if (response.statusCode == 200) {
      // Successful add principal returns 200 OK
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

  Future<Map<String, dynamic>> updateLoan({
    required int loanId,
    required Map<String, String> loanData,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    // Your backend uses multer for this route
    // so we must use a Multipart request.
    var request = http.MultipartRequest(
      'PUT',
      Uri.parse('$_baseUrl/loans/$loanId'), // Calls PUT /api/loans/:id
    );

    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    // We are not sending a photo, your backend will handle this

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
}