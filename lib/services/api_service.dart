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
    if (token == null) throw Exception('Not authenticated');
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  String _buildQuery({int? branchId, String? extra}) {
    List<String> params = [];
    if (branchId != null) params.add('branchId=$branchId');
    if (extra != null && extra.isNotEmpty) params.add(extra);
    if (params.isEmpty) return '';
    return '?${params.join('&')}';
  }

  // --- AUTH ---
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
    await prefs.remove('current_branch_view');
    await prefs.remove('current_branch_name');
  }

  // --- DASHBOARD ---
  Future<Map<String, dynamic>> getDashboardStats({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(Uri.parse('$_baseUrl/dashboard/stats$query'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load stats');
  }

  Future<List<dynamic>> search(String query) async {
    if (query.length < 2) return [];
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/search?q=$query'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // --- RECENT ACTIVITY ---
  Future<List<dynamic>> getRecentCreatedLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(Uri.parse('$_baseUrl/loans/recent/created$query'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  Future<List<dynamic>> getRecentClosedLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(Uri.parse('$_baseUrl/loans/recent/closed$query'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    return [];
  }

  // --- BRANCH MANAGEMENT ---
  Future<List<Branch>> getBranches() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/branches'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Branch.fromJson(item)).toList();
    }
    throw Exception('Failed to load branches');
  }

  Future<void> createBranch(Map<String, dynamic> branchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/branches'), headers: headers, body: jsonEncode(branchData));
    if (response.statusCode != 201) throw Exception('Failed to create branch');
  }

  Future<void> updateBranch(int id, Map<String, dynamic> branchData) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(Uri.parse('$_baseUrl/branches/$id'), headers: headers, body: jsonEncode(branchData));
    if (response.statusCode != 200) throw Exception('Failed to update branch');
  }

  Future<void> deleteBranch(int id) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/branches/$id'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete branch');
  }

  // --- CUSTOMERS ---
  Future<List<Customer>> getCustomers({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(Uri.parse('$_baseUrl/customers$query'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((dynamic item) => Customer.fromJson(item)).toList();
    }
    throw Exception('Failed to load customers');
  }

  Future<Customer> getCustomerDetails(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/customers/$customerId'), headers: headers);
    if (response.statusCode == 200) return Customer.fromJson(jsonDecode(response.body));
    throw Exception('Failed to load customer details');
  }

  Future<List<CustomerLoan>> getCustomerLoans(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/customers/$customerId/loans'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => CustomerLoan.fromJson(item)).toList();
    }
    throw Exception('Failed to load customer loans');
  }

  Future<Map<String, dynamic>> addCustomer({required String name, required String phoneNumber, required String address, String? idProofType, String? idProofNumber, String? nomineeName, String? nomineeRelation, File? photoFile}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/customers'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;
    if (idProofType != null) request.fields['id_proof_type'] = idProofType;
    if (idProofNumber != null) request.fields['id_proof_number'] = idProofNumber;
    if (nomineeName != null) request.fields['nominee_name'] = nomineeName;
    if (nomineeRelation != null) request.fields['nominee_relation'] = nomineeRelation;
    if (photoFile != null) request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path, contentType: MediaType('image', 'jpeg')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to add customer');
  }

  Future<Map<String, dynamic>> updateCustomer({required int id, required String name, required String phoneNumber, required String address, String? idProofType, String? idProofNumber, String? nomineeName, String? nomineeRelation, File? photoFile}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/customers/$id'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['name'] = name;
    request.fields['phone_number'] = phoneNumber;
    request.fields['address'] = address;
    if (idProofType != null) request.fields['id_proof_type'] = idProofType;
    if (idProofNumber != null) request.fields['id_proof_number'] = idProofNumber;
    if (nomineeName != null) request.fields['nominee_name'] = nomineeName;
    if (nomineeRelation != null) request.fields['nominee_relation'] = nomineeRelation;
    if (photoFile != null) request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path, contentType: MediaType('image', 'jpeg')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update customer');
  }

  // --- LOANS ---
  Future<List<Loan>> getLoans({int? branchId}) async {
    final headers = await _getAuthHeaders();
    final query = _buildQuery(branchId: branchId);
    final response = await http.get(Uri.parse('$_baseUrl/loans$query'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => Loan.fromJson(item)).toList();
    }
    throw Exception('Failed to load loans');
  }

  Future<LoanDetail> getLoanDetails(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/loans/$loanId'), headers: headers);
    if (response.statusCode == 200) return LoanDetail.fromJson(jsonDecode(response.body));
    throw Exception('Failed to load loan details');
  }

  Future<List<LoanHistoryItem>> getLoanHistory(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/loans/$loanId/history'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => LoanHistoryItem.fromJson(item)).toList();
    }
    throw Exception('Failed to load loan history');
  }

  Future<Map<String, dynamic>> createLoan({required Map<String, String> loanData, File? imageFile}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/loans'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    if (imageFile != null) request.files.add(await http.MultipartFile.fromPath('itemPhoto', imageFile.path, contentType: MediaType('image', 'jpeg')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to create loan');
  }

  Future<Map<String, dynamic>> updateLoan({required int loanId, required Map<String, String> loanData, File? imageFile}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/loans/$loanId'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields.addAll(loanData);
    if (imageFile != null) request.files.add(await http.MultipartFile.fromPath('itemPhoto', imageFile.path, contentType: MediaType('image', 'jpeg')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update loan');
  }

  // --- ACTIONS (RENEW, FORFEIT, SETTLE) ---

  // 1. RENEW LOAN (UPDATED: New Parameters)
  Future<Map<String, dynamic>> renewLoan({
    required int oldLoanId,
    required String interestPaid,
    required String principalPaid,
    required String principalAdded,
    required String newPrincipal,
    required String newBookLoanNumber,
    required String newInterestRate,
    required bool deductFirstMonthInterest,
  }) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/loans/$oldLoanId/renew'),
      headers: headers,
      body: jsonEncode({
        'interestPaid': interestPaid,
        'principalPaid': principalPaid,
        'principalAdded': principalAdded,
        'newPrincipal': newPrincipal,
        'newBookLoanNumber': newBookLoanNumber,
        'newInterestRate': newInterestRate,
        'deductFirstMonthInterest': deductFirstMonthInterest,
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    String msg = 'Failed to renew loan';
    try { msg = jsonDecode(response.body)['error'] ?? msg; } catch (_) {}
    throw Exception(msg);
  }

  // 2. FORFEIT LOAN (NEW: Multipart)
  Future<void> forfeitLoan({required int loanId, required String salePrice, String? notes, File? signatureFile, File? photoFile}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('POST', Uri.parse('$_baseUrl/loans/$loanId/forfeit'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['salePrice'] = salePrice;
    if (notes != null) request.fields['notes'] = notes;
    if (signatureFile != null) request.files.add(await http.MultipartFile.fromPath('signature', signatureFile.path, contentType: MediaType('image', 'png')));
    if (photoFile != null) request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path, contentType: MediaType('image', 'jpeg')));

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      String msg = 'Failed to forfeit loan';
      try { msg = jsonDecode(response.body)['error'] ?? msg; } catch (_) {}
      throw Exception(msg);
    }
  }

  // 3. UNDO FORFEIT (NEW)
  Future<void> undoForfeit(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/loans/$loanId/undo-forfeit'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to undo forfeiture');
  }

  // 4. SETTLE LOAN (Restored)
  Future<Map<String, dynamic>> settleLoan({required int loanId, String? discountAmount, String? settlementAmount}) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/loans/$loanId/settle'), headers: headers, body: jsonEncode({'discountAmount': discountAmount ?? '0', 'settlementAmount': settlementAmount ?? '0'}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to settle loan');
  }

  // --- TRANSACTIONS ---
  Future<List<dynamic>> addPayment({required int loanId, required String amount, required String paymentType, String? customDate}) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(
      Uri.parse('$_baseUrl/transactions'),
      headers: headers,
      body: jsonEncode({'loan_id': loanId, 'amount_paid': amount, 'payment_type': paymentType, if (customDate != null) 'custom_date': customDate}),
    );
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed to add payment');
  }

  Future<Map<String, dynamic>> addPrincipal({required int loanId, required String amount}) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/loans/$loanId/add-principal'), headers: headers, body: jsonEncode({'additionalAmount': amount}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to add principal');
  }

  // DELETE TRANSACTION (NEW)
  Future<void> deleteTransaction(int transactionId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/transactions/$transactionId'), headers: headers);
    if (response.statusCode != 200) throw Exception('Failed to delete transaction');
  }

  Future<List<Transaction>> getLoanTransactions(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/loans/$loanId'), headers: headers);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List tList = data['transactions'] ?? [];
      return tList.map((e) => Transaction.fromJson(e)).toList();
    }
    throw Exception('Failed to load transactions');
  }

  // --- SETTINGS, STAFF, RECYCLE BIN (Preserved) ---
  Future<BusinessSettings> getBusinessSettings({int? branchId}) async {
    final globalRes = await http.get(Uri.parse('$_baseUrl/settings'));
    if (globalRes.statusCode != 200) throw Exception('Failed');
    Map<String, dynamic> settingsMap = jsonDecode(globalRes.body);
    int? targetBranchId = branchId;
    if (targetBranchId == null) { if (_user == null) await loadUser(); targetBranchId = _user?.branchId; }
    if (targetBranchId != null) {
      final token = await _getToken();
      if (token != null) {
        try {
          final branchRes = await http.get(Uri.parse('$_baseUrl/branches/$targetBranchId'), headers: {'Authorization': 'Bearer $token'});
          if (branchRes.statusCode == 200) {
            final bd = jsonDecode(branchRes.body);
            settingsMap['address'] = bd['address'] ?? settingsMap['address'];
            settingsMap['phone_number'] = bd['phone_number'] ?? settingsMap['phone_number'];
          }
        } catch (_) {}
      }
    }
    return BusinessSettings.fromJson(settingsMap);
  }

  Future<BusinessSettings> updateBusinessSettings({required String businessName, required String address, required String phoneNumber, required String licenseNumber, File? logoFile, String? existingLogoUrl}) async {
    final token = await _getToken();
    var request = http.MultipartRequest('PUT', Uri.parse('$_baseUrl/settings'));
    request.headers['Authorization'] = 'Bearer $token';
    request.fields['business_name'] = businessName;
    request.fields['address'] = address;
    request.fields['phone_number'] = phoneNumber;
    request.fields['license_number'] = licenseNumber;
    if (existingLogoUrl != null) request.fields['existingLogoUrl'] = existingLogoUrl;
    if (logoFile != null) request.files.add(await http.MultipartFile.fromPath('logo', logoFile.path, contentType: MediaType('image', 'jpeg')));
    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode == 200) return BusinessSettings.fromJson(jsonDecode(response.body));
    throw Exception('Failed update settings');
  }

  Future<List<User>> getStaff() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/users'), headers: headers);
    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      return body.map((item) => User.fromJson(item)).toList();
    }
    throw Exception('Failed load staff');
  }

  Future<Map<String, dynamic>> createStaff({required String username, required String password, String role = 'staff', int? branchId}) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/users/create'), headers: headers, body: jsonEncode({'username': username, 'password': password, 'role': role, 'branchId': branchId}));
    if (response.statusCode == 201) return jsonDecode(response.body);
    throw Exception('Failed create staff');
  }

  Future<Map<String, dynamic>> changeStaffPassword({required int userId, required String newPassword}) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(Uri.parse('$_baseUrl/users/change-password'), headers: headers, body: jsonEncode({'userId': userId, 'newPassword': newPassword}));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed change password');
  }

  Future<Map<String, dynamic>> deleteStaff(int userId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/users/$userId'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed delete user');
  }

  Future<RecycleBinData> getRecycleBinData() async {
    final headers = await _getAuthHeaders();
    final response = await http.get(Uri.parse('$_baseUrl/recycle-bin/deleted'), headers: headers);
    if (response.statusCode == 200) return RecycleBinData.fromJson(jsonDecode(response.body));
    throw Exception('Failed load bin');
  }

  Future<Map<String, dynamic>> softDeleteCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/customers/$customerId'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed delete customer');
  }

  Future<Map<String, dynamic>> softDeleteLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/loans/$loanId'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed delete loan');
  }

  Future<Map<String, dynamic>> restoreCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/customers/$customerId/restore'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed restore');
  }

  Future<Map<String, dynamic>> restoreLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.post(Uri.parse('$_baseUrl/loans/$loanId/restore'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed restore');
  }

  Future<Map<String, dynamic>> permanentDeleteCustomer(int customerId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/customers/$customerId/permanent-delete'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed perm delete');
  }

  Future<Map<String, dynamic>> permanentDeleteLoan(int loanId) async {
    final headers = await _getAuthHeaders();
    final response = await http.delete(Uri.parse('$_baseUrl/loans/$loanId/permanent-delete'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed perm delete');
  }

  Future<FinancialReport> getFinancialReport(String startDate, String endDate, {int? branchId}) async {
    final headers = await _getAuthHeaders();
    String query = 'startDate=$startDate&endDate=$endDate${branchId!=null?'&branchId=$branchId':''}';
    final response = await http.get(Uri.parse('$_baseUrl/reports/financial-summary?$query'), headers: headers);
    if (response.statusCode == 200) return FinancialReport.fromJson(jsonDecode(response.body));
    throw Exception('Failed load report');
  }

  Future<Map<String, dynamic>> getDayBook(String date, {int? branchId}) async {
    final headers = await _getAuthHeaders();
    String query = 'date=$date${branchId!=null?'&branchId=$branchId':''}';
    final response = await http.get(Uri.parse('$_baseUrl/reports/day-book?$query'), headers: headers);
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed load daybook');
  }

  Future<void> updateStaff(int userId, Map<String, dynamic> updates) async {
    final headers = await _getAuthHeaders();
    final response = await http.put(Uri.parse('$_baseUrl/users/$userId'), headers: headers, body: jsonEncode(updates));
    if (response.statusCode != 200) throw Exception('Failed update staff');
  }
}