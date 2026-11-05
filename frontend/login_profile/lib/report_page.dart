import 'package:flutter/material.dart';
import 'ecoride_colors.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({super.key});

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  String? _selectedIssue;
  
  // Controller for issue description matching database column
  final TextEditingController _descriptionController = TextEditingController(); 

  // Mapping UI labels to database ENUM values (maintenance_reports table)
  final Map<String, String> _issueTypesMap = {
    'Brakes / wheels': 'brake',
    'Damaged part': 'body_damage',
    'Battery issue': 'battery',
    'Electrical issue': 'electrical',
    'Tire issue': 'tire',
    'Other': 'other'
  };

  void _submitReport() {
    // Prepare data to match database columns (maintenance_reports table)
    final Map<String, dynamic> requestData = {
      // Backend requires user_id and vehicle_id to complete the insertion
      'issue_type': _issueTypesMap[_selectedIssue] ?? 'other', 
      'description': _descriptionController.text,
    };

    print('Data to send to Backend: $requestData');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted successfully')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EcoRideColors.bgWhite,
      appBar: AppBar(
        backgroundColor: EcoRideColors.bgWhite,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: EcoRideColors.textMain), onPressed: () => Navigator.pop(context)),
        title: const Text('Report a problem', style: TextStyle(color: EcoRideColors.textMain, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('What\'s wrong?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: EcoRideColors.textMain)),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(16)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedIssue,
                  hint: const Text('Select issue type', style: TextStyle(color: EcoRideColors.textMuted)),
                  items: _issueTypesMap.keys.map((String value) {
                    return DropdownMenuItem<String>(value: value, child: Text(value, style: const TextStyle(color: EcoRideColors.textMain)));
                  }).toList(),
                  onChanged: (newValue) {
                    setState(() { _selectedIssue = newValue; }); 
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: EcoRideColors.inputBg, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: _descriptionController,
                maxLines: 5,
                style: const TextStyle(color: EcoRideColors.textMain),
                decoration: const InputDecoration(hintText: 'Describe the issue...', hintStyle: TextStyle(color: EcoRideColors.textMuted), border: InputBorder.none),
              ),
            ),
            const Spacer(),

            ElevatedButton(
              onPressed: _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: EcoRideColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                elevation: 0,
              ),
              child: const Text('Send report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}