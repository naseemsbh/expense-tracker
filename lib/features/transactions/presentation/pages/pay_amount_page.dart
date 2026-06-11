import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../widgets/payment_security_widgets.dart';
import 'package:expense_tracker/features/auth/presentation/pages/mpin_verification_page.dart';

class PayAmountPage extends StatefulWidget {
  final Contact contact;

  const PayAmountPage({super.key, required this.contact});

  @override
  State<PayAmountPage> createState() => _PayAmountPageState();
}

class _PayAmountPageState extends State<PayAmountPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  bool _isLoading = false;
  List<Map<String, dynamic>> _myAccounts = [];
  String? _selectedAccountId;
  final Map<String, double> _revealedBalances = {};

  final double _maxLimit = 100000;

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_amountFocusNode);
    });
  }

  Future<void> _fetchAccounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .get();

    setState(() {
      _myAccounts = snapshot.docs.map((doc) {
        var data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Account',
          'number': data['accountNumber'] ?? '****',
          'realBalance': (data['balance'] ?? 0).toDouble(),
        };
      }).toList();

      // FIXED: Automatically select the first (Primary) account
      if (_myAccounts.isNotEmpty) {
        _selectedAccountId = _myAccounts[0]['id'];
      }
    });
  }

  // --- 1. COMPACT SHEET (Fixed Check Balance) ---
  void _onArrowPressed() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Ensure we have a valid selection, or default to first
          var selectedAccount = _myAccounts.firstWhere(
                  (a) => a['id'] == _selectedAccountId,
              orElse: () => _myAccounts.isNotEmpty ? _myAccounts[0] : {'name': 'No Account'}
          );

          if (_myAccounts.isEmpty) return const SizedBox(); // Safety check

          bool isBalanceRevealed = _revealedBalances.containsKey(selectedAccount['id']);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, color: Colors.grey[700])),
                const SizedBox(height: 20),
                const Text("Choose account to pay with", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // --- ACCOUNT CARD ---
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2C),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      // 1. BANK ICON (Clicking triggers Expand)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showAllAccountsSheet(amount);
                        },
                        child: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.account_balance, color: Colors.black),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 2. TEXT AREA
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Name (Clicking triggers Expand)
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _showAllAccountsSheet(amount);
                              },
                              child: Text(selectedAccount['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 4),

                            // FIXED: CHECK BALANCE BUTTON (Separate Click Area)
                            isBalanceRevealed
                                ? Text("₹${_revealedBalances[selectedAccount['id']]}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                                : GestureDetector(
                              onTap: () => _checkBalance(selectedAccount['id'], selectedAccount['realBalance'], setSheetState),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                color: Colors.transparent, // Hit test area
                                child: const Text("Check balance", style: TextStyle(color: Color(0xFF669DF6), fontSize: 13, fontWeight: FontWeight.w500)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. ARROW (Clicking triggers Expand)
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                          _showAllAccountsSheet(amount);
                        },
                        child: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // PAY BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF669DF6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    ),
                    onPressed: () => _validateAndPay(amount),
                    child: Text("Pay ₹$amount", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black)),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text("Powered by ", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    Text("UPI", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 2. FULL LIST SHEET ---
  void _showAllAccountsSheet(double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1F1F1F),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, color: Colors.grey[700])),
                const SizedBox(height: 20),
                const Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Select Bank Account", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))
                ),
                const SizedBox(height: 20),
                ..._myAccounts.map((account) {
                  bool isSelected = account['id'] == _selectedAccountId;
                  return InkWell(
                    onTap: () {
                      setState(() => _selectedAccountId = account['id']);
                      Navigator.pop(context); // Close list
                      _onArrowPressed(); // Re-open compact view with new selection
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF2C2C2C) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: isSelected ? Border.all(color: const Color(0xFF669DF6)) : Border.all(color: Colors.grey.shade800),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                            child: const Icon(Icons.account_balance, color: Colors.black),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text("Savings Account", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle, color: Color(0xFF669DF6)),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 3. CHECK BALANCE LOGIC ---
  void _checkBalance(String accountId, double realBalance, StateSetter setSheetState) async {
    // Navigate to Full Screen MPIN Page
    final bool? isVerified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MpinVerificationPage()),
    );

    // If success, reveal balance
    if (isVerified == true) {
      setSheetState(() {
        _revealedBalances[accountId] = realBalance;
      });
    }
  }

  // --- 4. VALIDATE & PAY ---
  void _validateAndPay(double amount) {
    var account = _myAccounts.firstWhere((a) => a['id'] == _selectedAccountId);
    double availableBalance = account['realBalance'];

    Navigator.pop(context); // Close Sheet

    if (availableBalance < amount) {
      _showInsufficientBalanceError();
    } else {
      _askMpinAndProcess(amount);
    }
  }

  // --- 5. INSUFFICIENT BALANCE UI ---
  void _showInsufficientBalanceError() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                child: const Icon(Icons.priority_high, color: Colors.red, size: 30),
              ),
              const SizedBox(height: 16),
              const Text("Insufficient Balance", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
              const SizedBox(height: 8),
              const Text("Payment failed due to not enough balance. No money deducted.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC6F68D), foregroundColor: Colors.black, elevation: 0),
                  onPressed: () {
                    Navigator.pop(context);
                    double amount = double.tryParse(_amountController.text) ?? 0;
                    _showAllAccountsSheet(amount);
                  },
                  child: const Text("Change payment method"),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.black, side: BorderSide(color: Colors.grey.shade300)),
                  onPressed: () {
                    Navigator.pop(context);
                    FocusScope.of(context).requestFocus(_amountFocusNode);
                  },
                  child: const Text("Retry with less amount"),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 6. MPIN & SUCCESS ---
  void _askMpinAndProcess(double amount) async {
    final bool? isVerified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MpinVerificationPage()),
    );

    if (isVerified == true) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentSuccessPage(amount: amount, name: widget.contact.displayName),
        ),
      ).then((result) {
        if (result == true) {
          _processPaymentBackground(amount);
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Cancelled"), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _processPaymentBackground(double amount) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String contactName = widget.contact.displayName;
      String contactNumber = widget.contact.phones.isNotEmpty
          ? widget.contact.phones.first.number.replaceAll(RegExp(r'\D'), '')
          : "";
      if (contactNumber.length > 10) contactNumber = contactNumber.substring(contactNumber.length - 10);

      String noteText = _noteController.text.trim();
      String finalNote = "Paid to $contactName";
      if (noteText.isNotEmpty) finalNote += ": $noteText";

      final batch = FirebaseFirestore.instance.batch();
      final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();
      Map<String, dynamic> transData = {
        'amount': amount,
        'type': 'expense',
        'accountId': _selectedAccountId,
        'category': 'Transfer',
        'note': finalNote,
        'date': FieldValue.serverTimestamp(),
      };
      if (contactNumber.isNotEmpty) {
        transData['relatedContactName'] = contactName;
        transData['relatedContactNumber'] = contactNumber;
      }
      batch.set(transRef, transData);
      final accountRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(_selectedAccountId);
      batch.update(accountRef, { 'balance': FieldValue.increment(-amount) });
      await batch.commit();
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    String name = widget.contact.displayName;
    String initial = name.isNotEmpty ? name[0].toUpperCase() : "?";
    String phone = widget.contact.phones.isNotEmpty ? widget.contact.phones.first.number : "";

    // --- VALIDATION LOGIC ---
    double currentVal = double.tryParse(_amountController.text) ?? 0;
    bool isOverLimit = currentVal > _maxLimit;

    return Scaffold(
      backgroundColor: const Color(0xFF181B26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.purpleAccent,
                child: Text(initial, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
              const SizedBox(height: 16),
              Text("Paying $name", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(phone, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 60),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  const Text("₹", style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w400)),
                  const SizedBox(width: 8),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      cursorColor: Colors.white,
                      style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w500),
                      inputFormatters: [
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          String newText = newValue.text;
                          if (newText.isEmpty) return newValue;
                          if (!RegExp(r'^[0-9.]*$').hasMatch(newText)) return oldValue;
                          if (newText.indexOf('.') != newText.lastIndexOf('.')) return oldValue;
                          if (newText.startsWith('.') || newText.startsWith('0')) return oldValue;
                          double? val = double.tryParse(newText);
                          if (val != null && val > _maxLimit) return oldValue;
                          return newValue;
                        }),
                      ],
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "0", hintStyle: TextStyle(color: Colors.white38)),
                      onChanged: (val) {
                        setState(() {});
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              Container(
                width: 140,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF2A2E3B), borderRadius: BorderRadius.circular(20)),
                child: TextField(
                  controller: _noteController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  cursorColor: Colors.white,
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, hintText: "Add note", hintStyle: TextStyle(color: Colors.white54, fontSize: 14), contentPadding: EdgeInsets.zero),
                ),
              ),
            ],
          ),

          Positioned(
            right: 20, bottom: 20,
            child: SizedBox(
              width: 65, height: 65,
              child: FloatingActionButton(
                onPressed: (_amountController.text.isNotEmpty && (double.tryParse(_amountController.text) ?? 0) > 0) ? _onArrowPressed : null,
                backgroundColor: (_amountController.text.isNotEmpty && (double.tryParse(_amountController.text) ?? 0) > 0) ? Colors.white : Colors.grey[600],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.black))
                    : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.black, size: 28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}