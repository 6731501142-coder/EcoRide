import 'package:flutter/material.dart';
import 'ecoride_colors.dart';
import 'login_page.dart';
import 'account_settings_page.dart'; // Import Account Settings Page

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // Variables matching database naming conventions for incoming data
  String full_name = 'Loading...'; 
  String student_id = 'Loading...';
  String role = 'user'; // Matches ENUM('user','admin')
  
  // Statistical data to be calculated from backend views (e.g., v_borrowing_history)
  int total_rides = 0;
  double hours_ridden = 0.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoRideColors.bgWhite,
      appBar: AppBar(
        backgroundColor: EcoRideColors.bgWhite,
        elevation: 0,
        title: const Text('Profile', style: TextStyle(color: EcoRideColors.textMain, fontWeight: FontWeight.w600)),
        centerTitle: true,
        automaticallyImplyLeading: false, 
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const CircleAvatar(radius: 45, backgroundColor: EcoRideColors.bgLight, child: Icon(Icons.person, size: 45, color: EcoRideColors.primaryRed)),
              const SizedBox(height: 16),
              
              // Display dynamic user data
              Text(full_name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: EcoRideColors.textMain)),
              const SizedBox(height: 4),
              Text('$student_id - $role', style: const TextStyle(fontSize: 16, color: EcoRideColors.textMuted)),
              const SizedBox(height: 24),

              // Statistics cards
              Row(
                children: [
                  Expanded(child: _buildStatCard(title: 'Total rides', value: total_rides.toString())),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard(title: 'Hours ridden', value: hours_ridden.toStringAsFixed(1))),
                ],
              ),
              const SizedBox(height: 32),

              _buildMenuItem(
                context, 
                icon: Icons.history, 
                title: 'Borrowing history', 
                onTap: () {
                  // TODO: Navigate to Borrowing History Page
                }
              ),
              _buildMenuItem(
                context, 
                icon: Icons.settings, 
                title: 'Account settings', 
                onTap: () {
                  // Navigate to Account Settings Page
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountSettingsPage()));
                }
              ),
              
              const SizedBox(height: 40),
              TextButton.icon(
                onPressed: () {
                  // Clear session and return to Login Page
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                    (route) => false,
                  );
                },
                icon: const Icon(Icons.logout, color: EcoRideColors.primaryRed),
                label: const Text('Log out', style: TextStyle(color: EcoRideColors.primaryRed, fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({required String title, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(color: EcoRideColors.bgLight, borderRadius: BorderRadius.circular(16)),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: EcoRideColors.textMain)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 14, color: EcoRideColors.textMain)),
        ],
      ),
    );
  }

  // Updated to accept onTap callback
  Widget _buildMenuItem(BuildContext context, {required IconData icon, required String title, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: EcoRideColors.bgLight, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: EcoRideColors.primaryRed, size: 24),
      ),
      title: Text(title, style: const TextStyle(color: EcoRideColors.textMain, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: EcoRideColors.textMuted),
      onTap: onTap, // Assign the navigation action here
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
    );
  }
}