import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'phone_login_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  Future<void> _submit() async {
    setState(() => _isLoading = true);
    String email = _emailController.text.trim();
    String password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError("Please fill in all fields.");
      setState(() => _isLoading = false);
      return;
    }

    try {
      if (_isLogin) {
        await _auth.signInWithEmail(email, password);
      } else {
        await _auth.signUpWithEmail(email, password, 'Citizen');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await _auth.signInWithGoogle();
    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.location_city,
                size: 80,
                color: Color(0xFFFF6D00),
              ),
              const SizedBox(height: 20),
              const Text(
                "FixCity",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _isLogin ? "Welcome back, Hero!" : "Join the movement.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 16),
              ),
              const SizedBox(height: 40),

              // 1. EMAIL INPUT
              TextField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Email Address", Icons.email),
              ),
              const SizedBox(height: 20),

              // 2. PASSWORD INPUT
              TextField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _inputDecoration("Password", Icons.lock),
              ),
              const SizedBox(height: 20),

              // 3. MAIN ACTION BUTTON (LOGIN/SIGNUP)
              _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF6D00),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6D00),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _isLogin ? "LOG IN" : "SIGN UP",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
              const SizedBox(height: 20),

              // 4. TOGGLE ACCOUNT TYPE (Don't have an account?)
              TextButton(
                onPressed: () => setState(() => _isLogin = !_isLogin),
                child: RichText(
                  text: TextSpan(
                    text: _isLogin
                        ? "Don't have an account? "
                        : "Already have an account? ",
                    style: const TextStyle(color: Colors.grey),
                    children: [
                      TextSpan(
                        text: _isLogin ? "Sign Up" : "Log In",
                        style: const TextStyle(
                          color: Color(0xFFFF6D00),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // 5. PHONE LOGIN BUTTON (Added Correctly Here)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PhoneLoginScreen(),
                    ),
                  );
                },
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.phone, size: 16, color: Color(0xFFFF6D00)),
                    SizedBox(width: 8),
                    Text(
                      "Log in with Phone Number",
                      style: TextStyle(
                        color: Color(0xFFFF6D00),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
              const Divider(color: Colors.white24),
              const SizedBox(height: 30),

              // 6. GOOGLE SIGN IN
              OutlinedButton.icon(
                onPressed: _handleGoogleSignIn,
                icon: const Icon(
                  Icons.g_mobiledata,
                  size: 30,
                  color: Colors.white,
                ),
                label: const Text(
                  "Continue with Google",
                  style: TextStyle(color: Colors.white),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // 7. ADMIN / CONTRACTOR LINKS
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/admin_login'),
                    icon: const Icon(
                      Icons.admin_panel_settings,
                      size: 14,
                      color: Colors.grey,
                    ),
                    label: const Text(
                      "Admin Access",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text("|", style: TextStyle(color: Colors.white24)),
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () =>
                        Navigator.pushNamed(context, '/contractor_login'),
                    icon: const Icon(
                      Icons.engineering,
                      size: 14,
                      color: Colors.grey,
                    ),
                    label: const Text(
                      "Contractor Access",
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.grey),
      prefixIcon: Icon(icon, color: const Color(0xFFFF6D00)),
      filled: true,
      fillColor: const Color(0xFF1E1E1E),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFFF6D00)),
      ),
    );
  }
}
