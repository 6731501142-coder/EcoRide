import 'package:flutter/material.dart';
import 'ecoride_colors.dart';

class AccountSettingsPage extends StatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  bool _isObscure = true;

  // Controllers for input fields
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // TODO: Fetch existing user data from Backend and display it here
    _fullNameController.text = "Somchai Jaidee"; // Dummy existing data
    _emailController.text = ""; // Empty email for testing
  }

  void _handleSaveSettings() {
    // Prepare data to match database columns (users table)
    final Map<String, dynamic> requestData = {};

    // Only send fields that have been filled/changed
    if (_fullNameController.text.isNotEmpty) {
      requestData['full_name'] = _fullNameController.text;
    }
    if (_emailController.text.isNotEmpty) {
      requestData['email'] = _emailController.text;
    }
    if (_passwordController.text.isNotEmpty) {
      requestData['password'] = _passwordController.text; // Backend handles hashing to password_hash
    }

    print('Data to send to Backend (Update Profile): $requestData');

    // Show success message and go back
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account settings updated successfully')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoRideColors.bgWhite,
      appBar: AppBar(
        backgroundColor: EcoRideColors.bgWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: EcoRideColors.textMain),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Account settings', style: TextStyle(color: EcoRideColors.textMain, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Profile Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: EcoRideColors.textMain)),
            const SizedBox(height: 16),
            _buildInputField(controller: _fullNameController, hint: 'Full name', icon: Icons.person_outline),
            const SizedBox(height: 16),
            _buildInputField(controller: _emailController, hint: 'Email address', icon: Icons.email_outlined),
            
            const SizedBox(height: 32),
            
            const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: EcoRideColors.textMain)),
            const SizedBox(height: 16),
            _buildPasswordField(controller: _passwordController, hint: 'New password'),
            const SizedBox(height: 8),
            const Text(
              'Leave password blank if you do not want to change it.',
              style: TextStyle(color: EcoRideColors.textMuted, fontSize: 12),
            ),
            
            const SizedBox(height: 40),
            
            ElevatedButton(
              onPressed: _handleSaveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: EcoRideColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                elevation: 0,
              ),
              child: const Text('Save changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({required TextEditingController controller, required String hint, required IconData icon}) {
    return Container(
      decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(99)),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: EcoRideColors.textMain),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: EcoRideColors.textMuted, size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: EcoRideColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required String hint}) {
    return Container(
      decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(99)),
      child: TextField(
        controller: controller,
        obscureText: _isObscure,
        style: const TextStyle(color: EcoRideColors.textMain),
        decoration: InputDecoration(
          prefixIcon: const Icon(Icons.lock_outline, color: EcoRideColors.textMuted, size: 20),
          hintText: hint,
          hintStyle: const TextStyle(color: EcoRideColors.textMuted, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          suffixIcon: IconButton(
            icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: EcoRideColors.textMuted),
            onPressed: () => setState(() => _isObscure = !_isObscure),
          ),
        ),
      ),
    );
  }
}