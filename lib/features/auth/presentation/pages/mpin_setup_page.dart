import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/auth_service.dart'; // Import AuthService
import 'login_page.dart'; // Import Login Page

class MpinSetupPage extends StatefulWidget {
  final String phoneNumber;

  const MpinSetupPage({super.key, required this.phoneNumber});

  @override
  State<MpinSetupPage> createState() => _MpinSetupPageState();
}

class _MpinSetupPageState extends State<MpinSetupPage> {
  // Logic State
  String _enteredPin = "";
  String _firstPin = ""; // Stores the PIN from step 1
  bool isConfirming = false;
  bool isBiometricEnabled = true;

  // Colors
  final Color bgDark = const Color(0xFF121418);
  final Color accentBlue = const Color(0xFF4B39EF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        automaticallyImplyLeading: false, // Custom header
        toolbarHeight: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () {
                      if (isConfirming) {
                        // Go back to Step 1
                        setState(() {
                          isConfirming = false;
                          _enteredPin = "";
                          _firstPin = "";
                        });
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const Spacer(),
                  Text(
                    isConfirming ? "CONFIRM MPIN" : "SET NEW MPIN",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // Balance spacing
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- CONTEXT TEXT ---
            Column(
              children: [
                Icon(
                    isConfirming ? Icons.lock_outline : Icons.lock_open_rounded,
                    size: 40,
                    color: Colors.white70
                ),
                const SizedBox(height: 16),
                Text(
                  isConfirming ? "Re-enter your 4-digit PIN" : "Create a 4-digit PIN",
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  isConfirming
                      ? "Make sure it matches the first one"
                      : "You will use this to unlock the app",
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // --- PIN INDICATORS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                bool isFilled = _enteredPin.length > index;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled ? Colors.white : Colors.white24,
                    boxShadow: isFilled
                        ? [BoxShadow(color: accentBlue.withOpacity(0.6), blurRadius: 15, spreadRadius: 2)]
                        : [],
                  ),
                );
              }),
            ),

            const Spacer(),

            // --- BIOMETRIC SWITCH (Only on Step 1) ---
            if (!isConfirming)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                width: 280,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fingerprint, color: Colors.white70),
                        SizedBox(width: 12),
                        Text("Enable Biometrics", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Switch(
                      value: isBiometricEnabled,
                      activeColor: accentBlue,
                      onChanged: (val) => setState(() => isBiometricEnabled = val),
                    ),
                  ],
                ),
              ),

            // --- CUSTOM KEYPAD ---
            Container(
              padding: const EdgeInsets.only(bottom: 40, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildKeyRow(["1", "2", "3"]),
                  const SizedBox(height: 20),
                  _buildKeyRow(["4", "5", "6"]),
                  const SizedBox(height: 20),
                  _buildKeyRow(["7", "8", "9"]),
                  const SizedBox(height: 20),
                  _buildKeyRow(["BACKSPACE", "0", "EMPTY"]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- LOGIC: Handle Key Press ---
  void _onKeyPress(String val) {
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() => _enteredPin += val);

      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), () => _handleStepCompletion());
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  // --- LOGIC: Step Completion ---
  void _handleStepCompletion() async {
    if (!isConfirming) {
      // Step 1 Finished -> Move to Confirm
      setState(() {
        _firstPin = _enteredPin;
        _enteredPin = "";
        isConfirming = true;
      });
    } else {
      // Step 2 Finished -> Validate
      if (_enteredPin == _firstPin) {
        // SUCCESS: Save & Redirect
        HapticFeedback.heavyImpact();
        try {
          // Save to Firebase/Local Storage
          await AuthService().setMpin(_enteredPin);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Setup Complete! Please Login."), backgroundColor: Colors.green)
          );

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => LoginPage(
                autoFillPhone: widget.phoneNumber,
              ),
            ),
                (route) => false,
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      } else {
        // ERROR: Mismatch
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("PINs do not match. Try again."), backgroundColor: Colors.red)
        );
        setState(() {
          isConfirming = false; // Reset to start
          _enteredPin = "";
          _firstPin = "";
        });
      }
    }
  }

  // --- WIDGET HELPERS ---
  Widget _buildKeyRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key == "BACKSPACE") {
          return _buildSpecialKey(icon: Icons.backspace_outlined, onTap: _onBackspace);
        }
        if (key == "EMPTY") {
          return const SizedBox(width: 80, height: 80);
        }
        return _buildNumberKey(key);
      }).toList(),
    );
  }

  Widget _buildNumberKey(String number) {
    return Container(
      width: 80,
      height: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onKeyPress(number),
          borderRadius: BorderRadius.circular(40),
          splashColor: Colors.white24,
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpecialKey({required IconData icon, required VoidCallback onTap}) {
    return Container(
      width: 80,
      height: 80,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Center(
            child: Icon(icon, color: Colors.white70, size: 28),
          ),
        ),
      ),
    );
  }
}