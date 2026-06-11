import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'self_transfer_amount_page.dart';

class SelfTransferPage extends StatelessWidget {
  const SelfTransferPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF181B26), // Dark Theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Self Transfer",
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),

      // --- NEW BUTTON LOCATION (Bottom Right) ---
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 10, right: 10),
        child: SizedBox(
          height: 56,
          width: 160, // Fixed width for pill shape
          child: FloatingActionButton.extended(
            onPressed: () => _showTransferToSheet(context),
            backgroundColor: const Color(0xFF8AB4F8), // GPay-style Light Blue
            foregroundColor: const Color(0xFF000000), // Black Text
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            label: const Text(
              "Self transfer",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // --- HISTORY LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('transactions')
                  .where('type', isEqualTo: 'self_transfer')
              // .orderBy('date', descending: true) // Uncomment after creating composite index
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.white));
                }
                var docs = snapshot.data!.docs;

                // --- EMPTY STATE ---
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: const BoxDecoration(
                            color: Color(0xFF222530),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.swap_horiz_rounded, size: 48, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "No self transfers yet",
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Transfers between your accounts\nwill appear here.",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[500], fontSize: 14),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 80), // Extra bottom padding for FAB
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return _buildHistoryCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- HISTORY CARD (Cleaned up: No Repeat Button) ---
  Widget _buildHistoryCard(Map<String, dynamic> data) {
    double amount = (data['amount'] ?? 0).toDouble();
    String fromName = data['fromAccountName'] ?? "Account";
    String toName = data['toAccountName'] ?? "Account";
    String fromDigits = data['fromAccountDigits'] ?? "";
    String toDigits = data['toAccountDigits'] ?? "";

    // Date Logic
    Timestamp? ts = data['date'];
    String dateStr = "Recent";
    if (ts != null) {
      dateStr = DateFormat('d MMM, h:mm a').format(ts.toDate());
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF222530),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Payment to own account", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
              Text(dateStr, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          const SizedBox(height: 12),

          // Amount
          Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),

          // Flow Visualization
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF2C303E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // From
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Debited from", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("$fromName $fromDigits", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),

                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.arrow_forward, color: Colors.grey[600], size: 18),
                ),

                // To
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text("Credited to", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                      const SizedBox(height: 4),
                      Text("$toName $toDigits", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // "Repeat" button removed as requested
        ],
      ),
    );
  }

  // --- STEP 1: SELECT "TRANSFER TO" SHEET ---
  void _showTransferToSheet(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
                var docs = snapshot.data!.docs;

                String? selectedId;
                Map<String, dynamic>? selectedData;

                return StatefulBuilder(
                    builder: (context, setState) {
                      return Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
                            const SizedBox(height: 24),

                            const Text("Transfer money to", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                            const SizedBox(height: 24),

                            Expanded(
                              child: ListView.separated(
                                controller: scrollController,
                                itemCount: docs.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 12),
                                itemBuilder: (context, index) {
                                  var data = docs[index].data() as Map<String, dynamic>;
                                  String id = docs[index].id;
                                  bool isSelected = selectedId == id;

                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      selectedId = id;
                                      selectedData = data;
                                      selectedData!['id'] = id;
                                    }),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF333333) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: isSelected ? Border.all(color: const Color(0xFF669DF6)) : Border.all(color: Colors.grey.shade800),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                                            child: Icon(data['type'] == 'Cash' ? Icons.wallet : Icons.account_balance, color: Colors.white, size: 20),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(data['name'] ?? "Account", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                                Text("${data['type'] ?? 'Bank'} account", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                                              ],
                                            ),
                                          ),
                                          if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF669DF6), size: 24),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            const SizedBox(height: 16),

                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF669DF6),
                                  foregroundColor: Colors.black,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                                onPressed: selectedId == null ? null : () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => SelfTransferAmountPage(toAccount: selectedData!))
                                  );
                                },
                                child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                );
              },
            );
          },
        );
      },
    );
  }
}