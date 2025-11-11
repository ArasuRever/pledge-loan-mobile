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
  Key _appKey = UniqueKey();

  Future<String?> _checkLoginStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('jwt_token'); // Use jwt_token to match your code

    if (token != null) {
      try {
        if (Jwt.isExpired(token)) {
          await prefs.remove('jwt_token');
          await prefs.remove('role'); // Also clear role
          return null;
        }
        return token;
      } catch (e) {
        await prefs.remove('jwt_token');
        await prefs.remove('role');
        return null;
      }
    }
    return null;
  }

  void _onStateChange() {
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return MainScaffold(onLogout: () async {
              SharedPreferences prefs = await SharedPreferences.getInstance();
              await prefs.remove('jwt_token');
              await prefs.remove('role'); // Make sure role is cleared on logout
              _onStateChange();
            });
          }

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

// --- ALL YOUR LOGIN LOGIC IS NOW INSIDE THIS CLASS ---
class _LoginPageState extends State<LoginPage> {
  bool _isAdmin = true;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _message = '';
  bool _isLoading = false;

  final String apiUrl = 'https://pledge-loan-api-as.onrender.com/api/auth/login';

  // --- THIS IS THE NEW, CORRECTLY PLACED _login FUNCTION ---
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

        // --- THE FIX ---
        // Read the role from the 'user' object your backend is sending
        if (responseData['user'] == null || responseData['user']['role'] == null) {
          setState(() {
            _message = 'Login Failed: Server response is missing user data.';
          });
          return;
        }

        final String actualRole = responseData['user']['role'];
        // --- END FIX ---

        String expectedRole = _isAdmin ? 'admin' : 'staff';

        if (actualRole == expectedRole) {
          // Success! Save both token and role
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString('jwt_token', token);
          await prefs.setString('role', actualRole); // <-- This saves the role

          // Call the success callback to rebuild the app
          widget.onLoginSuccess();

        } else {
          // Role mismatch (e.g., trying to log in as 'admin' with 'staff' credentials)
          setState(() {
            _message = 'Login Failed: You do not have "$expectedRole" privileges.';
          });
        }
      } else {
        // Handle 401, 400, etc.
        setState(() {
          _message = 'Login Failed: ${responseData['message'] ?? responseData['error'] ?? 'Invalid credentials.'}';
        });
      }
    } catch (e) {
      // Handle network errors or JSON parsing errors
      setState(() {
        _message = 'Error: Could not connect to the server or parse response.';
      });
    } finally {
      if (mounted) { // Check if the widget is still in the tree
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- YOUR ORIGINAL build METHOD, NOW IN THE CORRECT PLACE ---
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
              _buildLoginToggle(),
              const SizedBox(height: 24.0),
              Text(
                'Username',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _usernameController, // Now this variable is found
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
              Text(
                'Password',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8.0),
              TextField(
                controller: _passwordController, // Now this variable is found
                obscureText: _obscurePassword, // Now this variable is found
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe, // Now this variable is found
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
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login, // Now these variables are found
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
              if (_message.isNotEmpty) // Now this variable is found
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

  // --- YOUR ORIGINAL toggle WIDGET, NOW IN THE CORRECT PLACE ---
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
          AnimatedAlign(
            alignment: _isAdmin ? Alignment.centerLeft : Alignment.centerRight,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child: Container(
              width: MediaQuery.of(context).size.width / 2 - 24,
              height: 50,
              decoration: BoxDecoration(
                color: _isAdmin ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    // Fix for deprecated 'withOpacity'
                    color: Colors.black.withAlpha(26), // 0.1 opacity
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
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
                    color: Colors.transparent,
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
                    color: Colors.transparent,
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
} // <-- This is the correct closing brace for _LoginPageState