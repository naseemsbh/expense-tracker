import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expense_tracker/features/auth/presentation/pages/home_page.dart';

class AddFirstAccountPage extends StatefulWidget {
  const AddFirstAccountPage({super.key});

  @override
  State<AddFirstAccountPage> createState() => _AddFirstAccountPageState();
}

class _AddFirstAccountPageState extends State<AddFirstAccountPage> {
  final TextEditingController balanceController = TextEditingController();
  final TextEditingController last4Controller = TextEditingController();

  String selectedBankName = "";
  Color selectedColor = Colors.black;
  String selectedType = "Cash";
  final List<String> accountTypes = ["Cash", "Bank"];

  final List<Color> cardColors = [
    Colors.black,
    const Color(0xFF1E88E5), // Blue
    const Color(0xFF43A047), // Green
    const Color(0xFF8E24AA), // Purple
    const Color(0xFFE53935), // Red
  ];

  bool isLoading = false;
  String userName = "User";

  final List<String> popularBanks = [
    "State Bank of India (SBI)", "HDFC Bank", "ICICI Bank", "Axis Bank", "Federal Bank",
    "Punjab National Bank (PNB)", "Bank of Baroda", "Canara Bank", "Union Bank of India",
    "Kotak Mahindra Bank", "IndusInd Bank", "IDFC First Bank", "South Indian Bank",
    "Kerala Gramin Bank", "Airtel Payments Bank", "Paytm Payments Bank", "Jio Payments Bank",
  ];

  @override
  void initState() {
    super.initState();
    _fetchUserName();
    _onTypeSelected("Cash");
  }

  void _fetchUserName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          String fullName = doc.data()?['name'] ?? "User";
          userName = fullName.split(" ")[0];
        });
      }
    }
  }

  void _onTypeSelected(String type) {
    HapticFeedback.selectionClick();
    setState(() {
      selectedType = type;
      if (type == "Cash") {
        selectedBankName = "Cash in Hand";
        last4Controller.clear();
      } else {
        selectedBankName = "";
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isCash = selectedType == "Cash";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text("Welcome, $userName! 👋", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              Text("Let's set up your first account.", style: TextStyle(fontSize: 16, color: Colors.grey[600])),

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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.nfc, color: Colors.white54, size: 30),
                        Text(selectedType.toUpperCase(), style: const TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              selectedBankName.isEmpty ? "Account Name" : selectedBankName,
                              style: const TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            if (!isCash && last4Controller.text.isNotEmpty)
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

              // --- TYPE SELECTOR ---
              const Text("Account Type", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 10),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: accountTypes.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final type = accountTypes[index];
                    final isSelected = type == selectedType;
                    return GestureDetector(
                      onTap: () => _onTypeSelected(type),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.black : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.black),
                        ),
                        child: Text(type, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // --- ACCOUNT NAME ---
              const Text("Account Name", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (isCash)
                TextField(
                  enabled: false,
                  controller: TextEditingController(text: "Cash in Hand"),
                  decoration: InputDecoration(
                    filled: true, fillColor: Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                )
              else
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

              // --- LAST 4 DIGITS ---
              if (!isCash) ...[
                const SizedBox(height: 20),
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
                    hintText: "e.g., 8821",
                    filled: true, fillColor: Colors.grey[50],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.password, color: Colors.grey),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // --- BALANCE INPUT (Updated for Double) ---
              const Text("Current Balance", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: balanceController,
                onChanged: (_) => setState(() {}),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')), // Allow decimals
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
                      HapticFeedback.selectionClick();
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
                  onPressed: isLoading ? null : _saveAndContinue,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Finish Setup", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndContinue() async {
    // 1. Basic Validation
    if (selectedBankName.isEmpty || balanceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter details")));
      return;
    }
    if (selectedType == "Bank" && last4Controller.text.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter last 4 digits")));
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => isLoading = true);

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw "User not logged in";

      // 2. CHECK DUPLICATES
      QuerySnapshot duplicateCheck;

      if (selectedType == "Cash") {
        duplicateCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .where('type', isEqualTo: 'Cash')
            .get();

        if (duplicateCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("You already have a Cash account! Update its balance instead."), backgroundColor: Colors.red),
          );
          setState(() => isLoading = false);
          return;
        }

      } else {
        duplicateCheck = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('accounts')
            .where('name', isEqualTo: selectedBankName)
            .where('last4Digits', isEqualTo: last4Controller.text)
            .get();

        if (duplicateCheck.docs.isNotEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("This bank account already exists!"), backgroundColor: Colors.red),
          );
          setState(() => isLoading = false);
          return;
        }
      }

      // 3. Save
      double initialBalance = double.tryParse(balanceController.text) ?? 0.0;

      // CRITICAL FIX: Set isPrimary = true if it's a BANK account
      // Since this is "First Account Page", if they choose Bank, it MUST be Primary.
      bool isPrimary = selectedType == "Bank";

      await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').add({
        'name': selectedBankName,
        'type': selectedType,
        'balance': initialBalance,
        'color': selectedColor.value,
        'last4Digits': selectedType == "Bank" ? last4Controller.text : "",
        'isPrimary': isPrimary, // SAVED CORRECTLY NOW
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update total balance
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'balance': FieldValue.increment(initialBalance),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Setup Complete!")));

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}