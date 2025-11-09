// lib/main.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decode/jwt_decode.dart';
import 'package:pledge_loan_mobile/main_scaffold.dart'; // Import our new MainScaffold

void main() {
  runApp(const PledgeLoanApp());
}

class PledgeLoanApp extends StatefulWidget {
  const PledgeLoanApp({super.key});

  @override
  _PledgeLoanAppState createState() => _PledgeLoanAppState();
}

class _PledgeLoanAppState extends State<PledgeLoanApp> {
  // This key is used to force a refresh of the app state
  Key _appKey = UniqueKey();

  Future<String?> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token');

    if (token != null) {
      // Check if token is expired
      try {
        if (Jwt.isExpired(token)) {
          await prefs.remove('jwt_token');
          return null; // Token is expired, treat as logged out
        }
        return token; // Token is valid
      } catch (e) {
        await prefs.remove('jwt_token');
        return null; // Token is invalid, treat as logged out
      }
    }
    return null; // No token found
  }

  void _onStateChange() {
    // This function is called by LoginPage or MainScaffold to trigger a rebuild
    setState(() {
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: _appKey,
      title: 'Sri Kubera Bankers',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          primary: const Color(0xFF4A6572),
          secondary: const Color(0xFF344955),
          surface: Colors.white,
        ),
        textTheme: const TextTheme(
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF232F30),
          ),
        ),
      ),
      home: FutureBuilder<String?>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          // While checking, show a loading screen
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // If token exists (snapshot has data), show the main app
          if (snapshot.hasData && snapshot.data != null) {
            return MainScaffold(onLogout: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              _onStateChange();
            });
          }

          // Otherwise, show the LoginPage
          return LoginPage(onLoginSuccess: _onStateChange);
        },
      ),
    );
  }
}


// --- LOGIN PAGE (Stays in main.dart for simplicity) ---
class LoginPage extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginPage({super.key, required this.onLoginSuccess});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isAdmin = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _message = '';
  bool _isLoading = false;

  final String apiUrl = 'https://pledge-loan-api-as.onrender.com/api/auth/login';

  Future<void> _login() async {
    setState(() { _isLoading = true; _message = ''; });

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 200) {
        final String token = responseData['token'];

        try {
          Map<String, dynamic> payload = Jwt.parseJwt(token);
          String actualRole = payload['role'];
          String expectedRole = _isAdmin ? 'admin' : 'staff';

          if (actualRole == expectedRole) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setString('jwt_token', token);

            // Call the success callback to rebuild the app
            widget.onLoginSuccess();

          } else {
            setState(() {
              _message = 'Login Failed: You do not have "$expectedRole" privileges.';
            });
          }
        } catch (e) {
          setState(() {
            _message = 'Login Failed: Invalid token received from server.';
          });
        }
      } else {
        setState(() {
          _message = 'Login Failed: ${responseData['message'] ?? responseData['error'] ?? 'Invalid credentials.'}';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: Could not connect to the server.';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // 1. Your Logo
              Image.asset(
                'assets/images/sri_kubera_logo.png',
                height: 150,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32.0),

              Text(
                'Sri KuberaLakshmi Bankers',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8.0),
              Text(
                'Login to access your account',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32.0),

              // 2. The Admin/Staff Toggle
              _buildLoginToggle(),
              const SizedBox(height: 24.0),

              // 3. Username Field
              Text(
                'Username',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _usernameController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Enter your username',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // 4. Password Field
              Text(
                'Password',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16.0),

              // 5. Remember Me / Forgot Password Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (value) {
                          setState(() {
                            _rememberMe = value ?? false;
                          });
                        },
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: Implement Forgot Password
                    },
                    child: const Text('Forgot password?'),
                  ),
                ],
              ),
              const SizedBox(height: 24.0),

              // 6. Login Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAdmin ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : const Text('Log In', style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 16.0),

              // 7. Error Message Display
              if (_message.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    _message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _message.contains('Success') ? Colors.green[700] : Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // --- This is the custom toggle widget ---
  Widget _buildLoginToggle() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(25),
      ),
      child: Stack(
        children: [
          // Animated background
          AnimatedAlign(
            alignment: _isAdmin ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              width: MediaQuery.of(context).size.width / 2 - 24, // Half width minus padding
              height: 50,
              decoration: BoxDecoration(
                color: _isAdmin ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Row with the text buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdmin = true;
                    });
                  },
                  child: Container(
                    color: Colors.transparent, // Makes the full area tappable
                    alignment: Alignment.center,
                    child: Text(
                      'Admin',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _isAdmin ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _isAdmin = false;
                    });
                  },
                  child: Container(
                    color: Colors.transparent, // Makes the full area tappable
                    alignment: Alignment.center,
                    child: Text(
                      'Staff',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_isAdmin ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}