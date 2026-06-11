import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../features/auth/presentation/pages/mpin_verification_page.dart'; // Import MPIN Page
import 'pots_dashboard_page.dart';

class ClosePotPage extends StatefulWidget {
  final String potId;
  final String potName;
  final double potBalance;
  final String accountLast4;
  final DocumentReference accountRef;

  const ClosePotPage({
    super.key,
    required this.potId,
    required this.potName,
    required this.potBalance,
    required this.accountLast4,
    required this.accountRef,
  });

  @override
  State<ClosePotPage> createState() => _ClosePotPageState();
}

class _ClosePotPageState extends State<ClosePotPage> {
  bool _isClosing = false;

  // --- EXECUTE THE CLOSURE IN FIREBASE ---
  Future<void> _executeClosePot() async {
    // 1. ASK FOR MPIN FIRST
    final bool? isVerified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MpinVerificationPage())
    );

    // If verification failed or back button was pressed, stop here.
    if (isVerified != true) return;

    // 2. PROCEED IF VERIFIED
    setState(() => _isClosing = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final potRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('pots').doc(widget.potId);

      // Move money back if the pot has a balance
      if (widget.potBalance > 0) {
        batch.update(widget.accountRef, {'balance': FieldValue.increment(widget.potBalance)});

        // Record the closing transaction
        final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();
        batch.set(transRef, {
          'type': 'pot_close',
          'amount': widget.potBalance,
          'date': FieldValue.serverTimestamp(),
          'note': 'Closed pot: ${widget.potName}',
          'category': 'Transfer',
          'potId': widget.potId,
          'accountId': widget.accountRef.id,
        });
      }

      // Delete the Pot permanently
      batch.delete(potRef);

      await batch.commit();

      if (!mounted) return;

      // Navigate back to the Dashboard
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PotsDashboardPage()),
            (route) => route.isFirst,
      );
    } catch (e) {
      setState(() => _isClosing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error closing pot: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB), // Light grey background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Close Pot", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            // Icon
            Icon(Icons.savings_rounded, size: 80, color: Colors.blueGrey[700]),
            const SizedBox(height: 16),
            // Pot Name
            Text(
              widget.potName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 30),
            // Title
            const Text(
              "After you close your Pot",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 30),

            // Info Point 1: Balance Transfer
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: Colors.grey, size: 22),
                const SizedBox(width: 16),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black87, fontSize: 15, height: 1.4),
                      children: [
                        TextSpan(text: "₹${widget.potBalance.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: " will be credited to your Savings Account ending with "),
                        TextSpan(text: widget.accountLast4, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const TextSpan(text: "."),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Info Point 2: Deletion Warning
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.grey, size: 22),
                const SizedBox(width: 16),
                const Expanded(
                  child: Text(
                    "Your pot and its goal will be deleted permanently.",
                    style: TextStyle(color: Colors.black87, fontSize: 15, height: 1.4),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Close Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F61), // Salmon red
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                onPressed: _isClosing ? null : _executeClosePot,
                child: _isClosing
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("Close Pot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
              ),
            ),
            const SizedBox(height: 12),

            // Back Button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Back", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}