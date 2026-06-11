import 'package:cloud_firestore/cloud_firestore.dart'; // To check DB
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'otp_verification_page.dart'; // Import the OTP page

class AuthGatePage extends StatefulWidget {
  const AuthGatePage({super.key});

  @override
  State<AuthGatePage> createState() => _AuthGatePageState();
}

class _AuthGatePageState extends State<AuthGatePage> {
  // Controller: Captures what the user types
  final TextEditingController phoneController = TextEditingController();

  // State: Are we loading (checking database)?
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, // Align text to left
            children: [
              const SizedBox(height: 60), // Top spacing

              // 1. The Headline
              const Text(
                "Welcome to\nExpense Pro",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  height: 1.2, // Line height
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter your phone number to continue",
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),

              const SizedBox(height: 40),

              // 2. The Input Field (Styled like GPay)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Row(
                  children: [
                    // A. Country Code (Static for now)
                    const Text(
                      "🇮🇳 +91",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 12),

                    // B. Vertical Divider
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(width: 12),

                    // C. The Actual Input
                    Expanded(
                      child: TextField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone, // Number pad
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2, // Space out numbers
                        ),
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(10), // Max 10 digits
                          FilteringTextInputFormatter.digitsOnly, // No letters
                        ],
                        decoration: const InputDecoration(
                          border: InputBorder.none, // Remove default line
                          hintText: "00000 00000",
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(), // Pushes button to bottom

              // 3. The "Next" Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    // Logic: Check if phone number is valid (10 digits)
                    if (phoneController.text.length == 10) {
                      _checkUserExistence();
                    } else {
                      // Show error snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please enter a valid 10-digit number")),
                      );
                    }
                  },
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  // --- SMART CHECK FUNCTION ---
  void _checkUserExistence() async {
    setState(() => isLoading = true);

    try {
      // 1. Check Firestore: Does a user with this phone number already exist?
      // We look for any document in 'users' collection where 'phone' matches.
      final QuerySnapshot result = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phoneController.text)
          .limit(1)
          .get();

      if (!mounted) return;

      if (result.docs.isNotEmpty) {
        // CASE A: User ALREADY EXISTS
        setState(() => isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Account already exists! Please Login."),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );

        // Optional: Go back to Login Page automatically
        // Navigator.pop(context);

      } else {
        // CASE B: New User -> Go to OTP
        setState(() => isLoading = false);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationPage(
              phoneNumber: phoneController.text,
            ),
          ),
        );
      }
    } catch (e) {
      // Handle network errors
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Connection Error: $e")),
      );
    }
  }
}