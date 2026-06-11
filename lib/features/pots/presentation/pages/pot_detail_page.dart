import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_pot_category_page.dart';
import 'pots_dashboard_page.dart';
import 'pot_transfer_page.dart';
import 'pot_history_page.dart';
import 'close_pot_page.dart'; // <--- IMPORT NEW PAGE

class PotDetailPage extends StatefulWidget {
  final String potId;
  final PotCategory category;
  final String potName;
  final double currentBalance;

  const PotDetailPage({
    super.key,
    required this.potId,
    required this.category,
    required this.potName,
    this.currentBalance = 0.0,
  });

  @override
  State<PotDetailPage> createState() => _PotDetailPageState();
}

class _PotDetailPageState extends State<PotDetailPage> {

  void _goBack() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const PotsDashboardPage()),
          (route) => route.isFirst,
    );
  }

  // --- NEW: FETCH ACCOUNT & NAVIGATE TO CONFIRMATION PAGE ---
  Future<void> _navigateToClosePotPage(double currentRealBalance) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Show a loader while fetching the account
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Find Primary Account
      final accountSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .where('isPrimary', isEqualTo: true)
          .limit(1)
          .get();

      // Remove loader
      if (!mounted) return;
      Navigator.pop(context);

      if (accountSnapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No primary account found to credit balance!")));
        return;
      }

      final accountDoc = accountSnapshot.docs.first;
      final accountData = accountDoc.data();

      // Navigate to the Close Pot confirmation page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClosePotPage(
            potId: widget.potId,
            potName: widget.potName,
            potBalance: currentRealBalance,
            accountLast4: accountData['last4Digits'] ?? 'xxxx',
            accountRef: accountDoc.reference,
          ),
        ),
      );

    } catch (e) {
      // Remove loader & show error
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error fetching account: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _goBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF3E5F5),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
            onPressed: _goBack,
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user?.uid)
              .collection('pots')
              .doc(widget.potId)
              .snapshots(),
          builder: (context, snapshot) {
            double realBalance = widget.currentBalance;
            String realName = widget.potName;

            if (snapshot.hasData && snapshot.data!.exists) {
              var data = snapshot.data!.data() as Map<String, dynamic>;
              realBalance = (data['currentAmount'] ?? 0).toDouble();
              realName = data['name'] ?? widget.potName;
            }

            return Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: SizedBox(
                    height: 220,
                    width: 170,
                    child: _DetailSpaceSticker(
                        category: widget.category,
                        customName: realName
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  realName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A)),
                ),
                const SizedBox(height: 40),
                const Text("Currently in the Pot", style: TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Text(
                  "₹${realBalance.toStringAsFixed(0)}",
                  style: const TextStyle(fontSize: 42, fontWeight: FontWeight.w900, color: Colors.black),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6F61),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 4,
                    shadowColor: const Color(0xFFFF6F61).withOpacity(0.4),
                  ),
                  onPressed: () {
                    // TODO: Open Set Goal Dialog
                  },
                  child: const Text("Set a goal", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _showMoreOptionsSheet(context, realBalance),
                  icon: const Icon(Icons.tune_rounded, size: 18, color: Color(0xFF6A1B9A)),
                  label: const Text("More options", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6A1B9A))),
                ),
                const SizedBox(height: 30),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showMoreOptionsSheet(BuildContext context, double currentRealBalance) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16), // Adjusted padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 30),

              // Deposit
              _buildOptionTile(
                icon: Icons.add_circle_rounded,
                color: const Color(0xFF00BFA5),
                title: "Deposit money",
                subtitle: "Add funds from your account",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PotTransferPage(
                            category: widget.category,
                            potId: widget.potId,
                            potName: widget.potName,
                            currentPotBalance: currentRealBalance,
                            goalAmount: 0.0,
                            action: PotAction.deposit,
                          )
                      )
                  );
                },
              ),

              const SizedBox(height: 16),

              // Withdraw
              _buildOptionTile(
                icon: Icons.remove_circle_rounded,
                color: const Color(0xFFFFB74D),
                title: "Withdraw money",
                subtitle: "Move money back to account",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => PotTransferPage(
                            category: widget.category,
                            potId: widget.potId,
                            potName: widget.potName,
                            currentPotBalance: currentRealBalance,
                            goalAmount: 0.0,
                            action: PotAction.withdraw,
                          )
                      )
                  );
                },
              ),

              const SizedBox(height: 16),

              // History
              _buildOptionTile(
                icon: Icons.receipt_long_rounded,
                color: Colors.black87,
                title: "View transaction history",
                subtitle: "All money-in and money-out",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PotHistoryPage(
                        potId: widget.potId,
                        potName: widget.potName,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),

              // --- UPDATED: "INTERESTING" CLOSE POT BUTTON ---
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red, // Text & Icon color
                    side: BorderSide(color: Colors.red.withOpacity(0.5), width: 1.5), // Red border
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.red.withOpacity(0.05), // Slight red tint
                  ),
                  onPressed: () {
                    Navigator.pop(context); // Close sheet
                    _navigateToClosePotPage(currentRealBalance); // Navigate to new page
                  },
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text("Withdraw and close Pot", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // ... (_buildOptionTile and _DetailSpaceSticker remain unchanged)
  Widget _buildOptionTile({required IconData icon, required Color color, required String title, required String subtitle, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class _DetailSpaceSticker extends StatelessWidget {
  final PotCategory category;
  final String? customName;

  const _DetailSpaceSticker({
    required this.category,
    this.customName,
  });

  @override
  Widget build(BuildContext context) {
    String displayText = (customName != null && customName!.isNotEmpty)
        ? customName!
        : category.label;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(90), bottom: Radius.circular(20)),
        border: Border.all(color: const Color(0xFF202020), width: 3),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: category.gradientColors),
        boxShadow: [BoxShadow(color: category.gradientColors.first.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(86), bottom: Radius.circular(16)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(top: 20, left: 20, child: Icon(Icons.star, color: Colors.white24, size: 8)),
            Positioned(top: 50, right: 30, child: Icon(Icons.star, color: Colors.white24, size: 12)),
            Positioned(bottom: 40, left: 40, child: Icon(Icons.star, color: Colors.white24, size: 6)),
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent], begin: Alignment.topRight, end: Alignment.bottomLeft)),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(category.emoji, style: const TextStyle(fontSize: 60)),
            ),

            Positioned(
              bottom: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                constraints: const BoxConstraints(maxWidth: 140),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: category.gradientColors.first, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}