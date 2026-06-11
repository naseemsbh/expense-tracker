import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../features/transactions/presentation/pages/transaction_details_page.dart';
import '../../../../features/profile/presentation/pages/profile_page.dart';
import '../../../../features/transactions/presentation/pages/add_income_page.dart';
import '../../../../features/auth/presentation/pages/mpin_verification_page.dart';
import '../../../../features/transactions/presentation/pages/transfers_page.dart';
import '../../../../features/transactions/presentation/pages/add_expense_page.dart';
import '../../../../features/money/presentation/pages/money_page.dart';
import '../../../../features/transactions/presentation/pages/all_transactions_page.dart'; // Add this
import '../../../../features/pots/presentation/pages/create_pot_category_page.dart';
import '../../../../features/pots/presentation/pages/pots_dashboard_page.dart';

class HomePage extends StatefulWidget {
  final int initialIndex; // 1. Add this variable

  // 2. Update constructor to accept it (defaults to 0 for Home)
  const HomePage({super.key, this.initialIndex = 0});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  bool _isTotalBalanceVisible = false;
  double _totalCalculatedBalance = 0.0;

  // --- 1. ICON MAP ---
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
  };

  // --- 2. COLOR MAP ---
  static final Map<String, Color> _categoryColors = {
    'Food & drinks': const Color(0xFF000000), // Black
    'Groceries': const Color(0xFF2EC4B6),     // Teal
    'Fuel': const Color(0xFFE71D36),          // Red
    'Shopping': const Color(0xFF9D4EDD),      // Purple
    'Entertainment': const Color(0xFFFF006E), // Pink
    'Bills': const Color(0xFFFFBE0B),         // Yellow
    'Commute': const Color(0xFF3A86FF),       // Blue
    'Rent': const Color(0xFF06D6A0),          // Green
    'Medical': const Color(0xFFEF476F),       // Red-Pink
    'Education': const Color(0xFF118AB2),     // Cyan
    'Pets': const Color(0xFF8D5B4C),          // Brown
    'Personal': const Color(0xFFFF5400),      // Deep Orange
    'Tools': const Color(0xFF607D8B),         // Blue Grey
    'Travel': const Color(0xFF00B4D8),        // Light Blue
    'Fees': const Color(0xFF9E9E9E),          // Grey
    'Gifts': const Color(0xFFFF7096),         // Light Pink
    'Random': const Color(0xFF607D8B),        // Blue Grey
    'Transfer': const Color(0xFF3F51B5),      // Indigo
  };

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex; // 3. Set the selected index from the constructor
    _calculateTotalBalance();
  }

  void _calculateTotalBalance() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .snapshots()
        .listen((snapshot) {
      double total = 0;
      for (var doc in snapshot.docs) {
        total += (doc.data()['balance'] ?? 0).toDouble();
      }
      if (mounted) {
        setState(() {
          _totalCalculatedBalance = total;
        });
      }
    });
  }

  // --- SMART POTS NAVIGATION ---
  Future<void> _handlePotsClick(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check if user has at least 1 pot
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('pots')
        .limit(1)
        .get();

    if (!context.mounted) return;

    if (snapshot.docs.isNotEmpty) {
      // Has Pots -> Dashboard
      Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PotsDashboardPage())
      );
    } else {
      // No Pots -> Creation Page
      Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const CreatePotCategoryPage())
      );
    }
  }

  // --- SHOW ADD SHEET ---
  void _showAddTransactionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return const _AccountSelectionSheet();
      },
    );
  }

  // --- SHOW CHECK ALL BALANCES ---
  void _showAllBalances(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return const SizedBox();

        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text("Your Accounts", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              SizedBox(
                height: 300,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                    var docs = snapshot.data!.docs;
                    if (docs.isEmpty) return const Text("No accounts found.");
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        return _SecureAccountTile(data: docs[index].data() as Map<String, dynamic>);
                      },
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final List<Widget> pages = [
      _buildDashboard(user),
      const TransfersPage(),
      const MoneyPage(), // <--- UPDATED: Displays your new Money Page
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        backgroundColor: Colors.white,
        elevation: 10,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.swap_horiz), label: 'Transfers'),
          BottomNavigationBarItem(icon: Icon(Icons.pie_chart_outline), label: 'Money'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'You'),
        ],
      ),
    );
  }

  // --- DASHBOARD WIDGET ---
  Widget _buildDashboard(User user) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER ---
            const SizedBox(height: 10),
            StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
                builder: (context, snapshot) {
                  String name = "...";
                  String initial = "?";
                  if (snapshot.hasData && snapshot.data!.data() != null) {
                    var data = snapshot.data!.data() as Map<String, dynamic>;
                    name = data['name'] ?? "User";
                    if (name.isNotEmpty) initial = name[0].toUpperCase();
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Welcome back,", style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.black)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage())),
                        child: CircleAvatar(
                          backgroundColor: Colors.black,
                          radius: 24,
                          child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  );
                }
            ),

            const SizedBox(height: 24),

            // --- HERO CARD ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10))
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20)),
                    child: const Text("Total Balance", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isTotalBalanceVisible ? "₹ $_totalCalculatedBalance" : "₹ ••••••",
                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -1),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => setState(() => _isTotalBalanceVisible = !_isTotalBalanceVisible),
                        child: Icon(_isTotalBalanceVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 24),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  GestureDetector(
                    onTap: () => _showAllBalances(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Check all balances", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600, fontSize: 14)),
                        Icon(Icons.keyboard_arrow_right, color: Colors.grey[700], size: 18)
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // --- ACTION BUTTONS ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                    icon: Icons.add,
                    label: "Add",
                    isPrimary: true,
                    onTap: () => _showAddTransactionSheet(context)
                ),
                _buildActionButton(
                    icon: Icons.add_card,
                    label: "Expense",
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpensePage()))
                ),
                // --- POTS BUTTON ---
                _buildActionButton(
                    icon: Icons.savings_outlined,
                    label: "Pots",
                    onTap: () => _handlePotsClick(context)
                ),

                _buildActionButton(icon: Icons.bar_chart_rounded, label: "Analysis", onTap: () {}),
              ],
            ),

            const SizedBox(height: 24),

            // --- RECENT TRANSACTIONS HEADER ---
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Recent Transactions", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF163C46))),
                TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AllTransactionsPage()),
                      );
                    },
                    child: const Text("View All", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))
                ),
              ],
            ),
            const SizedBox(height: 10),

            // --- RECENT TRANSACTIONS LIST ---
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .collection('transactions')
                    .orderBy('date', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(child: Text("No transactions yet", style: TextStyle(color: Colors.grey)));
                  }
                  var docs = snapshot.data!.docs;
                  return ListView.builder(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var doc = docs[index];
                      var data = doc.data() as Map<String, dynamic>;

                      // FIX: Pass both the Document ID and the Data
                      return _buildTransactionTile(doc.id, data);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(String docId, Map<String, dynamic> data) {
    String type = data['type'] ?? '';

    // Determine Categories
    bool isSelfTransfer = type == 'self_transfer';
    bool isExpense = type == 'expense';
    bool isPotDeposit = type == 'pot_deposit';
    bool isPotWithdraw = type == 'pot_withdraw' || type == 'pot_close';

    double amount = (data['amount'] ?? 0).toDouble();
    String category = data['category'] ?? "General";
    String note = data['note'] ?? category;

    // Clean Note
    if (note.contains(":")) {
      note = note.split(":")[1].trim();
    } else if (note.startsWith("Paid to")) {
      note = note.replaceFirst("Paid to ", "");
    } else if (note.startsWith("Received from")) {
      note = note.replaceFirst("Received from ", "");
    }

    // Format Date
    String dateString = "Just now";
    if (data['date'] != null) {
      DateTime date = (data['date'] as Timestamp).toDate();
      dateString = "${date.day}/${date.month} • ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'pm' : 'am'}";
    }

    // Styles
    IconData icon;
    Color iconBgColor;
    Color iconColor;
    Color amountTextColor;
    String sign;

    if (isSelfTransfer) {
      icon = Icons.swap_horiz_rounded;
      iconColor = const Color(0xFF2E7D32);
      iconBgColor = const Color(0xFFE8F5E9);
      amountTextColor = Colors.black;
      sign = "";
    } else if (isPotDeposit) {
      icon = Icons.savings_rounded;
      iconColor = const Color(0xFF3F51B5);
      iconBgColor = const Color(0xFFE8EAF6);
      amountTextColor = Colors.red.shade700;
      sign = "-";
    } else if (isPotWithdraw) {
      icon = Icons.downloading_rounded;
      iconColor = const Color(0xFF1B5E20);
      iconBgColor = const Color(0xFFE8F5E9);
      amountTextColor = const Color(0xFF2E7D32);
      sign = "+";
    } else if (isExpense) {
      icon = _categoryIcons[category] ?? Icons.person_rounded;
      Color baseColor = _categoryColors[category] ?? const Color(0xFF3F51B5);
      if (_categoryColors.containsKey(category)) {
        iconColor = baseColor;
        iconBgColor = baseColor.withOpacity(0.1);
      } else {
        iconColor = const Color(0xFF3F51B5);
        iconBgColor = const Color(0xFFE8EAF6);
      }
      amountTextColor = Colors.red.shade700;
      sign = "-";
    } else {
      icon = Icons.downloading_rounded;
      iconBgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF1B5E20);
      amountTextColor = const Color(0xFF2E7D32);
      sign = "+";
    }

    // --- ADDED GESTURE DETECTOR HERE ---
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TransactionDetailsPage(
              transactionId: docId,
              data: data,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              height: 44, width: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(note, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(dateString, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Text(
              "$sign₹${amount.toStringAsFixed(0)}",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16,
                  color: amountTextColor
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildActionButton({required IconData icon, required String label, required VoidCallback onTap, bool isPrimary = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 60, width: 60,
            decoration: BoxDecoration(
              color: isPrimary ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: isPrimary ? null : Border.all(color: Colors.grey.shade200),
              boxShadow: isPrimary ? [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))] : [],
            ),
            child: Icon(icon, color: isPrimary ? Colors.white : Colors.black, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

// ... (_SecureAccountTile and _AccountSelectionSheet remain unchanged from previous versions)
// Just include the rest of the file content you already have.
class _SecureAccountTile extends StatefulWidget {
  final Map<String, dynamic> data;
  const _SecureAccountTile({required this.data});
  @override
  State<_SecureAccountTile> createState() => _SecureAccountTileState();
}

class _SecureAccountTileState extends State<_SecureAccountTile> {
  bool _isRevealed = false;

  Future<void> _checkMpinAndReveal() async {
    final bool? isVerified = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const MpinVerificationPage())
    );
    if (isVerified == true) {
      setState(() => _isRevealed = true);
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isRevealed = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String digits = widget.data['last4Digits'] ?? "";
    String displayName = widget.data['name'] ?? "Bank";
    if (digits.isNotEmpty) displayName += " •••• $digits";
    double balance = (widget.data['balance'] ?? 0).toDouble();

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Color(widget.data['color'] ?? 0xFF000000),
        child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 18),
      ),
      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(widget.data['type'] ?? "Account"),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRevealed ? "₹ $balance" : "••••••",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {
              if (_isRevealed) setState(() => _isRevealed = false);
              else _checkMpinAndReveal();
            },
            child: Icon(_isRevealed ? Icons.visibility_off : Icons.visibility, size: 20, color: Colors.grey),
          )
        ],
      ),
    );
  }
}

