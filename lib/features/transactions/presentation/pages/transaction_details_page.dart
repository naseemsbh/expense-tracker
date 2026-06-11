import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TransactionDetailsPage extends StatefulWidget {
  final String transactionId;
  final Map<String, dynamic> data;

  const TransactionDetailsPage({
    super.key,
    required this.transactionId,
    required this.data,
  });

  @override
  State<TransactionDetailsPage> createState() => _TransactionDetailsPageState();
}

class _TransactionDetailsPageState extends State<TransactionDetailsPage> {
  late DateTime _selectedDate;
  late String _selectedCategory;
  late TextEditingController _tagController;
  late TextEditingController _noteController;
  bool _isLoading = false;

  // --- ICONS MAPPING ---
  static final Map<String, IconData> _categoryIcons = {
    'Food & drinks': Icons.fastfood_rounded,
    'Groceries': Icons.shopping_basket_rounded,
    'Fuel': Icons.local_gas_station_rounded,
    'Shopping': Icons.shopping_bag_rounded,
    'Entertainment': Icons.movie_filter_rounded,
    'Bills': Icons.lightbulb_rounded,
    'Commute': Icons.directions_car_rounded,
    'Rent': Icons.home_rounded,
    'Medical': Icons.medical_services_rounded,
    'Education': Icons.school_rounded,
    'Pets': Icons.pets_rounded,
    'Personal': Icons.face_rounded,
    'Tools': Icons.build_circle_rounded,
    'Travel': Icons.flight_takeoff_rounded,
    'Fees': Icons.receipt_long_rounded,
    'Gifts': Icons.card_giftcard_rounded,
    'Random': Icons.shuffle_rounded,
    'Transfer': Icons.person_rounded,
    'Salary': Icons.account_balance_wallet_rounded,
    'Allowance': Icons.savings_rounded,
    'Bonus': Icons.star_rounded,
    'Other': Icons.more_horiz_rounded
  };

  @override
  void initState() {
    super.initState();
    if (widget.data['date'] is Timestamp) {
      _selectedDate = (widget.data['date'] as Timestamp).toDate();
    } else {
      _selectedDate = DateTime.now();
    }
    _selectedCategory = widget.data['category'] ?? 'Uncategorised';
    _tagController = TextEditingController(text: widget.data['tag'] ?? '');
    _noteController = TextEditingController(text: widget.data['note'] ?? widget.data['category'] ?? 'Transaction');
  }

  @override
  void dispose() {
    _tagController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  // --- ACTIONS ---

  Future<void> _updateDate(DateTime newDate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _selectedDate = newDate);
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(widget.transactionId).update({'date': newDate});
  }

