import 'package:flutter/material.dart'; // For debugPrint
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert'; // For jsonDecode
import 'package:pledge_loan_mobile/models/customer_model.dart';
import 'package:pledge_loan_mobile/models/loan_model.dart';

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
}