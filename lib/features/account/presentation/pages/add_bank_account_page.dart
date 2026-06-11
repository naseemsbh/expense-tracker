import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddBankAccountPage extends StatefulWidget {
  const AddBankAccountPage({super.key});

  @override
  State<AddBankAccountPage> createState() => _AddBankAccountPageState();
}

class _AddBankAccountPageState extends State<AddBankAccountPage> {
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController last4Controller = TextEditingController();

  String selectedBankName = "";
  Color selectedColor = Colors.black;

  final List<Color> cardColors = [
    Colors.black,
    const Color(0xFF1E88E5), // Blue
    const Color(0xFF43A047), // Green
    const Color(0xFF8E24AA), // Purple
    const Color(0xFFE53935), // Red
  ];

  bool isLoading = false;

  final List<String> popularBanks = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "Federal Bank",
    "Punjab National Bank (PNB)", "Bank of Baroda", "Canara Bank", "Union Bank of India",
    "Kotak Mahindra Bank", "IndusInd Bank", "IDFC First Bank", "South Indian Bank",
    "Kerala Gramin Bank", "Airtel Payments Bank", "Paytm Payments Bank", "Jio Payments Bank",
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Add Bank Account", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Link a new bank", style: TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 30),

              // --- CARD PREVIEW ---
              Container(
                width: double.infinity,
                height: 180,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: selectedColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: selectedColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(Icons.nfc, color: Colors.white54, size: 30),
                        Text("BANK", style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedBankName.isEmpty ? "Bank Name" : selectedBankName,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            if (last4Controller.text.isNotEmpty)
                              Text(
                                  " •••• ${last4Controller.text}",
                                  style: const TextStyle(color: Colors.white70, fontSize: 14)
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "₹ ${balanceController.text.isEmpty ? '0.00' : balanceController.text}",
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // --- BANK NAME INPUT ---
              const Text("Bank Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              LayoutBuilder(
                  builder: (context, constraints) {
                    return Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text == '') return const Iterable<String>.empty();
                        return popularBanks.where((String option) => option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) => setState(() => selectedBankName = selection),
                      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
                        textController.addListener(() => setState(() => selectedBankName = textController.text));
                        return TextField(
                          controller: textController,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            hintText: "Search Bank (e.g., SBI)",
                            filled: true, fillColor: Colors.grey[50],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            suffixIcon: const Icon(Icons.search, color: Colors.grey),
                          ),
                        );
                      },
                    );
                  }
              ),

              const SizedBox(height: 20),

              // --- LAST 4 DIGITS INPUT ---
              const Text("Last 4 Digits", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: last4Controller,
                onChanged: (_) => setState(() {}),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  LengthLimitingTextInputFormatter(4),
                  FilteringTextInputFormatter.digitsOnly
                ],
                decoration: InputDecoration(
                  hintText: "****",
                  filled: true, fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  prefixIcon: const Icon(Icons.password, color: Colors.grey),
                ),
              ),

              const SizedBox(height: 20),

              // --- BALANCE INPUT (Updated for Decimals) ---
              const Text("Current Balance", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: balanceController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true), // Allow decimals
                inputFormatters: [
                  // Regex to allow numbers and one decimal point (100.50)
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  prefixText: "₹ ",
                  hintText: "0.00",
                  filled: true, fillColor: Colors.grey[50],
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),

              const SizedBox(height: 30),

              // --- COLOR PICKER ---
              const Text("Card Color", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              Row(
                children: cardColors.map((color) {
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick(); // Feedback
                      setState(() => selectedColor = color);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selectedColor == color ? Border.all(color: Colors.grey, width: 3) : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 40),

              // --- SAVE BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: isLoading ? null : _saveAccount,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Save Account", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAccount() async {
    // 1. Validation
    if (selectedBankName.isEmpty || balanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter details")));
      return;
    }
    if (last4Controller.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter last 4 digits")));
      return;
    }

    // Haptic Feedback for Save Action
    HapticFeedback.mediumImpact();
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      final accountsRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts');

      // 2. CHECK IF THIS IS THE FIRST *BANK* ACCOUNT (Correctly Ignoring Cash)
      final allAccountsSnapshot = await accountsRef.get();

      final existingBanks = allAccountsSnapshot.docs.where((doc) {
        final data = doc.data();
        // Ensure we don't count the "Cash" wallet as a bank
        return data['name'] != "Cash on Hand" && data['type'] != "Cash";
      }).toList();

      bool isFirstAccount = existingBanks.isEmpty;

      // 3. CHECK DUPLICATES
      final duplicateCheck = existingBanks.where((doc) {
        final data = doc.data();
        return data['name'] == selectedBankName && data['last4Digits'] == last4Controller.text;
      });

      if (duplicateCheck.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("This bank account already exists!"), backgroundColor: Colors.red),
        );
        setState(() => isLoading = false);
        return;
      }

      // 4. Save (Using Double for Balance)
      double initialBalance = double.tryParse(balanceController.text) ?? 0.0;

      await accountsRef.add({
        'name': selectedBankName,
        'type': 'Bank',
        'balance': initialBalance, // Saved as Double
        'color': selectedColor.value,
        'last4Digits': last4Controller.text,
        'isPrimary': isFirstAccount, // Auto-set Primary logic
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update total balance
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'balance': FieldValue.increment(initialBalance),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Account Added!")));

      Navigator.pop(context);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}