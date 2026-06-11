import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import 'pay_anyone_page.dart';

class AddIncomePage extends StatefulWidget {
  final String accountId;
  final String accountName;
  final String last4Digits;

  const AddIncomePage({
    super.key,
    required this.accountId,
    required this.accountName,
    required this.last4Digits,
  });

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  Contact? _selectedContact;

  bool _isLoading = false;
  final double _maxAmount = 1000000;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_amountFocusNode);
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  // --- HELPER: Clean Number for Database ID ---
  String _cleanPhoneNumberForDB(String raw) {
    String clean = raw.replaceAll(RegExp(r'\D'), '');
    if (clean.length == 12 && clean.startsWith('91')) {
      clean = clean.substring(2);
    } else if (clean.length == 11 && clean.startsWith('0')) {
      clean = clean.substring(1);
    }
    return clean;
  }

  Future<void> _pickContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PayAnyonePage(isSelectionMode: true),
      ),
    );

    if (result != null && result is Contact) {
      setState(() {
        _selectedContact = result;
      });
    }
  }

  void _removeContact() {
    setState(() {
      _selectedContact = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    String displayTitle = widget.accountName;
    if (widget.last4Digits.isNotEmpty) {
      displayTitle += " • ${widget.last4Digits}";
    }

    double currentVal = double.tryParse(_amountController.text) ?? 0;
    bool isValid = currentVal >= 1 && currentVal <= _maxAmount;

    return Scaffold(
      backgroundColor: const Color(0xFF1F1F1F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F1F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("Deposit money to", style: TextStyle(color: Colors.grey[400], fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Text(displayTitle, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 1),

            // --- HERO AMOUNT INPUT ---
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text("₹", style: TextStyle(fontSize: 50, color: _amountController.text.isEmpty ? Colors.grey[600] : Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                IntrinsicWidth(
                  child: TextField(
                    controller: _amountController,
                    focusNode: _amountFocusNode,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    cursorColor: const Color(0xFF669DF6),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    style: const TextStyle(fontSize: 70, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: "0",
                      hintStyle: TextStyle(color: Colors.grey[700]),
                    ),
                    onChanged: (val) => setState(() {}),
                  ),
                ),
              ],
            ),

            if (currentVal > _maxAmount)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text("Maximum limit is ₹10,00,000", style: TextStyle(color: Colors.red[300], fontSize: 13)),
              ),

            const SizedBox(height: 30),

            // --- CONTACT CHIP ---
            if (_selectedContact != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2C),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.blueAccent,
                      child: Text(
                        _selectedContact!.displayName[0].toUpperCase(),
                        style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "From: ${_selectedContact!.displayName}",
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _removeContact,
                      child: const Icon(Icons.close, size: 16, color: Colors.grey),
                    )
                  ],
                ),
              ),

            // --- NOTE PILL ---
            Container(
              width: 260,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF303030),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TextField(
                controller: _noteController,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
                cursorColor: Colors.white,
                decoration: InputDecoration(
                  icon: GestureDetector(
                    onTap: _pickContact,
                    child: Icon(
                        _selectedContact != null ? Icons.edit_outlined : Icons.add_circle_outline,
                        size: 22,
                        color: Colors.grey[400]
                    ),
                  ),
                  border: InputBorder.none,
                  hintText: _selectedContact != null ? "What is this for?" : "Add note / contact",
                  hintStyle: TextStyle(fontSize: 15, color: Colors.grey[400], fontWeight: FontWeight.w500),
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),

            const Spacer(flex: 2),

            // --- ADD MONEY BUTTON ---
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? const Color(0xFF669DF6) : const Color(0xFF2C2C2C),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  onPressed: (_isLoading || !isValid) ? null : _saveTransaction,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : Text(
                      isValid ? "Add Money" : (currentVal > _maxAmount ? "Limit Exceeded" : "Enter Amount"),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isValid ? Colors.black : Colors.grey[500])
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveTransaction() async {
    String rawAmount = _amountController.text;
    if (rawAmount.isEmpty) return;
    double amount = double.parse(rawAmount);

    if (amount < 1 || amount > _maxAmount) return;

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String finalNote = "";
      String description = _noteController.text.trim();
      String? contactName;
      String? contactNumber;

      // --- LOGIC: Handle Contact Data ---
      if (_selectedContact != null) {
        // 1. Set structured data
        contactName = _selectedContact!.displayName;
        if (_selectedContact!.phones.isNotEmpty) {
          contactNumber = _cleanPhoneNumberForDB(_selectedContact!.phones.first.number);
        }

        // 2. Create display note
        finalNote = "Received from $contactName";
        if (description.isNotEmpty) {
          finalNote += ": $description";
        }
      } else {
        finalNote = description.isNotEmpty ? description : "Money Deposited";
      }

      final batch = FirebaseFirestore.instance.batch();

      final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();

      // --- SAVING THE NEW FIELDS ---
      Map<String, dynamic> transData = {
        'amount': amount,
        'type': 'income',
        'accountId': widget.accountId,
        'accountName': widget.accountName,
        'category': 'Deposit',
        'note': finalNote,
        'date': FieldValue.serverTimestamp(),
      };

      // Only add contact fields if they exist
      if (contactNumber != null) {
        transData['relatedContactName'] = contactName;
        transData['relatedContactNumber'] = contactNumber;
      }

      batch.set(transRef, transData);

      final accountRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(widget.accountId);
      batch.update(accountRef, {
        'balance': FieldValue.increment(amount),
      });

      await batch.commit();

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("₹$rawAmount added successfully"), backgroundColor: Colors.green));
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}