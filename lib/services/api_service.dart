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
import 'package:pledge_loan_mobile/models/branch_model.dart';

class ApiService {
  // Ensure this URL matches your live server
  final String _baseUrl = 'https://pledge-loan-api-as.onrender.com/api';

  String? _token;
  User? _user;

  User? get user => _user;
  String? get token => _token;

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    return _token;
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token');
    final userStr = prefs.getString('user_data');
    if (userStr != null) {
      _user = User.fromJson(jsonDecode(userStr));
    }
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

  // --- HELPER: Build Query String ---
  String _buildQuery({int? branchId, String? extra}) {
    List<String> params = [];
    if (branchId != null) params.add('branchId=$branchId');
    if (extra != null && extra.isNotEmpty) params.add(extra);

    if (params.isEmpty) return '';
    return '?${params.join('&')}';
  }

  Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _token = data['token'];
        _user = User.fromJson(data['user']);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', _token!);
        await prefs.setString('user_data', jsonEncode(_user!.toJson()));
        await prefs.setString('role', _user!.role);
        return true;
      }
      return false;
    } catch (e) {
      print('Login Error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_data');
    await prefs.remove('role');
    await prefs.remove('current_branch_view'); // Clear view selection on logout
    await prefs.remove('current_branch_name');
  }

  // --- DASHBOARD ---
  Future<Map<String, dynamic>> getDashboardStats({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(
      Uri.parse('$_baseUrl/dashboard/stats$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load dashboard stats: ${response.body}');
    }
  }

  Future<List<dynamic>> search(String query) async {
    if (query.length < 2) return [];
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/search?q=$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  // --- RECENT ACTIVITY ---
  Future<List<dynamic>> getRecentCreatedLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(
      Uri.parse('$_baseUrl/loans/recent/created$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  Future<List<dynamic>> getRecentClosedLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(
      Uri.parse('$_baseUrl/loans/recent/closed$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      return [];
    }
  }

  // --- BRANCH MANAGEMENT ---
  Future<List<Branch>> getBranches() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/branches'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Branch.fromJson(item)).toList();
    } else {
      throw Exception('Failed to load branches');
    }
  }

  Future<void> createBranch(Map<String, dynamic> branchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/branches'),
      headers: headers,
      body: jsonEncode(branchData),
    );
    if (response.statusCode != 201) {
      throw Exception('Failed to create branch: ${response.body}');
    }
  }

  Future<void> updateBranch(int id, Map<String, dynamic> branchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/branches/$id'),
      headers: headers,
      body: jsonEncode(branchData),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update branch: ${response.body}');
    }
  }

  Future<void> deleteBranch(int id) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/branches/$id'), headers: headers);
    if (response.statusCode != 200) {
      throw Exception('Failed to delete branch');
    }
  }

  // --- CUSTOMERS (UPDATED) ---
  Future<List<Customer>> getCustomers({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(
      Uri.parse('$_baseUrl/customers$query'),
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

    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;

    if (idProofType != null && idProofType.isNotEmpty) request.fields['id_proof_type'] = idProofType;
    if (idProofNumber != null && idProofNumber.isNotEmpty) request.fields['id_proof_number'] = idProofNumber;
    if (nomineeName != null && nomineeName.isNotEmpty) request.fields['nominee_name'] = nomineeName;
    if (nomineeRelation != null && nomineeRelation.isNotEmpty) request.fields['nominee_relation'] = nomineeRelation;

    if (photoFile != null && await photoFile.exists()) {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
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

  // --- LOANS (UPDATED) ---
  Future<List<Loan>> getLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(
      Uri.parse('$_baseUrl/loans$query'),
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

  Future<Map<String, dynamic>> updateLoan({
    required int loanId,
    required Map<String, String> loanData,
    File? imageFile,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/loans/$loanId'));
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

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to update loan: ${response.body}');
    }
  }

  // --- TRANSACTIONS (UPDATED) ---
  Future<List<dynamic>> addPayment({
    required int loanId,
    required String amount,
    required String paymentType,
    String? customDate, // <--- 1. NEW PARAMETER for Backdating
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: headers,
      body: jsonEncode({
        'loan_id': loanId,
        'amount_paid': amount,
        'payment_type': paymentType,
        if (customDate != null) 'custom_date': customDate, // <--- 2. SEND TO BACKEND
      }),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      // Improved error handling for specific backend messages like "Date cannot be before Pledge Date"
      String msg = 'Failed to add payment';
      try {
        final err = jsonDecode(response.body);
        if (err['error'] != null) msg = err['error'];
      } catch (_) {
        msg = 'Failed to add payment: ${response.body}';
      }
      throw Exception(msg);
    }
  }

  // --- FORFEIT / SELL LOAN ---
  Future<void> forfeitLoan({
    required int loanId,
    required String salePrice,
    String? notes,
    File? signatureFile,
    File? photoFile,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/loans/$loanId/forfeit'));
    request.headers['Authorization'] = 'Bearer $token';

    request.fields['salePrice'] = salePrice;
    if (notes != null) request.fields['notes'] = notes;

    if (signatureFile != null && await signatureFile.exists()) {
      // Assuming signature is usually a PNG from signature pads, but mimetype handling can be generic
      request.files.add(await http.MultipartFile.fromPath(
        'signature',
        signatureFile.path,
        contentType: MediaType('image', 'png'),
      ));
    }

    if (photoFile != null && await photoFile.exists()) {
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        photoFile.path,
        contentType: MediaType('image', 'jpeg'),
      ));
    }

    try {
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        String msg = 'Failed to forfeit loan';
        try {
          final body = jsonDecode(response.body);
          msg = body['error'] ?? msg;
        } catch (_) {
          msg = response.body;
        }
        throw Exception(msg);
      }
    } catch (e) {
      throw Exception('Connection error during forfeiture: $e');
    }
  }

  // --- NEW: Get Transactions for specific Loan (Used in Edit Page) ---
  Future<List<Transaction>> getLoanTransactions(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(
      Uri.parse('$_baseUrl/loans/$loanId'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List tList = data['transactions'] ?? [];
      return tList.map((e) => Transaction.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load transactions');
    }
  }

  Future<Map<String, dynamic>> settleLoan({
    required int loanId,
    String? discountAmount,
    String? settlementAmount,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$loanId/settle'),
      headers: headers,
      body: jsonEncode({
        'discountAmount': discountAmount ?? '0',
        'settlementAmount': settlementAmount ?? '0',
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

  // --- SETTINGS (UPDATED) ---
  Future<BusinessSettings> getBusinessSettings({int? branchId}) async {
    try {
      final globalRes = await http.get(Uri.parse('$_baseUrl/settings'));
      if (globalRes.statusCode != 200) throw Exception('Failed to load global settings');

      Map<String, dynamic> settingsMap = jsonDecode(globalRes.body);

      int? targetBranchId = branchId;

      if (targetBranchId == null) {
        if (_user == null) await loadUser();
        targetBranchId = _user?.branchId;
      }

      if (targetBranchId != null) {
        try {
          final token = await _getToken();
          if (token != null) {
            final branchRes = await http.get(
              Uri.parse('$_baseUrl/branches/$targetBranchId'),
              headers: {'Authorization': 'Bearer $token'},
            );

            if (branchRes.statusCode == 200) {
              final branchData = jsonDecode(branchRes.body);
              settingsMap['address'] = branchData['address'] ?? settingsMap['address'];
              settingsMap['phone_number'] = branchData['phone_number'] ?? settingsMap['phone_number'];
              settingsMap['license_number'] = branchData['license_number'] ?? settingsMap['license_number'];
            }
          }
        } catch (e) {
          print('Branch settings fetch failed: $e');
        }
      }

      return BusinessSettings.fromJson(settingsMap);
    } catch (e) {
      throw Exception('Failed to load settings: $e');
    }
  }

  Future<BusinessSettings> updateBusinessSettings({
    required String businessName,
    required String address,
    required String phoneNumber,
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
        'logo',
        logoFile.path,
        contentType: MediaType('image', 'jpeg'),
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

  // --- STAFF ---
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

  Future<Map<String, dynamic>> createStaff({
    required String username,
    required String password,
    String role = 'staff',
    int? branchId,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/users/create'),
      headers: headers,
      body: jsonEncode({
        'username': username,
        'password': password,
        'role': role,
        'branchId': branchId,
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

  // --- FINANCIAL REPORT (UPDATED) ---
  Future<FinancialReport> getFinancialReport(String startDate, String endDate, {int? branchId}) async {
    final headers = await _getAuthHeaders();
    // Build query carefully
    String query = 'startDate=$startDate&endDate=$endDate';
    if (branchId != null) {
      query += '&branchId=$branchId';
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/financial-summary?$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return FinancialReport.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to load financial report: ${response.body}');
    }
  }

  // --- DAYBOOK (UPDATED) ---
  Future<Map<String, dynamic>> getDayBook(String date, {int? branchId}) async {
    final headers = await _getAuthHeaders();
    String query = 'date=$date';
    if (branchId != null) {
      query += '&branchId=$branchId';
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/reports/day-book?$query'),
      headers: headers,
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load Day Book: ${response.body}');
    }
  }

  Future<void> updateStaff(int userId, Map<String, dynamic> updates) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(
      Uri.parse('$_baseUrl/users/$userId'),
      headers: headers,
      body: jsonEncode(updates),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update user: ${response.body}');
    }
  }
}