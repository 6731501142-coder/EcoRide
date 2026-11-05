import 'package:flutter/material.dart';
import 'ecoride_colors.dart';
import 'profile_page.dart';
import 'report_page.dart'; 

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0; // Default to Home page (0)

  // List of pages for Bottom Navigation
  final List<Widget> _pages = [
    const _MockPage(title: 'Home Page', icon: Icons.home),
    const _MockPage(title: 'Scan QR Page', icon: Icons.qr_code_scanner),
    const _MockPage(title: 'History Page', icon: Icons.history),
    const ProfilePage(), // Integrated Profile Page
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Ensure all 4 icons are visible
        currentIndex: _selectedIndex,
        selectedItemColor: EcoRideColors.primaryRed,
        unselectedItemColor: EcoRideColors.textMuted,
        backgroundColor: EcoRideColors.bgWhite,
        elevation: 10,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; 
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      
      // Temporary floating button to test Report Page navigation
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const ReportPage()));
        },
        backgroundColor: EcoRideColors.primaryRed,
        child: const Icon(Icons.report_problem, color: Colors.white),
      ),
    );
  }
}

// Dummy page for testing navigation
class _MockPage extends StatelessWidget {
  final String title;
  final IconData icon;
  const _MockPage({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: EcoRideColors.textMuted),
          const SizedBox(height: 16),
          Text(title, style: const TextStyle(fontSize: 24, color: EcoRideColors.textMain)),
        ],
      ),
    );
  }
}