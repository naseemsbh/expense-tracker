import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PotHistoryPage extends StatelessWidget {
  final String potId;
  final String potName;

  const PotHistoryPage({
    super.key,
    required this.potId,
    required this.potName,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Column(
          children: [
            const Text("History", style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(potName, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('transactions')
            .where('potId', isEqualTo: potId)
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  "Need Index!\n\nCheck your Debug Console for the creation link.\nError: ${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history_toggle_off_rounded, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No transactions yet", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          var docs = snapshot.data!.docs;

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              var data = docs[index].data() as Map<String, dynamic>;
              return _HistoryTile(data: data);
            },
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    // 1. Parse Data
    String type = data['type'] ?? '';
    bool isDeposit = type == 'pot_deposit'; // "Credit" to Pot
    double amount = (data['amount'] ?? 0).toDouble();
    Timestamp? ts = data['date'];
    DateTime date = ts != null ? ts.toDate() : DateTime.now();

    // 2. Formatting
    String dateStr = DateFormat('MMM d, h:mm a').format(date);
    Color color = isDeposit ? const Color(0xFF00C853) : Colors.black;
    Color iconBg = isDeposit ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5);
    String sign = isDeposit ? "+" : "-";

    // 3. Icon Logic (Updated)
    IconData icon;
    if (isDeposit) {
      icon = Icons.savings_rounded; // Credit: Pot Icon
    } else {
      icon = Icons.downloading_rounded; // Debit: Downloading Icon
    }

    // Special Case: Closing Pot
    if (type == 'pot_close') {
      icon = Icons.delete_outline_rounded;
      iconBg = const Color(0xFFFFEBEE);
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isDeposit ? "Added to Pot" : (type == 'pot_close' ? "Pot Closed" : "Withdrawn"),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(dateStr, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Text(
            "$sign₹${amount.toStringAsFixed(0)}",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}