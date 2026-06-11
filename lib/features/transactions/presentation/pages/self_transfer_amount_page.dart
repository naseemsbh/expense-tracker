import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../features/auth/presentation/pages/mpin_verification_page.dart';
import '../widgets/payment_security_widgets.dart'; // For PaymentSuccessPage

class SelfTransferAmountPage extends StatefulWidget {
  final Map<String, dynamic> toAccount; // The account receiving money

  const SelfTransferAmountPage({super.key, required this.toAccount});

  @override
  State<SelfTransferAmountPage> createState() => _SelfTransferAmountPageState();
}

class _SelfTransferAmountPageState extends State<SelfTransferAmountPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  // --- CONFIG ---
  final double _maxLimit = 100000;
  final double _mpinThreshold = 150;

  // --- STATE ---
  List<Map<String, dynamic>> _availableFromAccounts = [];
  String? _selectedFromAccountId; // The ID of the account we are paying FROM
  final Map<String, double> _revealedBalances = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchFromAccounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_amountFocusNode);
    });
  }

  // Fetch accounts but EXCLUDE the "To" account
  Future<void> _fetchFromAccounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .get();

    if (snapshot.docs.isEmpty) return;

    List<Map<String, dynamic>> loadedAccounts = [];

    for (var doc in snapshot.docs) {
      // FILTER: Don't include the account we are sending TO
      if (doc.id == widget.toAccount['id']) continue;

      var data = doc.data();
      loadedAccounts.add({
        'id': doc.id,
        'name': data['name'] ?? 'Account',
        'realBalance': (data['balance'] ?? 0).toDouble(),
      });
    }

    // Sort alphabetically
    loadedAccounts.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if (mounted) {
      setState(() {
        _availableFromAccounts = loadedAccounts;
        // Default to first available
        if (_availableFromAccounts.isNotEmpty) {
          _selectedFromAccountId = _availableFromAccounts[0]['id'];
        }
      });
    }
  }

  // --- 1. COMPACT SHEET (The "Choose Account" Sheet) ---
  void _onArrowPressed() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    // Safety: ensure a valid selection exists
    if (_selectedFromAccountId == null && _availableFromAccounts.isNotEmpty) {
      setState(() => _selectedFromAccountId = _availableFromAccounts[0]['id']);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414), // Pure Dark
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Get selected account object
          var selectedAccount = _availableFromAccounts.firstWhere(
                  (a) => a['id'] == _selectedFromAccountId,
              orElse: () => _availableFromAccounts.isNotEmpty ? _availableFromAccounts[0] : {'name': 'No Account', 'realBalance': 0.0}
          );

          if (_availableFromAccounts.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text("No other accounts available to transfer from.", style: TextStyle(color: Colors.white)),
            );
          }

          bool isBalanceRevealed = _revealedBalances.containsKey(selectedAccount['id']);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),

                const Text("Transfer from", style: TextStyle(color: Colors.grey, fontSize: 14)), // "Transfer from" instead of "Pay using"
                const SizedBox(height: 16),

                // --- ACCOUNT CARD ---
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _showAllAccountsSheet(amount);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF252525),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                        const SizedBox(width: 12),
                        Text(
                            selectedAccount['name'],
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey, size: 18),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Check Balance
                isBalanceRevealed
                    ? Text("₹${_revealedBalances[selectedAccount['id']]}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                    : GestureDetector(
                  onTap: () => _checkBalance(selectedAccount['id'], selectedAccount['realBalance'], setSheetState),
                  child: const Text("Check balance", style: TextStyle(color: Color(0xFF669DF6), fontSize: 13, fontWeight: FontWeight.w500)),
                ),

                const SizedBox(height: 32),

                // PAY BUTTON
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    onPressed: () => _validateAndProcess(amount),
                    child: Text("Transfer ₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.verified_user_outlined, color: Colors.grey, size: 12),
                    SizedBox(width: 4),
                    Text("Secure Transfer", style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- 2. SWITCH ACCOUNT SHEET ---
  void _showAllAccountsSheet(double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 24),
                const Text("Select Account", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                ..._availableFromAccounts.map((account) {
                  bool isSelected = account['id'] == _selectedFromAccountId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedFromAccountId = account['id']);
                      Navigator.pop(context); // Close list
                      _onArrowPressed(); // Re-open compact sheet
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF333333) : const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected ? Border.all(color: Colors.white24) : null,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                            child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(account['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                const SizedBox(height: 2),
                                Text("Available", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.white, size: 24),
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

  // --- LOGIC METHODS ---
  void _checkBalance(String accountId, double realBalance, StateSetter setSheetState) async {
    final bool? isVerified = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MpinVerificationPage()));
    if (isVerified == true) setSheetState(() => _revealedBalances[accountId] = realBalance);
  }

  void _validateAndProcess(double amount) {
    var account = _availableFromAccounts.firstWhere((a) => a['id'] == _selectedFromAccountId);
    double availableBalance = account['realBalance'];
    Navigator.pop(context); // Close Sheet

    if (availableBalance < amount) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient Balance"), backgroundColor: Colors.red));
      return;
    }

    // Always ask MPIN for transfers (safer)
    _askMpinAndProcess(amount);
  }

  void _askMpinAndProcess(double amount) async {
    final bool? isVerified = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MpinVerificationPage()));
    if (isVerified == true) _processTransfer(amount);
  }

  Future<void> _processTransfer(double amount) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || _selectedFromAccountId == null) return;

      String fromId = _selectedFromAccountId!;
      String toId = widget.toAccount['id'];
      String note = _noteController.text.trim();
      if (note.isEmpty) note = "Self Transfer";

      var fromAccount = _availableFromAccounts.firstWhere((a) => a['id'] == fromId);

      // BATCH WRITE
      final batch = FirebaseFirestore.instance.batch();

      final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();
      batch.set(transRef, {
        'amount': amount,
        'type': 'self_transfer',
        'category': 'Transfer', // Icons logic uses this
        'note': note,
        'fromAccountId': fromId,
        'toAccountId': toId,
        'fromAccountName': fromAccount['name'],
        'toAccountName': widget.toAccount['name'],
        'date': FieldValue.serverTimestamp(),
      });

      final fromRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(fromId);
      batch.update(fromRef, { 'balance': FieldValue.increment(-amount) });

      final toRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(toId);
      batch.update(toRef, { 'balance': FieldValue.increment(amount) });

      await batch.commit();

      if (!mounted) return;

      // Success Page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => PaymentSuccessPage(amount: amount, name: "Self Transfer")),
      );

    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    double currentVal = double.tryParse(_amountController.text) ?? 0;
    bool isOverLimit = currentVal > _maxLimit;

    return Scaffold(
      backgroundColor: const Color(0xFF181B26),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white), // Close icon instead of back for modal feel
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              const SizedBox(height: 40),

              // 1. CENTER ICON & TITLE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF222530),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                "Self Transfer",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                "To: ${widget.toAccount['name']}",
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),

              const SizedBox(height: 40),

              // 2. AMOUNT INPUT
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text("₹", style: TextStyle(color: isOverLimit ? Colors.redAccent : Colors.white, fontSize: 40, fontWeight: FontWeight.w300)),
                  const SizedBox(width: 4),
                  IntrinsicWidth(
                    child: TextField(
                      controller: _amountController,
                      focusNode: _amountFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      cursorColor: Colors.white,
                      style: TextStyle(
                        color: isOverLimit ? Colors.redAccent : Colors.white,
                        fontSize: 64,
                        fontWeight: FontWeight.bold,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          // Block starting with 0 or .
                          if(newValue.text.startsWith('.') || newValue.text.startsWith('0')) return oldValue;
                          return newValue;
                        }),
                      ],
                      decoration: const InputDecoration(border: InputBorder.none, hintText: "0", hintStyle: TextStyle(color: Colors.white24)),
                      onChanged: (val) => setState(() {}),
                    ),
                  ),
                ],
              ),
              if (isOverLimit) const Text("Max limit is ₹1,00,000", style: TextStyle(color: Colors.redAccent, fontSize: 12)),

              const SizedBox(height: 30),

              // 3. NOTE INPUT (Centered Pill)
              Container(
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF222530),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _noteController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Add a note",
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),

          // 4. FAB ARROW (Bottom Right)
          Positioned(
            right: 20, bottom: 20,
            child: SizedBox(
              width: 64, height: 64,
              child: FloatingActionButton(
                onPressed: (currentVal > 0 && !isOverLimit) ? _onArrowPressed : null,
                backgroundColor: (currentVal > 0 && !isOverLimit) ? Colors.white : const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
                child: _isLoading
                    ? const Padding(padding: EdgeInsets.all(18), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3))
                    : const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 30),
              ),
            ),
          ),
        ],
      ),
    );
  }
}