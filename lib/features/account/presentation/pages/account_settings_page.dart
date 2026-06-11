import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/features/auth/presentation/pages/mpin_verification_page.dart';

class AccountSettingsPage extends StatefulWidget {
  final String docId;
  final String bankName;
  final String last4Digits;

  const AccountSettingsPage({
    super.key,
    required this.docId,
    required this.bankName,
    required this.last4Digits,
  });

  @override
  State<AccountSettingsPage> createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final User? user = FirebaseAuth.instance.currentUser;

  // --- LOGIC: Set Primary ---
  Future<void> _setAsPrimary() async {
    if (user == null) return;
    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('accounts');

    // 1. Set all others to false
    var snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isPrimary': false});
    }
    // 2. Set current to true
    batch.update(collection.doc(widget.docId), {'isPrimary': true});

    await batch.commit();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Primary account updated")));
  }

  // --- LOGIC: Smart Remove Account ---
  Future<void> _removeAccount(bool isCurrentPrimary) async {
    if (user == null) return;

    // 1. Verify MPIN First
    final bool? isVerified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MpinVerificationPage()),
    );

    if (isVerified == true) {
      final accountsRef = FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('accounts');

      // 2. Delete the specific account
      await accountsRef.doc(widget.docId).delete();

      // 3. SMART AUTO-ASSIGN LOGIC
      // If the deleted account was Primary, we must find a new Primary
      if (isCurrentPrimary) {
        final snapshot = await accountsRef.get();

        // --- CRITICAL FIX START ---
        // Filter: We only want real Banks (Not Cash) to become Primary
        final remainingBanks = snapshot.docs.where((doc) {
          final data = doc.data();
          String type = data['type'] ?? 'Bank';
          return type != 'Cash' && data['name'] != 'Cash on Hand';
        }).toList();
        // --- CRITICAL FIX END ---

        if (remainingBanks.isNotEmpty) {
          // Make the first available BANK the new Primary
          await accountsRef.doc(remainingBanks.first.id).update({'isPrimary': true});
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Primary account reassigned automatically")));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account removed. No banks left.")));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account removed")));
      }

      // 4. Close the settings page
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to real-time updates to know if 'isPrimary' changes
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user!.uid)
          .collection('accounts')
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        // Handle case where doc is deleted while page is open
        if (!snapshot.data!.exists) {
          return const SizedBox();
        }

        var data = snapshot.data!.data() as Map<String, dynamic>;
        bool isPrimary = data['isPrimary'] ?? false;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.black),
              onPressed: () => Navigator.pop(context),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Account settings", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
                Text("${widget.bankName} ${widget.last4Digits} • Savings account", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.normal)),
              ],
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              children: [
                // 1. PRIMARY ACCOUNT OPTION
                _buildOptionTile(
                  icon: Icons.credit_card,
                  title: "Primary account",
                  subtitle: "For receiving money",
                  trailing: isPrimary
                      ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(6)),
                    child: Text("Primary", style: TextStyle(color: Colors.green[800], fontWeight: FontWeight.bold, fontSize: 12)),
                  )
                      : TextButton(
                    onPressed: _setAsPrimary,
                    child: const Text("Set as primary", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),

                // 2. REMOVE ACCOUNT OPTION
                _buildOptionTile(
                  icon: Icons.delete_outline,
                  title: "Remove account",
                  subtitle: null,
                  isDestructive: true,
                  onTap: () => _removeAccount(isPrimary), // Pass current status here
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isDestructive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade200),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.black87, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDestructive ? Colors.black : Colors.black87)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}