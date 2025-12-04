// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:pledge_loan_mobile/main_scaffold.dart';
import 'package:pledge_loan_mobile/services/api_service.dart';
import 'package:pledge_loan_mobile/models/business_settings_model.dart';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const PledgeLoanApp());
}

class PledgeLoanApp extends StatefulWidget {
  const PledgeLoanApp({super.key});

  @override
  _PledgeLoanAppState createState() => _PledgeLoanAppState();
}

class _PledgeLoanAppState extends State<PledgeLoanApp> {
  Key _appKey = UniqueKey();

  // --- Custom Colors for "Sri Kubera" ---
  static const Color kPrimaryNavy = Color(0xFF1A237E);
  static const Color kBackground = Color(0xFFF5F7FA);

  Future<String?> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');
    if (token != null) {
      try {
        if (Jwt.isExpired(token)) {
          await _logout(prefs);
          return null;
        }
        return token;
      } catch (e) {
        await _logout(prefs);
        return null;
      }
    }
    return null;
  }

  Future<void> _logout(SharedPreferences prefs) async {
    await prefs.remove('jwt_token');
    await prefs.remove('role');
    await prefs.remove('user_data');
  }

  void _onStateChange() {
    setState(() => _appKey = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'Sri Kubera Bankers',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimaryNavy,
          primary: kPrimaryNavy,
          secondary: const Color(0xFFEF6C00),
          surface: Colors.white,
          background: kBackground,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: kPrimaryNavy),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.white,
          margin: EdgeInsets.zero,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimaryNavy, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey.shade700),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimaryNavy,
            foregroundColor: Colors.white,
            elevation: 3,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: kPrimaryNavy,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: FutureBuilder<String?>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Scaffold(body: Center(child: CircularProgressIndicator()));
          if (snapshot.hasData && snapshot.data != null) {
            return MainScaffold(onLogout: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await _logout(prefs);
              _onStateChange();
            });
          }
          return LoginPage(onLoginSuccess: _onStateChange);
        },
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String _message = '';

  BusinessSettings? _branding;
  bool _loadingBranding = true;
  final String apiUrl = 'https://pledge-loan-api-as.onrender.com/api/auth/login';

  @override
  void initState() {
    super.initState();
    _loadBranding();
  }

  Future<void> _loadBranding() async {
    try {
      final settings = await ApiService().getBusinessSettings();
      if (mounted) setState(() => _branding = settings);
    } catch (e) {
      print("Failed to load branding: $e");
    } finally {
      if (mounted) setState(() => _loadingBranding = false);
    }
  }

  ImageProvider? _getLogoProvider() {
    if (_branding?.logoUrl != null) {
      try {
        final url = _branding!.logoUrl!;
        if (url.startsWith('data:')) {
          return MemoryImage(base64Decode(url.split(',')[1]));
        }
        return NetworkImage(url);
      } catch (_) {}
    }
    return const AssetImage('assets/images/sri_kubera_logo.png');
  }

  Future<void> _login() async {
    setState(() { _isLoading = true; _message = ''; });
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'username': _usernameController.text, 'password': _passwordController.text}),
      );
      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final String token = responseData['token'];
        if (responseData['user'] == null || responseData['user']['role'] == null) {
          setState(() => _message = 'Login Failed: Missing user data.'); return;
        }

        // --- UNIFIED LOGIN LOGIC ---
        // We accept ALL valid roles returned by the backend.
        // We trust the backend to validate credentials.
        final String rawRole = responseData['user']['role'];
        final String actualRole = rawRole.toLowerCase().trim();

        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);
        await prefs.setString('role', actualRole);

        // Save user data so Home Page can find branch info
        await prefs.setString('user_data', jsonEncode(responseData['user']));

        widget.onLoginSuccess();
      } else {
        setState(() => _message = responseData['message'] ?? responseData['error'] ?? 'Invalid credentials.');
      }
    } catch (e) {
      setState(() => _message = 'Connection Error. Check internet.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 20, spreadRadius: 5)],
                  ),
                  child: _loadingBranding
                      ? const SizedBox(height: 100, width: 100, child: CircularProgressIndicator())
                      : Image(
                    image: _getLogoProvider()!,
                    height: 100,
                    width: 100,
                    fit: BoxFit.contain,
                    errorBuilder: (c,o,s) => const Icon(Icons.store, size: 80, color: Color(0xFF1A237E)),
                  ),
                ),
                const SizedBox(height: 24.0),
                Text(
                    _branding?.businessName ?? 'Sri Kubera Bankers',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall
                ),
                const SizedBox(height: 8.0),
                Text(
                    _branding != null ? 'Welcome Back' : 'Secure Loan Management',
                    style: TextStyle(color: Colors.grey[600])
                ),
                const SizedBox(height: 48.0),

                // --- TOGGLE REMOVED ---

                TextField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username', prefixIcon: Icon(Icons.person_outline)),
                ),
                const SizedBox(height: 16.0),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 24.0),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('LOGIN', style: TextStyle(fontSize: 16, letterSpacing: 1)),
                  ),
                ),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 20.0),
                    child: Text(_message, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}