import 'package:file_picker/file_picker.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:queueless_office/screens/dashboad/OfficeDashboardScreen.dart';

class OfficeOnboardingScreen extends StatefulWidget {
  const OfficeOnboardingScreen({super.key});

  @override
  State<OfficeOnboardingScreen> createState() => _OfficeOnboardingScreenState();
}

class _OfficeOnboardingScreenState extends State<OfficeOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();

  String _category = 'CLINIC'; // 'CLINIC' or 'SALON'

  // General Controllers
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _pincodeController = TextEditingController();
  final _openingTimeController = TextEditingController(text: '09:00 AM');
  final _closingTimeController = TextEditingController(text: '08:00 PM');

  // Clinic Controllers
  final _doctorNameController = TextEditingController();
  final _specializationController = TextEditingController();
  final _medRegNoController = TextEditingController();

  // Salon Controllers
  final _tradeLicenseController = TextEditingController();
  String _salonType = 'Unisex';

  // Other Controllers
  final _otherBusinessTypeController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Files
  PlatformFile? _primaryDoc;
  PlatformFile? _secondaryDoc;

  bool _loading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _openingTimeController.dispose();
    _closingTimeController.dispose();
    _doctorNameController.dispose();
    _specializationController.dispose();
    _medRegNoController.dispose();
    _tradeLicenseController.dispose();
    _otherBusinessTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  String get _baseUrl => kIsWeb
      ? 'http://localhost:8080/api/office/onboarding'
      : 'http://10.0.2.2:8080/api/office/onboarding';

  Future<void> _pickFile(bool isPrimary) async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result.isNotEmpty) {
      setState(() {
        if (isPrimary) {
          _primaryDoc = result.first;
        } else {
          _secondaryDoc = result.first;
        }
      });
    }
  }

  Future<void> _submitOnboarding() async {
    if (!_formKey.currentState!.validate()) return;

    if (_primaryDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload the required primary document')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final token = await _storage.read(key: 'jwt_token');

      if (token == null || token.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired or not logged in. Please sign in.'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      var request = http.MultipartRequest('POST', Uri.parse(_baseUrl));
      request.headers['Authorization'] = 'Bearer $token';

      // General Fields
      request.fields['category'] = _category;
      request.fields['phone'] = _phoneController.text.trim();
      request.fields['address'] = _addressController.text.trim();
      request.fields['city'] = _cityController.text.trim();
      request.fields['state'] = _stateController.text.trim();
      request.fields['pincode'] = _pincodeController.text.trim();
      request.fields['openingTime'] = _openingTimeController.text.trim();
      request.fields['closingTime'] = _closingTimeController.text.trim();
      request.fields['description'] = _descriptionController.text.trim();

      // Category Specific Fields
      if (_category == 'CLINIC') {
        request.fields['doctorName'] = _doctorNameController.text.trim();
        request.fields['specialization'] = _specializationController.text.trim();
        request.fields['medicalRegistrationNumber'] = _medRegNoController.text.trim();
      } else if (_category == 'SALON') {
        request.fields['salonType'] = _salonType;
        request.fields['tradeLicenseNumber'] = _tradeLicenseController.text.trim();
      } else if (_category == 'OTHER') {
        request.fields['specialization'] = _otherBusinessTypeController.text.trim();
        request.fields['tradeLicenseNumber'] = _tradeLicenseController.text.trim();
      }

      // Attach Primary File
      if (kIsWeb || _primaryDoc!.path == null) {
        final bytes = await _primaryDoc!.xFile.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes(
          'primaryDocument',
          bytes,
          filename: _primaryDoc!.name,
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath(
          'primaryDocument',
          _primaryDoc!.path!,
          filename: _primaryDoc!.name,
        ));
      }

      // Attach Secondary File (if picked)
      if (_secondaryDoc != null) {
        if (kIsWeb || _secondaryDoc!.path == null) {
          final bytes = await _secondaryDoc!.xFile.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes(
            'secondaryDocument',
            bytes,
            filename: _secondaryDoc!.name,
          ));
        } else {
          request.files.add(await http.MultipartFile.fromPath(
            'secondaryDocument',
            _secondaryDoc!.path!,
            filename: _secondaryDoc!.name,
          ));
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Details and documents submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Navigate to Office Dashboard
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const OfficeDashboardScreen(),
            ),
                (route) => false,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Submission failed: ${response.body}'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Office Setup'),
        backgroundColor: const Color(0xFF4F46E5),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Select Your Business Category',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              // Category Selector (Clinic, Salon, Other)
              Row(
                children: [
                  _categoryChip('CLINIC', 'Clinic', Icons.local_hospital_outlined),
                  const SizedBox(width: 8),
                  _categoryChip('SALON', 'Salon', Icons.content_cut_outlined),
                  const SizedBox(width: 8),
                  _categoryChip('OTHER', 'Other', Icons.business_outlined),
                ],
              ),
              const SizedBox(height: 24),

              // Dynamic Category-Specific Form Section
              if (_category == 'CLINIC') ...[
                const Text('Clinic & Doctor Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _inputField('Doctor Name', _doctorNameController, 'Dr. John Doe'),
                _inputField('Specialization', _specializationController, 'e.g. Dentistry, Cardiology'),
                _inputField('Medical Registration No.', _medRegNoController, 'e.g. MED-12345'),
              ] else if (_category == 'SALON') ...[
                const Text('Salon Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _inputField('Trade License / GST No.', _tradeLicenseController, 'e.g. TR-987654'),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _salonType,
                  decoration: const InputDecoration(labelText: 'Salon Type', border: OutlineInputBorder()),
                  items: ['Unisex', 'Men Only', 'Women Only']
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setState(() => _salonType = v!),
                ),
              ] else if (_category == 'OTHER') ...[
                const Text('Business Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _inputField('Business Type / Industry', _otherBusinessTypeController, 'e.g. Bank, Government Office, Consulting, Gym'),
                _inputField('License / Registration No. (Optional)', _tradeLicenseController, 'e.g. REG-12345, GSTIN', isRequired: false),
                _inputField('Business Description (Optional)', _descriptionController, 'Brief description of services', isRequired: false),
              ],

              const SizedBox(height: 24),
              const Text('Address & Contact', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _inputField('Phone Number', _phoneController, '+91 9876543210', keyboardType: TextInputType.phone),
              _inputField('Street Address', _addressController, 'Shop 12, Main Street'),
              Row(
                children: [
                  Expanded(child: _inputField('City', _cityController, 'Mumbai')),
                  const SizedBox(width: 10),
                  Expanded(child: _inputField('Pincode', _pincodeController, '400001')),
                ],
              ),

              const SizedBox(height: 24),
              const Text('Document Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),

              // Document Upload Pickers
              _documentPickerCard(
                title: _category == 'CLINIC'
                    ? '1. Clinic Registration Certificate (Required)'
                    : _category == 'SALON'
                        ? '1. Trade / Business License (Required)'
                        : '1. Business Registration / Govt ID (Required)',
                file: _primaryDoc,
                onPick: () => _pickFile(true),
              ),
              const SizedBox(height: 12),
              _documentPickerCard(
                title: _category == 'CLINIC'
                    ? '2. Doctor Degree / ID (Optional)'
                    : _category == 'SALON'
                        ? '2. Owner ID Proof / GST (Optional)'
                        : '2. Additional Document / ID Proof (Optional)',
                file: _secondaryDoc,
                onPick: () => _pickFile(false),
              ),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _submitOnboarding,
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit for Verification', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChip(String type, String label, IconData icon) {
    final selected = _category == type;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _category = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF4F46E5).withOpacity(0.08) : Colors.white,
            border: Border.all(color: selected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0), width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? const Color(0xFF4F46E5) : Colors.grey),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: selected ? const Color(0xFF4F46E5) : Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        validator: (v) {
          if (!isRequired) return null;
          return (v == null || v.isEmpty) ? 'Please enter $label' : null;
        },
      ),
    );
  }

  Widget _documentPickerCard({required String title, required PlatformFile? file, required VoidCallback onPick}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Icon(file != null ? Icons.check_circle : Icons.upload_file, color: file != null ? Colors.green : Colors.indigo),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                if (file != null)
                  Text(file.name, style: const TextStyle(fontSize: 12, color: Colors.grey), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onPick,
            child: Text(file == null ? 'Browse' : 'Change'),
          ),
        ],
      ),
    );
  }
}