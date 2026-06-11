import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expense_tracker/features/auth/presentation/pages/mpin_verification_page.dart';
import '../widgets/payment_security_widgets.dart'; // For PaymentSuccessPage

class AddExpensePage extends StatefulWidget {
  const AddExpensePage({super.key});

  @override
  State<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends State<AddExpensePage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  // --- CONFIG ---
  final double _maxLimit = 100000;
  final double _mpinThreshold = 150;

  // --- STATE ---
  String _selectedCategory = "Food & drinks"; // Default
  IconData _selectedIcon = Icons.fastfood;    // Default Icon
  Color _selectedColor = const Color(0xFFFF9F1C); // Default Color (Orange)

  List<Map<String, dynamic>> _myAccounts = [];
  String? _selectedAccountId;
  final Map<String, double> _revealedBalances = {};
  bool _isLoading = false;

  // --- DATA: CATEGORIES (Vibrant Colors) ---
  final List<Map<String, dynamic>> _allCategories = [
    {'name': 'Food & drinks', 'icon': Icons.fastfood, 'color': Color(0xFFFF9F1C)},
    {'name': 'Groceries', 'icon': Icons.shopping_basket_rounded, 'color': Color(0xFF2EC4B6)},
    {'name': 'Fuel', 'icon': Icons.local_gas_station_rounded, 'color': Color(0xFFE71D36)},
    {'name': 'Shopping', 'icon': Icons.shopping_bag_rounded, 'color': Color(0xFF9D4EDD)},
    {'name': 'Entertainment', 'icon': Icons.movie_filter_rounded, 'color': Color(0xFFFF006E)},
    {'name': 'Bills', 'icon': Icons.lightbulb_rounded, 'color': Color(0xFFFFBE0B)},
    {'name': 'Commute', 'icon': Icons.directions_car_rounded, 'color': Color(0xFF3A86FF)},
    {'name': 'Rent', 'icon': Icons.home_rounded, 'color': Color(0xFF06D6A0)},
    {'name': 'Medical', 'icon': Icons.medical_services_rounded, 'color': Color(0xFFEF476F)},
    {'name': 'Education', 'icon': Icons.school_rounded, 'color': Color(0xFF118AB2)},
    {'name': 'Pets', 'icon': Icons.pets_rounded, 'color': Color(0xFF8D5B4C)},
    {'name': 'Personal', 'icon': Icons.face_rounded, 'color': Color(0xFFFF5400)},
    {'name': 'Tools', 'icon': Icons.build_circle_rounded, 'color': Color(0xFF607D8B)},
    {'name': 'Travel', 'icon': Icons.flight_takeoff_rounded, 'color': Color(0xFF00B4D8)},
    {'name': 'Fees', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFF9E9E9E)},
    {'name': 'Gifts', 'icon': Icons.card_giftcard_rounded, 'color': Color(0xFFFF7096)},
    {'name': 'Random', 'icon': Icons.shuffle_rounded, 'color': Colors.white},
  ];

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_amountFocusNode);
    });
  }

  // --- FIXED FETCH & SORT LOGIC ---
  Future<void> _fetchAccounts() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .get();

    if (snapshot.docs.isEmpty) return;

    List<Map<String, dynamic>> loadedAccounts = snapshot.docs.map((doc) {
      var data = doc.data();
      return {
        'id': doc.id,
        'name': data['name'] ?? 'Account',
        'realBalance': (data['balance'] ?? 0).toDouble(),
      };
    }).toList();

    // 1. SORT ALPHABETICALLY (So "Bank A" comes before "Cash")
    // Or you can leave this out if you just want the order you created them in.
    loadedAccounts.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if (mounted) {
      setState(() {
        _myAccounts = loadedAccounts;
        // 2. FORCE SELECT INDEX 0 (This is your Primary now)
        if (_myAccounts.isNotEmpty) {
          _selectedAccountId = _myAccounts[0]['id'];
        }
      });
    }
  }

  // --- 1. COMPACT PAYMENT SHEET ---
  void _onArrowPressed() {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) return;

    if (_myAccounts.isEmpty) return;

    // --- CRITICAL FIX: ENSURE PRIMARY IS SELECTED ---
    // If nothing selected, OR selected ID doesn't exist anymore, reset to Index 0
    bool idExists = _myAccounts.any((a) => a['id'] == _selectedAccountId);
    if (_selectedAccountId == null || !idExists) {
      setState(() {
        _selectedAccountId = _myAccounts[0]['id'];
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141414), // Pure Dark
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          // Find selected account object safely
          var selectedAccount = _myAccounts.firstWhere(
                  (a) => a['id'] == _selectedAccountId,
              orElse: () => _myAccounts[0] // Fallback to Primary
          );

          bool isBalanceRevealed = _revealedBalances.containsKey(selectedAccount['id']);

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Handle bar
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),

                const Text("Paying using", style: TextStyle(color: Colors.grey, fontSize: 14)),
                const SizedBox(height: 16),

                // --- ACCOUNT CARD (Redesigned) ---
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
                      mainAxisSize: MainAxisSize.min, // Hug content
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

                // Check Balance Link
                isBalanceRevealed
                    ? Text("₹${_revealedBalances[selectedAccount['id']]}", style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
                    : GestureDetector(
                  onTap: () => _checkBalance(selectedAccount['id'], selectedAccount['realBalance'], setSheetState),
                  child: const Text("Check balance", style: TextStyle(color: Color(0xFF669DF6), fontSize: 13, fontWeight: FontWeight.w500)),
                ),

                const SizedBox(height: 32),

                // PAY BUTTON (Full Width)
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
                    onPressed: () => _validateAndPay(amount),
                    child: Text("Pay ₹${amount.toStringAsFixed(0)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.verified_user_outlined, color: Colors.grey, size: 12),
                    SizedBox(width: 4),
                    Text("Secure Payment", style: TextStyle(color: Colors.grey, fontSize: 12)),
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

                ..._myAccounts.map((account) {
                  bool isSelected = account['id'] == _selectedAccountId;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _selectedAccountId = account['id']);
                      Navigator.pop(context); // Close selection
                      _onArrowPressed(); // Re-open payment sheet
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

  // --- LOGIC METHODS (MPIN, BALANCE) ---
  void _checkBalance(String accountId, double realBalance, StateSetter setSheetState) async {
    final bool? isVerified = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MpinVerificationPage()));
    if (isVerified == true) setSheetState(() => _revealedBalances[accountId] = realBalance);
  }

  void _validateAndPay(double amount) {
    // Safety check again inside payment logic
    if (_selectedAccountId == null && _myAccounts.isNotEmpty) {
      _selectedAccountId = _myAccounts[0]['id'];
    }

    var account = _myAccounts.firstWhere((a) => a['id'] == _selectedAccountId, orElse: () => _myAccounts[0]);
    double availableBalance = account['realBalance'];
    Navigator.pop(context); // Close Sheet

    if (availableBalance < amount) {
      _showInsufficientBalanceError();
      return;
    }
    if (amount >= _mpinThreshold) _askMpinAndProcess(amount);
    else _saveExpense(amount);
  }

  void _showInsufficientBalanceError() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Insufficient Balance"), backgroundColor: Colors.red)
    );
  }

  void _askMpinAndProcess(double amount) async {
    final bool? isVerified = await Navigator.push(context, MaterialPageRoute(builder: (context) => const MpinVerificationPage()));
    if (isVerified == true) _saveExpense(amount);
  }

  Future<void> _saveExpense(double amount) async {
    setState(() => _isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String note = _tagController.text.trim();
      if (note.isEmpty) note = _selectedCategory;

      final batch = FirebaseFirestore.instance.batch();
      final transRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').doc();
      batch.set(transRef, {
        'amount': amount, 'type': 'expense', 'category': _selectedCategory, 'note': note,
        'accountId': _selectedAccountId, 'date': FieldValue.serverTimestamp(),
      });
      final accRef = FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').doc(_selectedAccountId);
      batch.update(accRef, { 'balance': FieldValue.increment(-amount) });
      await batch.commit();

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PaymentSuccessPage(amount: amount, name: _selectedCategory)));
    } catch (e) { debugPrint("Error: $e"); }
    finally { if(mounted) setState(() => _isLoading = false); }
  }

  // --- MAIN UI BUILD ---
  @override
  Widget build(BuildContext context) {
    double currentVal = double.tryParse(_amountController.text) ?? 0;
    bool isOverLimit = currentVal > _maxLimit;

    return Scaffold(
      backgroundColor: Colors.black, // Midnight Theme
      body: SafeArea(
        child: Column(
          children: [
            // 1. TOP BAR
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20)),
                    child: const Text("Add Expense", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 48), // Spacer
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. AMOUNT INPUT (HERO)
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Enter amount", style: TextStyle(color: Colors.grey, fontSize: 14)),
                  const SizedBox(height: 16),
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
                          cursorColor: _selectedColor,
                          style: TextStyle(color: isOverLimit ? Colors.redAccent : Colors.white, fontSize: 64, fontWeight: FontWeight.bold),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                            TextInputFormatter.withFunction((oldValue, newValue) {
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
                  if (isOverLimit) const Text("Limit exceeded", style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                ],
              ),
            ),

            // 3. CATEGORY SELECTOR (MIDNIGHT BUBBLES)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0; i < 3; i++) _buildCategoryBubble(_allCategories[i]),
                  GestureDetector(
                    onTap: _showFullCategoryGrid,
                    child: Column(
                      children: [
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white10),
                          ),
                          child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(height: 8),
                        const Text("More", style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(flex: 1),

            // 4. NOTE INPUT (CENTERED PILL)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _tagController,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Tag your spends, your way",
                    hintStyle: TextStyle(color: Colors.grey),
                    icon: Icon(Icons.edit_note_rounded, color: Colors.grey, size: 20),
                  ),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // 5. FAB
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.bottomRight,
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryBubble(Map<String, dynamic> cat) {
    bool isSelected = _selectedCategory == cat['name'];
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = cat['name'];
          _selectedIcon = cat['icon'];
          _selectedColor = cat['color'];
        });
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: isSelected ? cat['color'] : const Color(0xFF1E1E1E),
              shape: BoxShape.circle,
              boxShadow: isSelected ? [BoxShadow(color: cat['color'].withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))] : [],
            ),
            child: Icon(cat['icon'], color: isSelected ? Colors.black : cat['color'], size: 26),
          ),
          const SizedBox(height: 8),
          Text(cat['name'], style: TextStyle(color: isSelected ? cat['color'] : Colors.grey, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  void _showFullCategoryGrid() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Select Category", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  itemCount: _allCategories.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 24, crossAxisSpacing: 16, childAspectRatio: 0.75),
                  itemBuilder: (context, index) {
                    var cat = _allCategories[index];
                    bool isSelected = _selectedCategory == cat['name'];
                    return GestureDetector(
                      onTap: () {
                        setState(() { _selectedCategory = cat['name']; _selectedIcon = cat['icon']; _selectedColor = cat['color']; });
                        Navigator.pop(context);
                      },
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), shape: BoxShape.circle, border: isSelected ? Border.all(color: cat['color'], width: 2) : null),
                            child: Icon(cat['icon'], color: cat['color'], size: 24),
                          ),
                          const SizedBox(height: 8),
                          Text(cat['name'], textAlign: TextAlign.center, style: TextStyle(color: isSelected ? Colors.white : Colors.grey, fontSize: 11), maxLines: 1),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}