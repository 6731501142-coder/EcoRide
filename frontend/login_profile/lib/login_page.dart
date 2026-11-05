import 'package:flutter/material.dart';
import 'ecoride_colors.dart';
import 'register_page.dart';
import 'home_page.dart'; 

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isObscure = true; 
  
  // Controllers for input fields
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  void _handleLogin() {
    // Prepare data to match database columns (users table)
    final Map<String, dynamic> requestData = {
      'username': _usernameController.text,
      'password': _passwordController.text, // Backend handles hashing
    };

    print('Data to send to Backend: $requestData');
    
    // Replace current route with HomePage to prevent back navigation to Login
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoRideColors.bgWhite,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 80, bottom: 30),
            decoration: const BoxDecoration(
              color: EcoRideColors.primaryRed,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(34),
                bottomRight: Radius.circular(34),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(color: EcoRideColors.bgLight, shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: EcoRideColors.primaryRed, size: 36),
                ),
                const SizedBox(height: 12),
                const Text('EcoRide', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                const Text('Electric rides around campus', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildInputField(
                    controller: _usernameController,
                    icon: Icons.person_outline,
                    hint: 'Username',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    controller: _passwordController,
                    icon: Icons.lock_outline,
                    hint: 'Password',
                    isPassword: true,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EcoRideColors.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                      elevation: 0,
                    ),
                    child: const Text('Log in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('New here? ', style: TextStyle(color: EcoRideColors.textMuted)),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterPage()));
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Create account', style: TextStyle(color: EcoRideColors.primaryRed, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required IconData icon, required String hint, bool isPassword = false}) {
    return Container(
      decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(99)),
      child: TextField(
        controller: controller,
        obscureText: isPassword ? _isObscure : false,
        style: const TextStyle(color: EcoRideColors.textMain),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: EcoRideColors.textMuted, size: 20),
          suffixIcon: isPassword 
              ? IconButton(
                  icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: EcoRideColors.textMuted),
                  onPressed: () => setState(() => _isObscure = !_isObscure),
                )
              : null,
          hintText: hint,
          hintStyle: const TextStyle(color: EcoRideColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}