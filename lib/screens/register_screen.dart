import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'vendor_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // --- NEW: CONFIRM PASSWORD CONTROLLER ---
  final TextEditingController _confirmPasswordController = TextEditingController();

  final TextEditingController _bizNameController = TextEditingController();
  final TextEditingController _ssmController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _gitaController = TextEditingController();

  final AuthService _authService = AuthService();

  bool _isLoading = false;
  String _selectedRole = 'Consumer';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Dispose the new controller
    _bizNameController.dispose();
    _ssmController.dispose();
    _addressController.dispose();
    _gitaController.dispose(); 
    super.dispose();
  }

  // --- HELPER WIDGET FOR RED ASTERISKS ---
  Widget _buildLabel(String text, bool isMandatory) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black, fontSize: 14),
        children: [
          if (isMandatory)
            const TextSpan(text: ' *', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _handleRegister() async {
    // 1. Basic validation including Confirm Password
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all basic fields')));
      return;
    }

    // 2. --- NEW: PASSWORD MATCH VALIDATION ---
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('Passwords do not match. Please try again.')
        )
      );
      return;
    }

    // 3. Vendor validation (Notice we don't check _gitaController because it's optional)
    if (_selectedRole == 'Vendor') {
      if (_bizNameController.text.isEmpty || _ssmController.text.isEmpty || _addressController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vendors must provide all mandatory business details')));
        return;
      }
    }

    setState(() => _isLoading = true);

    var user = await _authService.registerWithEmailPassword(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text.trim(), // We only send the main password to Firebase
      _selectedRole,
      businessName: _selectedRole == 'Vendor' ? _bizNameController.text.trim() : null,
      ssmNumber: _selectedRole == 'Vendor' ? _ssmController.text.trim() : null,
      businessAddress: _selectedRole == 'Vendor' ? _addressController.text.trim() : null,
      gitaNumber: _selectedRole == 'Vendor' ? _gitaController.text.trim() : null, 
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user != null) {
      if (_selectedRole == 'Vendor') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.orange, content: Text('Application Submitted. Waiting for Admin Approval.'), duration: Duration(seconds: 4)),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const VendorDashboard()));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(backgroundColor: Colors.green, content: Text('Account Created!')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const HomeScreen()));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed. Email might be in use.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        title: const Text('Sign Up', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('I want to register as a...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = 'Consumer'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'Consumer' ? Colors.green.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(color: _selectedRole == 'Consumer' ? Colors.green : Colors.grey, width: 2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text('Consumer', style: TextStyle(color: _selectedRole == 'Consumer' ? Colors.green : Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedRole = 'Vendor'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedRole == 'Vendor' ? Colors.orange.withValues(alpha: 0.1) : Colors.transparent,
                          border: Border.all(color: _selectedRole == 'Vendor' ? Colors.deepOrange : Colors.grey, width: 2),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(
                          child: Text('Vendor', style: TextStyle(color: _selectedRole == 'Vendor' ? Colors.deepOrange : Colors.grey, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // --- BASIC INFO ---
              _buildLabel('Full Name / Representative Name', true),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
              ),
              const SizedBox(height: 16),

              _buildLabel('Email Address', true),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
              ),
              const SizedBox(height: 16),

              _buildLabel('Password', true),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
              ),
              const SizedBox(height: 16),
              
              // --- NEW: CONFIRM PASSWORD FIELD ---
              _buildLabel('Confirm Password', true),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0))),
              ),
              const SizedBox(height: 24),

              // --- DYNAMIC VENDOR FIELDS ---
              if (_selectedRole == 'Vendor') ...[
                const Divider(),
                const SizedBox(height: 16),
                const Text('Business Verification Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.deepOrange)),
                const SizedBox(height: 16),

                _buildLabel('Registered Business Name', true),
                const SizedBox(height: 8),
                TextField(
                  controller: _bizNameController,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), hintText: 'e.g., GreenBite Bakery Sdn Bhd'),
                ),
                const SizedBox(height: 16),

                _buildLabel('SSM Registration Number', true),
                const SizedBox(height: 8),
                TextField(
                  controller: _ssmController,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), hintText: 'e.g., 202301123456'),
                ),
                const SizedBox(height: 16),

                _buildLabel('Full Store Address', true),
                const SizedBox(height: 8),
                TextField(
                  controller: _addressController,
                  maxLines: 2,
                  decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), hintText: 'Street, City, Postcode, State'),
                ),
                const SizedBox(height: 16),

                _buildLabel('Green Investment Tax Allowance (GITA)', false), // false = No red asterisk
                const SizedBox(height: 8),
                TextField(
                  controller: _gitaController,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), 
                    hintText: 'Optional GITA Reference',
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 4, left: 4),
                  child: Text('Optional: Helps verify your eco-friendly status.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
                const SizedBox(height: 32),
              ],

              ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedRole == 'Vendor' ? Colors.deepOrange : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Application', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}