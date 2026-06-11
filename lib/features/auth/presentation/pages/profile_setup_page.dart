import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../data/auth_service.dart'; // Import AuthService
import 'mpin_setup_page.dart'; // Import MPIN Page

class ProfileSetupPage extends StatefulWidget {
  final String phoneNumber; // 1. We received this from the OTP page

  const ProfileSetupPage({super.key, required this.phoneNumber});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  bool isPasswordVisible = false;
  File? _selectedImage;
  bool isLoading = false; // Loading state

  Future<void> _pickImage() async {
    final returnedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (returnedImage == null) return;
    setState(() {
      _selectedImage = File(returnedImage.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Setup Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Logic
            Center(
              child: Stack(
                children: [
                  Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      image: _selectedImage != null
                          ? DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _selectedImage == null ? const Icon(Icons.person, size: 60, color: Colors.grey) : null,
                  ),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black, shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                hintText: "Enter your name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            const Text("Create Password", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: passwordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Minimum 6 characters",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixIcon: IconButton(
                  icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text("Confirm Password", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              controller: confirmPasswordController,
              obscureText: !isPasswordVisible,
              decoration: InputDecoration(
                hintText: "Re-enter password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: isLoading ? null : _validateAndRegister,
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Create Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _validateAndRegister() async {
    if (nameController.text.isEmpty) {
      _showError("Please enter your name");
    } else if (passwordController.text.length < 6) {
      _showError("Password must be at least 6 characters");
    } else if (passwordController.text != confirmPasswordController.text) {
      _showError("Passwords do not match");
    } else {
      // --- HERE IS THE MAGIC ---
      // We save the data to Firebase NOW.
      setState(() => isLoading = true);

      try {
        await AuthService().registerUser(
          phone: widget.phoneNumber,
          password: passwordController.text,
          name: nameController.text,
        );

        if (!mounted) return;

        // Success! Move to MPIN Page and PASS THE PHONE NUMBER
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MpinSetupPage(phoneNumber: widget.phoneNumber), // <--- Passing it along
          ),
        );
      } catch (e) {
        _showError(e.toString());
      } finally {
        if (mounted) setState(() => isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }
}