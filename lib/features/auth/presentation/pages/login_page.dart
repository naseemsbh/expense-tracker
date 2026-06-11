import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_gate_page.dart';
import '../../data/auth_service.dart';
import '../../../../features/account/presentation/pages/add_first_account_page.dart';
import '../../data/local_storage_service.dart';
// IMPORT HOME PAGE (Adjust path if needed)
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  final String? autoFillPhone;
  const LoginPage({super.key, this.autoFillPhone});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isPhoneLocked = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserPhone();
  }

  void _loadUserPhone() async {
    // Priority 1: Did we just come from Registration?
    if (widget.autoFillPhone != null) {
      setState(() {
        phoneController.text = widget.autoFillPhone!;
        isPhoneLocked = true;
      });
      return;
    }

    // Priority 2: Check Local Memory
    String? savedPhone = await LocalStorageService.getSavedPhoneNumber();
    if (savedPhone != null && savedPhone.isNotEmpty) {
      setState(() {
        phoneController.text = savedPhone;
        isPhoneLocked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                const Center(child: Icon(Icons.wallet, size: 60, color: Colors.black)),
                const SizedBox(height: 20),
                const Center(
                  child: Text("Welcome Back", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 40),

                // Phone Input
                if (isPhoneLocked) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_android, color: Colors.grey),
                        const SizedBox(width: 12),
                        Text("+91 ${phoneController.text}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey)),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() { isPhoneLocked = false; phoneController.clear(); }),
                          child: const Text("CHANGE", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  const Text("Phone Number", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [LengthLimitingTextInputFormatter(10), FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      prefixText: "+91 ",
                      hintText: "Enter mobile number",
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Password Input
                const Text("Password", style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: !isPasswordVisible,
                  decoration: InputDecoration(
                    hintText: "Enter your password",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(isPasswordVisible ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => isPasswordVisible = !isPasswordVisible),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Login Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("Login", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 40),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AuthGatePage())),
                      child: const Text("Create Account", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- THE FIXED LOGIC IS HERE ---
  void _handleLogin() async {
    if (phoneController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => isLoading = true);

    try {
      // 1. Perform Login
      await AuthService().loginUser(
        phone: phoneController.text,
        password: passwordController.text,
      );

      // 2. CHECK: Has this user set up their account?
      bool hasSetup = await AuthService().isAccountSetup();

      if (!mounted) return;

      if (hasSetup) {
        // A. Old User -> Go to Home
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        // B. New User -> Go to Setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AddFirstAccountPage()),
        );
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Login Failed: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}