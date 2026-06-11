import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../features/auth/presentation/pages/mpin_verification_page.dart';
import '../../../../features/transactions/presentation/widgets/payment_security_widgets.dart';
import 'create_pot_category_page.dart';

// Enum to define if we are Adding or Removing money
enum PotAction { deposit, withdraw }

class PotTransferPage extends StatefulWidget {
  final PotCategory category;
  final String potId;
  final String potName;
  final double currentPotBalance;
  final double goalAmount;
  final PotAction action;

  const PotTransferPage({
    super.key,
    required this.category,
    required this.potId,
    required this.potName,
    required this.currentPotBalance,
    required this.goalAmount,
    required this.action,
  });

  @override
  State<PotTransferPage> createState() => _PotTransferPageState();
}

class _PotTransferPageState extends State<PotTransferPage> {
  final TextEditingController _amountController = TextEditingController();

  // State for the selected "From" or "To" account
  Map<String, dynamic>? _selectedAccount;
  String? _selectedAccountId;
  bool _isLoadingAccount = true;

  @override
  void initState() {
    super.initState();
    _fetchPrimaryAccount();
  }

  // --- 1. FETCH DEFAULT (PRIMARY) ACCOUNT ---
  Future<void> _fetchPrimaryAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('accounts')
          .where('isPrimary', isEqualTo: true)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty && mounted) {
        setState(() {
          _selectedAccount = snapshot.docs.first.data();
          _selectedAccountId = snapshot.docs.first.id;
          _isLoadingAccount = false;
        });
      } else {
        _fetchAnyBankAccount();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingAccount = false);
    }
  }

  Future<void> _fetchAnyBankAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .where('type', isNotEqualTo: 'Cash')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty && mounted) {
      setState(() {
        _selectedAccount = snapshot.docs.first.data();
        _selectedAccountId = snapshot.docs.first.id;
        _isLoadingAccount = false;
      });
    } else {
      if(mounted) setState(() => _isLoadingAccount = false);
    }
  }

  // --- 2. SLIDE LOGIC ---
  void _onSlideCompleted() async {
    double amount = double.tryParse(_amountController.text) ?? 0;

    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter a valid amount")));
      return;
    }
    if (_selectedAccount == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a valid bank account")));
      return;
    }

    // Balance Check
    double accountBalance = (_selectedAccount!['balance'] ?? 0).toDouble();
    if (widget.action == PotAction.deposit) {
      if (accountBalance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient bank balance!"), backgroundColor: Colors.red));
        return;
      }
    } else {
      if (widget.currentPotBalance < amount) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Insufficient pot balance!"), backgroundColor: Colors.red));
        return;
      }
    }

    _verifyAndExecute(amount);
  }

  // --- 3. MPIN & EXECUTE ---
  Future<void> _verifyAndExecute(double amount) async {
    final bool? isVerified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MpinVerificationPage())
    );

    if (isVerified != true) return;
    _executeTransaction(amount);
  }

  Future<void> _executeTransaction(double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();

      final potRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('pots').doc(widget.potId);
      final accountRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(_selectedAccountId);
      final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();

      if (widget.action == PotAction.deposit) {
        // DEPOSIT
        batch.update(accountRef, {'balance': FieldValue.increment(-amount)});
        batch.update(potRef, {'currentAmount': FieldValue.increment(amount)});

        batch.set(transRef, {
          'type': 'pot_deposit',
          'amount': amount,
          'date': FieldValue.serverTimestamp(),
          'note': 'Saved to ${widget.potName}',
          'potId': widget.potId,
          'accountId': _selectedAccountId,
          'category': 'Savings'
        });
      } else {
        // WITHDRAW
        batch.update(potRef, {'currentAmount': FieldValue.increment(-amount)});
        batch.update(accountRef, {'balance': FieldValue.increment(amount)});

        batch.set(transRef, {
          'type': 'pot_withdraw',
          'amount': amount,
          'date': FieldValue.serverTimestamp(),
          'note': 'Withdrawn from ${widget.potName}',
          'potId': widget.potId,
          'accountId': _selectedAccountId,
          'category': 'Transfer'
        });
      }

      await batch.commit();

      if (!mounted) return;

      Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => PaymentSuccessPage(
              amount: amount,
              name: widget.action == PotAction.deposit ? "Saved to Pot" : "Withdrawn to Bank"
          ))
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }

  void _showAccountPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => _AccountSelectionList(
        onSelect: (id, data) {
          setState(() {
            _selectedAccountId = id;
            _selectedAccount = data;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDeposit = widget.action == PotAction.deposit;
    String accountLabel = isDeposit ? "FROM ACCOUNT" : "TO ACCOUNT";
    String sliderLabel = isDeposit ? "Slide to Deposit" : "Slide to Withdraw";
    String pageTitle = isDeposit ? "Adding Money" : "Withdrawing Money";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(pageTitle, style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      // CHANGE 1: Use Column + Expanded to pin button to bottom
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 10),

                    // --- HERO STICKER ---
                    SizedBox(
                      height: 180,
                      width: 140,
                      child: _TransferSpaceSticker(category: widget.category),
                    ),

                    const SizedBox(height: 20),

                    // Pot Name
                    Text(
                      widget.potName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Helper Text
                    Text(
                      isDeposit
                          ? "Current Balance: ₹${widget.currentPotBalance.toStringAsFixed(0)}"
                          : "Available to Withdraw: ₹${widget.currentPotBalance.toStringAsFixed(0)}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),

                    const SizedBox(height: 40),

                    // --- AMOUNT INPUT ---
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text("ENTER AMOUNT", style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          const Text("₹", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: _amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  hintText: "0",
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // --- ACCOUNT SELECTOR ---
                    Align(
                        alignment: Alignment.centerLeft,
                        child: Text(accountLabel, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1))
                    ),
                    const SizedBox(height: 10),

                    GestureDetector(
                      onTap: _showAccountPicker,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.account_balance, color: Colors.redAccent, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (_isLoadingAccount)
                                    const Text("Loading...", style: TextStyle(fontWeight: FontWeight.bold))
                                  else
                                    Text(_selectedAccount?['name'] ?? "Select Account", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),

                                  if (_selectedAccount != null)
                                    Text("• ${_selectedAccount?['last4Digits'] ?? 'xxxx'}", style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // --- SLIDER BUTTON (PINNED TO BOTTOM) ---
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 30),
            child: _DarkSlideButton(
              label: sliderLabel,
              isEnabled: _amountController.text.isNotEmpty && _selectedAccount != null,
              onSlideComplete: _onSlideCompleted,
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER: STICKER ---
class _TransferSpaceSticker extends StatelessWidget {
  final PotCategory category;
  const _TransferSpaceSticker({required this.category});

  @override
  Widget build(BuildContext context) {
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
            Positioned(
              top: -40, right: -40,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent], begin: Alignment.topRight, end: Alignment.bottomLeft)
                ),
              ),
            ),
            Text(category.emoji, style: const TextStyle(fontSize: 50)), // Slightly smaller emoji
            Positioned(
              bottom: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                child: Text(category.label, style: TextStyle(color: category.gradientColors.first, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- SLIDER BUTTON (WITH AUTO RESET) ---
class _DarkSlideButton extends StatefulWidget {
  final String label;
  final bool isEnabled;
  final VoidCallback onSlideComplete;

  const _DarkSlideButton({required this.label, required this.isEnabled, required this.onSlideComplete});

  @override
  State<_DarkSlideButton> createState() => _DarkSlideButtonState();
}

class _DarkSlideButtonState extends State<_DarkSlideButton> {
  double _dragValue = 0.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, constraints) {
          double width = constraints.maxWidth;
          double maxDrag = width - 60;

          return Opacity(
            opacity: widget.isEnabled ? 1.0 : 0.6,
            child: Container(
              height: 60,
              width: width,
              decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      widget.label,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  Positioned(
                    left: _dragValue,
                    top: 5,
                    bottom: 5,
                    child: GestureDetector(
                      onHorizontalDragUpdate: (details) {
                        if (!widget.isEnabled) return;
                        setState(() {
                          _dragValue += details.delta.dx;
                          _dragValue = _dragValue.clamp(0.0, maxDrag);
                        });
                      },
                      onHorizontalDragEnd: (details) {
                        if (!widget.isEnabled) return;
                        if (_dragValue >= maxDrag * 0.9) {
                          // 1. Snap to End
                          setState(() => _dragValue = maxDrag);

                          // 2. Trigger Action
                          widget.onSlideComplete();

                          // 3. CHANGE 2: Auto-Reset after delay
                          Future.delayed(const Duration(seconds: 1), () {
                            if (mounted) {
                              setState(() => _dragValue = 0.0);
                            }
                          });

                        } else {
                          // Snap back immediately
                          setState(() => _dragValue = 0.0);
                        }
                      },
                      child: Container(
                        width: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
    );
  }
}

// --- ACCOUNT LIST ---
class _AccountSelectionList extends StatelessWidget {
  final Function(String id, Map<String, dynamic> data) onSelect;

  const _AccountSelectionList({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Container(
      padding: const EdgeInsets.all(24),
      height: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Select Account", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('accounts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                var accounts = snapshot.data!.docs.where((doc) {
                  var d = doc.data() as Map<String, dynamic>;
                  return d['type'] != 'Cash';
                }).toList();

                if (accounts.isEmpty) return const Text("No bank accounts linked.");

                return ListView.separated(
                  itemCount: accounts.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var doc = accounts[index];
                    var data = doc.data() as Map<String, dynamic>;
                    return ListTile(
                      onTap: () => onSelect(doc.id, data),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade200)
                      ),
                      leading: const CircleAvatar(backgroundColor: Colors.black, child: Icon(Icons.account_balance, color: Colors.white, size: 18)),
                      title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("xxxx ${data['last4Digits']}"),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}