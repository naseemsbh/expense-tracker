import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MpinVerificationPage extends StatefulWidget {
  const MpinVerificationPage({super.key});

  @override
  State<MpinVerificationPage> createState() => _MpinVerificationPageState();
}

class _MpinVerificationPageState extends State<MpinVerificationPage> {
  String _enteredPin = "";

  @override
  Widget build(BuildContext context) {
    // 1. Premium Dark Theme Colors
    const Color bgDark = Color(0xFF121418); // Almost black
    const Color accentBlue = Color(0xFF4B39EF); // Your brand blue

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: bgDark,
        elevation: 0,
        automaticallyImplyLeading: false, // We use custom close button
        toolbarHeight: 0, // Hide default toolbar, use custom body
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- HEADER ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "ENTER PIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // --- BANK CONTEXT ---
            const Column(
              children: [
                Icon(Icons.lock_person_rounded, size: 40, color: Colors.white70),
                SizedBox(height: 16),
                Text(
                  "Unlock Payment Settings",
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  "Expense Tracker Pro",
                  style: TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // --- PIN INDICATORS (Underlined Style) ---
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
                  _buildKeyRow(["BACKSPACE", "0", "Submit"]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- KEYPAD LOGIC ---
  void _onKeyPress(String val) {
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact(); // Crisp vibration
      setState(() => _enteredPin += val);

      // Auto-submit when 4th digit is entered
      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 100), () => _verifyMpin());
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.selectionClick();
      setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
    }
  }

  void _verifyMpin() {
    if (_enteredPin == "1234") {
      HapticFeedback.heavyImpact(); // Success vibration
      Navigator.pop(context, true);
    } else {
      // Error Feedback
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 10),
                Text("Wrong PIN. Try again."),
              ],
            ),
            backgroundColor: Colors.red.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(20),
          )
      );
      setState(() => _enteredPin = "");
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
        if (key == "Submit") {
          // Placeholder for visual balance, or can be a checkmark
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
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Optional: Add subtle gradient or border for "Glass" effect
      ),
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
                fontWeight: FontWeight.w400, // Thinner, modern font weight
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