class _AccountSelectionSheet extends StatefulWidget {
  const _AccountSelectionSheet();

  @override
  State<_AccountSelectionSheet> createState() => _AccountSelectionSheetState();
}

class _AccountSelectionSheetState extends State<_AccountSelectionSheet> {
  String? _selectedDocId;
  Map<String, dynamic>? _selectedAccountData;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox();

    return Container(
      height: 600,
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: const BoxDecoration(
        color: Color(0xFF1F1F1F),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
                width: 50, height: 5,
                decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(10))
            ),
          ),
          const SizedBox(height: 25),

          const Text("Select Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 8),
          Text("Choose account to deposit to", style: TextStyle(color: Colors.grey[400], fontSize: 14)),
          const SizedBox(height: 25),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('accounts').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));
                var docs = snapshot.data!.docs;

                if (_selectedDocId == null && docs.isNotEmpty) {
                  var primaryAccounts = docs.where((d) => (d.data() as Map<String, dynamic>)['isPrimary'] == true).toList();
                  var targetDoc = primaryAccounts.isNotEmpty ? primaryAccounts.first : docs.first;

                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _selectedDocId = targetDoc.id;
                        _selectedAccountData = targetDoc.data() as Map<String, dynamic>;
                      });
                    }
                  });
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    var doc = docs[index];
                    var data = doc.data() as Map<String, dynamic>;
                    bool isSelected = _selectedDocId == doc.id;

                    String name = data['name'] ?? "Account";
                    String type = data['type'] ?? "Bank";
                    String digits = data['last4Digits'] ?? "";
                    if (digits.isNotEmpty) name += " • $digits";

                    Color cardColor = isSelected ? const Color(0xFF303030) : Colors.transparent;
                    Color borderColor = isSelected ? const Color(0xFF669DF6) : Colors.grey[800]!;
                    Color iconBg = const Color(0xFF404040);

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedDocId = doc.id;
                          _selectedAccountData = data;
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: borderColor, width: isSelected ? 2 : 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: iconBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                  type == 'Cash' ? Icons.wallet : Icons.account_balance,
                                  size: 22,
                                  color: Colors.white
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                                  const SizedBox(height: 4),
                                  Text(type.toUpperCase(), style: TextStyle(color: Colors.grey[400], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Color(0xFF669DF6), size: 28)
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF669DF6),
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              onPressed: () {
                if (_selectedDocId != null && _selectedAccountData != null) {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => AddIncomePage(
                          accountId: _selectedDocId!,
                          accountName: _selectedAccountData!['name'],
                          last4Digits: _selectedAccountData!['last4Digits'] ?? ""
                      ))
                  );
                }
              },
              child: const Text("Next", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}