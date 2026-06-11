import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'pay_amount_page.dart';
class ContactHistoryPage extends StatefulWidget {
  final Contact contact;

  const ContactHistoryPage({super.key, required this.contact});

  @override
  State<ContactHistoryPage> createState() => _ContactHistoryPageState();
}

class _ContactHistoryPageState extends State<ContactHistoryPage> {
  late String _cleanContactNumber;

  @override
  void initState() {
    super.initState();
    // Prepare the number for database querying
    if (widget.contact.phones.isNotEmpty) {
      _cleanContactNumber = _cleanPhoneNumberForDB(widget.contact.phones.first.number);
    } else {
      _cleanContactNumber = "";
    }
  }

  // Same helper to ensure we match what was saved
  String _cleanPhoneNumberForDB(String raw) {
    String clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 12 && clean.startsWith('91')) {
      clean = clean.substring(2);
    } else if (clean.length == 11 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    String name = widget.contact.displayName;
    String phone = widget.contact.phones.isNotEmpty ? widget.contact.phones.first.number : "";
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.purpleAccent,
              child: Text(
                  initial,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16, color: Colors.white)),
                Text(phone, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- 1. CHAT AREA ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .collection('transactions')
                  .where('relatedContactNumber', isEqualTo: _cleanContactNumber) // <--- THE FILTER
                  .orderBy('date', descending: true) // Newest first (for reverse list)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                var docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 60, color: Colors.grey[800]),
                        const SizedBox(height: 16),
                        const Text("No payment history", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  reverse: true, // Scroll from bottom like a chat
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    var data = docs[index].data() as Map<String, dynamic>;
                    return _buildTransactionBubble(data);
                  },
                );
              },
            ),
          ),

          // --- 2. FOOTER ---
          Container(
            padding: const EdgeInsets.all(16),
            color: const Color(0xFF1F1F1F),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF669DF6),
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  elevation: 0,
                ),
                onPressed: () {
                  // Navigate to Payment Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PayAmountPage(contact: widget.contact),
                    ),
                  );
                },
                child: const Text("Pay", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionBubble(Map<String, dynamic> data) {
    bool isIncome = data['type'] == 'income';
    // Logic:
    // Income = "Received from X" -> Left Side (White)
    // Expense = "Paid to X" -> Right Side (Dark)

    double amount = (data['amount'] ?? 0).toDouble();
    String note = data['note'] ?? "Payment";

    // Clean up note for display (optional: remove the "Received from X" prefix to save space)
    if (note.contains(":")) {
      note = note.split(":")[1].trim(); // Show only "Dinner Bill" part
    } else if (note.startsWith("Received from")) {
      note = "Money Received";
    }

    // Format Date
    String dateString = "Just now";
    if (data['date'] != null) {
      DateTime date = (data['date'] as Timestamp).toDate();
      dateString = "${date.day}/${date.month} • ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'pm' : 'am'}";
    }

    return Align(
      alignment: isIncome ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isIncome ? const Color(0xFF2C2C2C) : const Color(0xFF004D40), // Dark Grey vs Dark Teal
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: isIncome ? const Radius.circular(4) : const Radius.circular(20),
            bottomRight: isIncome ? const Radius.circular(20) : const Radius.circular(4),
          ),
          border: isIncome ? Border.all(color: Colors.grey.shade800) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isIncome ? "Payment from ${widget.contact.displayName.split(' ')[0]}" : "You paid",
                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 4),
            Text(note, style: const TextStyle(color: Colors.white, fontSize: 14)),
            const SizedBox(height: 12),
            Text("₹${amount.toStringAsFixed(0)}", style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w400)),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle, size: 14, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Text(dateString, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                const Spacer(),
                const Icon(Icons.chevron_right, size: 16, color: Colors.white30)
              ],
            )
          ],
        ),
      ),
    );
  }
}