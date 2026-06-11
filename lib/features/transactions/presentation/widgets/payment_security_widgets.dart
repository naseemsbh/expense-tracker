import 'package:flutter/material.dart';

// --- 1. MPIN DIALOG ---
class MpinDialog extends StatefulWidget {
  final VoidCallback onSuccess;
  const MpinDialog({super.key, required this.onSuccess});

  @override
  State<MpinDialog> createState() => _MpinDialogState();
}

class _MpinDialogState extends State<MpinDialog> {
  final List<String> _pin = [];

  void _onKeyTap(String val) {
    if (_pin.length < 4) {
      setState(() => _pin.add(val));
    }
    if (_pin.length == 4) {
      // SIMULATED VALIDATION
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          widget.onSuccess(); // Trigger success action
        }
      });
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) setState(() => _pin.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      color: const Color(0xFF1F1F1F),
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Text("Enter 4-digit UPI PIN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // DOTS
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: index < _pin.length ? Colors.white : Colors.grey[800],
                ),
              );
            }),
          ),
          const Spacer(),
          // KEYPAD
          Wrap(
            spacing: 20, runSpacing: 20,
            alignment: WrapAlignment.center,
            children: [
              for (var i = 1; i <= 9; i++) _buildKey(i.toString()),
              _buildKey("", isEmpty: true),
              _buildKey("0"),
              _buildKey("⌫", isIcon: true),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildKey(String val, {bool isIcon = false, bool isEmpty = false}) {
    if (isEmpty) return const SizedBox(width: 80, height: 60);
    return InkWell(
      onTap: () => isIcon ? _onBackspace() : _onKeyTap(val),
      child: Container(
        width: 80, height: 60,
        alignment: Alignment.center,
        child: isIcon
            ? const Icon(Icons.backspace_outlined, color: Colors.white)
            : Text(val, style: const TextStyle(color: Colors.white, fontSize: 24)),
      ),
    );
  }
}

// --- 2. SUCCESS ANIMATION SCREEN ---
class PaymentSuccessPage extends StatefulWidget {
  final double amount;
  final String name;
  const PaymentSuccessPage({super.key, required this.amount, required this.name});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _scaleAnimation = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();

    // Auto close after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if(mounted) Navigator.pop(context, true); // Return true to indicate success
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF669DF6), // Brand Blue
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: const Icon(Icons.check, size: 60, color: Color(0xFF669DF6)),
              ),
            ),
            const SizedBox(height: 30),
            // FIX: Use widget.amount
            Text(
                "Paid ₹${widget.amount}",
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 10),
            // FIX: Use widget.name
            Text(
                "to ${widget.name}",
                style: const TextStyle(color: Colors.white70, fontSize: 18)
            ),
          ],
        ),
      ),
    );
  }
}