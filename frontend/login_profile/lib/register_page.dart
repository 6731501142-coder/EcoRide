import 'package:flutter/material.dart';
import 'ecoride_colors.dart';
import 'home_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isObscure = true;
  bool _isConfirmObscure = true;
  
  // Controllers for input fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  void _handleRegister() {
    // Prepare data to match database columns (users table)
    final Map<String, dynamic> requestData = {
      'full_name': _fullNameController.text,
      'student_id': _studentIdController.text,
      'username': _usernameController.text,
      'password': _passwordController.text, // Backend handles hashing to password_hash
    };

    print('Data to send to Backend: $requestData');
    
    // Clear navigation stack and navigate to HomePage
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomePage()),
      (route) => false, 
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentIdController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoRideColors.bgWhite,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back, color: EcoRideColors.textMain),
                  ),
                  const SizedBox(width: 16),
                  const Text('Create account', style: TextStyle(color: EcoRideColors.textMain, fontSize: 18, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildInputField(controller: _fullNameController, hint: 'Full name'),
                      const SizedBox(height: 16),
                      _buildInputField(controller: _studentIdController, hint: 'Student / staff ID'),
                      const SizedBox(height: 16),
                      _buildInputField(controller: _usernameController, hint: 'Username'),
                      const SizedBox(height: 16),
                      _buildPasswordField(controller: _passwordController, hint: 'Password', isObscure: _isObscure, onToggle: () => setState(() => _isObscure = !_isObscure)),
                      const SizedBox(height: 16),
                      _buildPasswordField(controller: _confirmPasswordController, hint: 'Confirm password', isObscure: _isConfirmObscure, onToggle: () => setState(() => _isConfirmObscure = !_isConfirmObscure)),
                      const SizedBox(height: 12),
                      const Text('Use at least 8 characters.', style: TextStyle(color: EcoRideColors.textMuted, fontSize: 12)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: EcoRideColors.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                  elevation: 0,
                ),
                child: const Text('Sign up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint}) {
    return Container(
      decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(99)),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: EcoRideColors.textMain),
        decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: EcoRideColors.textMuted, fontSize: 14), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16)),
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint, required bool isObscure, required VoidCallback onToggle}) {
    return Container(
      decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(99)),
      child: TextField(
        controller: controller,
        obscureText: isObscure,
        style: const TextStyle(color: EcoRideColors.textMain),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: EcoRideColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: IconButton(icon: Icon(isObscure ? Icons.visibility_off : Icons.visibility, color: EcoRideColors.textMuted), onPressed: onToggle),
        ),
      ),
    );
  }
}