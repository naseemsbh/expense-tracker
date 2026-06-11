import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class BankAccountScreen extends StatefulWidget {
  const BankAccountScreen({super.key});

  @override
  State<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends State<BankAccountScreen> {
  // Current User
  final User? user = FirebaseAuth.instance.currentUser;

  // Local state to handle "Balance Visibility" toggles
  // Map<DocumentID, bool>
  final Map<String, bool> _visibleBalances = {};

  // --- LOGIC: Set Primary (Updates Firestore) ---
  Future<void> _setAsPrimary(String docId) async {
    if (user == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('accounts');

    // 1. Get all accounts to set isPrimary = false
    var snapshot = await collection.get();
    for (var doc in snapshot.docs) {
      batch.update(doc.reference, {'isPrimary': false});
    }

    // 2. Set the selected one to true
    batch.update(collection.doc(docId), {'isPrimary': true});

    await batch.commit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Primary account updated")),
      );
    }
  }

  // --- LOGIC: Remove Account (Deletes from Firestore) ---
  Future<void> _removeAccount(String docId) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('accounts')
        .doc(docId)
        .delete();

    if (mounted) {
      Navigator.pop(context); // Close Dialog
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account removed")),
      );
    }
  }

  // --- LOGIC: MPIN Dialog ---
  Future<void> _showMpinDialog({
    required Function onSuccess,
    String title = "Enter MPIN",
  }) async {
    final TextEditingController mpinController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: mpinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 10),
                decoration: InputDecoration(
                  hintText: "••••",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: "",
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[800],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    // TODO: Replace "1234" with actual MPIN check from Firestore user data
                    if (mpinController.text == "1234") {
                      Navigator.pop(context);
                      onSuccess();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Wrong MPIN!"), backgroundColor: Colors.red),
                      );
                    }
                  },
                  child: const Text("Confirm", style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Payment Settings"),
        backgroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Your Accounts", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),

            // 1. STATIC "CASH ON HAND" CARD
            // (Since Cash is usually not in the 'bank accounts' list, we keep it separate)
            _buildCashCard(),

            // 2. DYNAMIC FIREBASE LIST
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user!.uid)
                  .collection('accounts')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox(); // Or show "No accounts added"
                }

                var docs = snapshot.data!.docs;

                return Column(
                  children: docs.map((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    return _buildBankCard(doc.id, data);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // --- WIDGET: Static Cash Card ---
  Widget _buildCashCard() {
    bool isVisible = _visibleBalances['cash'] ?? false;
    double cashBalance = 12500.00; // You can fetch this from user doc if you store it there

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 45, height: 45,
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.account_balance_wallet, color: Colors.green),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Cash on Hand", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Liquid Cash", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
              // No menu needed for Cash usually, or minimal
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          GestureDetector(
            onTap: () {
              if (!isVisible) {
                // Cash might not need MPIN, or use same logic
                setState(() => _visibleBalances['cash'] = true);
                Future.delayed(const Duration(seconds: 5), () {
                  if (mounted) setState(() => _visibleBalances['cash'] = false);
                });
              }
            },
            child: Row(
              children: [
                Text(
                  isVisible ? "₹ $cashBalance" : "Check balance",
                  style: TextStyle(
                    color: isVisible ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET: Dynamic Bank Card ---
  Widget _buildBankCard(String docId, Map<String, dynamic> data) {
    String bankName = data['name'] ?? "Bank";
    String accountNumber = data['accountNumber'] ?? "XXXX";
    String last4 = accountNumber.length > 4 ? accountNumber.substring(accountNumber.length - 4) : accountNumber;
    double balance = (data['balance'] ?? 0.0).toDouble();
    bool isPrimary = data['isPrimary'] ?? false;

    // Check local visibility state
    bool isVisible = _visibleBalances[docId] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Bank Icon
              Container(
                width: 45, height: 45,
                decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.account_balance, color: Colors.blue[800]),
              ),
              const SizedBox(width: 15),
              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("Account •••• $last4", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  ],
                ),
              ),
              // Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.grey),
                onSelected: (value) {
                  if (value == 'primary') _setAsPrimary(docId);
                  if (value == 'remove') {
                    _showMpinDialog(
                      title: "Enter MPIN to Remove",
                      onSuccess: () => _removeAccount(docId),
                    );
                  }
                },
                itemBuilder: (context) => [
                  if (!isPrimary)
                    const PopupMenuItem(value: 'primary', child: Text("Set as Primary")),
                  const PopupMenuItem(value: 'remove', child: Text("Remove Account", style: TextStyle(color: Colors.red))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Divider(height: 1),
          const SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Check Balance Button
              GestureDetector(
                onTap: () {
                  if (!isVisible) {
                    _showMpinDialog(
                      title: "Enter MPIN",
                      onSuccess: () {
                        setState(() {
                          _visibleBalances[docId] = true;
                        });
                        Future.delayed(const Duration(seconds: 5), () {
                          if (mounted) setState(() => _visibleBalances[docId] = false);
                        });
                      },
                    );
                  }
                },
                child: Text(
                  isVisible ? "₹ $balance" : "Check balance",
                  style: TextStyle(
                    color: isVisible ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Primary Badge
              if (isPrimary)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                  child: const Text("Primary", style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
            ],
          )
        ],
      ),
    );
  }
}