  Future<void> _updateCategory(String newCategory) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _selectedCategory = newCategory;
      _noteController.text = newCategory; // Auto-rename transaction
    });

    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(widget.transactionId).update({
      'category': newCategory,
      'note': newCategory,
    });
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(widget.transactionId).update({
      'tag': _tagController.text.trim(),
      'note': _noteController.text.trim(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Changes saved successfully!")));
      Navigator.pop(context);
    }
  }

  Future<void> _deleteTransaction() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction"),
        content: const Text("This will remove the transaction and reverse the amount. Are you sure?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isLoading = true);
    try {
      DocumentReference accountRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(widget.data['accountId']);
      double amount = (widget.data['amount'] ?? 0).toDouble();
      String type = widget.data['type'];

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot accSnap = await transaction.get(accountRef);
        if (accSnap.exists) {
          double currentBal = (accSnap['balance'] ?? 0).toDouble();
          double newBal = currentBal;
          if (type == 'expense' || type == 'pot_deposit') newBal += amount;
          else if (type == 'income' || type == 'pot_withdraw') newBal -= amount;
          transaction.update(accountRef, {'balance': newBal});
        }
        transaction.delete(FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc(widget.transactionId));
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context, initialDate: _selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(data: ThemeData.light().copyWith(colorScheme: const ColorScheme.light(primary: Color(0xFF163C46))), child: child!);
      },
    );
    if (picked != null) _updateDate(DateTime(picked.year, picked.month, picked.day, _selectedDate.hour, _selectedDate.minute));
  }

  // --- UPDATED MORE DETAILS SHEET ---
  void _showMoreDetails() {
    String accountId = widget.data['accountId'] ?? '';
    String toAccountId = widget.data['toAccountId'] ?? '';

    String type = widget.data['type'] ?? 'expense';
    bool isMoneyIn = type == 'income' || type == 'pot_withdraw';
    bool isSelfTransfer = type.contains('transfer');

    String detailLabel = isMoneyIn ? "Money received in:" : "Payment Method";

    final user = FirebaseAuth.instance.currentUser;

    showModalBottomSheet(
        context: context, backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Transaction Details", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),

                // CASE 1: SELF TRANSFER
                if (isSelfTransfer) ...[
                  const Text("Transfer from:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildAccountRow(user?.uid, accountId), // FROM

                  const SizedBox(height: 20),
                  const Text("Transfer to:", style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  if (toAccountId.isNotEmpty)
                    _buildAccountRow(user?.uid, toAccountId) // TO
                  else
                    const Row(children: [Icon(Icons.help_outline, color: Colors.grey), SizedBox(width: 12), Text("Destination unknown", style: TextStyle(fontWeight: FontWeight.w600))]),

                  // CASE 2: NORMAL TRANSACTION
                ] else ...[
                  Text(detailLabel, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  _buildAccountRow(user?.uid, accountId),
                ],
                const SizedBox(height: 20),
              ],
            ),
          );
        }
    );
  }

  // --- IMPROVED ACCOUNT FETCHING ---
  Widget _buildAccountRow(String? userId, String accId) {
    if (userId == null || accId.isEmpty) {
      return Row(children: [
        Icon(Icons.warning_amber_rounded, color: Colors.orange[300]),
        const SizedBox(width: 12),
        const Text("Unknown Account", style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
      ]);
    }
    return FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).collection('accounts').doc(accId).get(),
        builder: (context, snapshot) {
          // 1. Loading State
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Row(children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 12),
              const Text("Loading account info...", style: TextStyle(color: Colors.grey))
            ]);
          }
          // 2. Data Exists
          if (snapshot.hasData && snapshot.data!.exists) {
            var accData = snapshot.data!.data() as Map<String, dynamic>;
            return Row(children: [
              Icon(Icons.account_balance, color: Colors.grey[700]),
              const SizedBox(width: 12),
              Text("${accData['name']} (${accData['last4Digits'] ?? '****'})", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))
            ]);
          }
          // 3. Document Missing (Deleted)
          return Row(children: [
            Icon(Icons.error_outline, color: Colors.red[300]),
            const SizedBox(width: 12),
            const Text("Account not found (Deleted?)", style: TextStyle(color: Colors.grey))
          ]);
        }
    );
  }

  void _showAllCategoriesSheet(bool isIncome) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white, isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6, minChildSize: 0.4, maxChildSize: 0.9, expand: false,
          builder: (_, controller) {
            return Column(
              children: [
                const SizedBox(height: 20),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text("Select Category", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Expanded(
                  child: GridView.count(
                    controller: controller, crossAxisCount: 4, mainAxisSpacing: 20, crossAxisSpacing: 10, padding: const EdgeInsets.all(24),
                    children: _getAllCategories(isIncome).map((cat) {
                      bool isSelected = _selectedCategory == cat;
                      return _buildCategoryIcon(cat, isSelected, closeSheet: true);
                    }).toList(),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String type = widget.data['type'] ?? 'expense';
    double amount = (widget.data['amount'] ?? 0).toDouble();
    bool isIncome = type == 'income';

    // Flags
    bool isPotDeposit = type == 'pot_deposit';
    bool isPotWithdraw = type == 'pot_withdraw';
    bool isPot = isPotDeposit || isPotWithdraw;
    bool isSelfTransfer = type.contains('transfer');
    bool showCategoryPicker = !isPot && !isSelfTransfer;

    Color themeColor = const Color(0xFF163C46);

    String suggestion1 = isIncome ? 'Salary' : 'Groceries';
    String suggestion2 = isIncome ? 'Allowance' : 'Shopping';
    if (_selectedCategory == suggestion1) suggestion1 = isIncome ? 'Bonus' : 'Fuel';
    if (_selectedCategory == suggestion2) suggestion2 = isIncome ? 'Other' : 'Food & drinks';

    return Scaffold(
      backgroundColor: themeColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [IconButton(icon: const Icon(Icons.help_outline, color: Colors.white), onPressed: () {})],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          children: [
            // STATUS & DATE
            Text((isIncome || isPot || isSelfTransfer) ? "Transaction successful" : "Payment successful", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [Text(DateFormat('EEE, d MMM • h:mm a').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(width: 6), const Icon(Icons.edit, color: Colors.white70, size: 14)]),
              ),
            ),

            const SizedBox(height: 30),

            // --- BOX 1: RECEIPT CARD ---
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16)),
                        // ICON SELECTION LOGIC
                        child: Icon(
                            isPot ? Icons.savings_outlined :
                            (isSelfTransfer ? Icons.swap_horiz_rounded : (_categoryIcons[_selectedCategory] ?? Icons.receipt)),
                            size: 28,
                            color: Colors.black
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: TextField(controller: _noteController, decoration: const InputDecoration(border: InputBorder.none, isDense: true), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
                      Text("${(isIncome || isPot) ? '+' : ''}₹${amount.toStringAsFixed(0)}", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: (isIncome || isPot) ? Colors.green[700] : Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _showMoreDetails,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("More details", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)),
                        Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.grey),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // --- BOX 2: CATEGORIES & TAGS ---
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  // A. CATEGORIES (Standard)
                  if (showCategoryPicker) ...[
                    const Text("Your spend was categorised", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("Tap to change it", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildCategoryIcon(_selectedCategory, true),
                        _buildCategoryIcon(suggestion1, false),
                        _buildCategoryIcon(suggestion2, false),
                        GestureDetector(
                          onTap: () => _showAllCategoriesSheet(isIncome),
                          child: Column(children: [
                            Container(width: 50, height: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.grey.shade300)), child: const Icon(Icons.add, color: Colors.black)),
                            const SizedBox(height: 8),
                            const Text("More", style: TextStyle(fontSize: 11, color: Colors.black54)),
                          ]),
                        )
                      ],
                    ),
                    const SizedBox(height: 40),

                    // B. LOCKED CATEGORY: WITHDRAW
                  ] else if (isPotWithdraw) ...[
                    const Text("Transaction marked as Pots withdrawal", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("This has been auto-selected", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    Center(child: Stack(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: Icon(Icons.downloading, color: Colors.grey[700], size: 28)), Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[700], shape: BoxShape.circle), child: const Icon(Icons.check, size: 10, color: Colors.white)))])),
                    const SizedBox(height: 40),

                    // C. LOCKED CATEGORY: DEPOSIT
                  ] else if (isPotDeposit) ...[
                    const Text("Transaction marked as Credited to Pots", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("This has been auto-selected", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    Center(child: Stack(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: Icon(Icons.savings_outlined, color: Colors.grey[700], size: 28)), Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[700], shape: BoxShape.circle), child: const Icon(Icons.check, size: 10, color: Colors.white)))])),
                    const SizedBox(height: 40),

                    // D. LOCKED CATEGORY: SELF TRANSFER
                  ] else if (isSelfTransfer) ...[
                    const Text("Transaction marked as Self Transfer", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text("This has been auto-selected", style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 24),
                    Center(child: Stack(children: [Container(width: 60, height: 60, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade300)), child: Icon(Icons.swap_horiz_rounded, color: Colors.grey[700], size: 28)), Positioned(right: 0, top: 0, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.grey[700], shape: BoxShape.circle), child: const Icon(Icons.check, size: 10, color: Colors.white)))])),
                    const SizedBox(height: 40),
                  ],

                  // E. TAGS
                  const Text("Tag your spends, your way", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _tagController,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: "Add your first tag",
                      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
                      fillColor: Colors.grey[100], filled: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- FOOTER BUTTONS ---
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: themeColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("Save Changes", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteTransaction,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text("Powered by ", style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)), const Text("EXPENSE TRACKER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10))]),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String cat, bool isSelected, {bool closeSheet = false}) {
    Color themeColor = const Color(0xFF163C46);
    return GestureDetector(
      onTap: () {
        _updateCategory(cat);
        if (closeSheet) Navigator.pop(context);
      },
      child: Column(
        children: [
          Stack(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 200), width: 50, height: 50, decoration: BoxDecoration(color: isSelected ? const Color(0xFFE3F2FD) : Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? themeColor : Colors.grey.shade300, width: isSelected ? 1.5 : 1), boxShadow: isSelected ? [BoxShadow(color: themeColor.withOpacity(0.1), blurRadius: 8)] : []), child: Icon(_categoryIcons[cat] ?? Icons.category, color: isSelected ? themeColor : Colors.grey, size: 22)),
            if (isSelected) Positioned(right: -2, top: -2, child: Container(padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: themeColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)), child: const Icon(Icons.check, size: 10, color: Colors.white)))
          ]),
          const SizedBox(height: 8),
          Text(cat, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.black87 : Colors.black54), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  List<String> _getAllCategories(bool isIncome) {
    if (isIncome) return ['Salary', 'Allowance', 'Bonus', 'Other'];
    return _categoryIcons.keys.where((k) => !['Salary', 'Allowance', 'Bonus', 'Other'].contains(k)).toList();
  }
}