import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';

import 'package:expense_tracker/features/auth/presentation/pages/mpin_verification_page.dart';

import 'package:expense_tracker/features/account/presentation/pages/add_bank_account_page.dart';

import 'package:expense_tracker/features/pots/presentation/pages/pots_dashboard_page.dart';

import 'package:expense_tracker/features/auth/presentation/pages/home_page.dart';

import 'package:expense_tracker/features/transactions/presentation/pages/transfers_page.dart';

import 'package:expense_tracker/features/profile/presentation/pages/profile_page.dart';
// =========================================================
// ====================  MAIN PAGE  ========================
// =========================================================

class MoneyPage extends StatefulWidget {
  final bool showBottomNavBar;

  const MoneyPage({super.key, this.showBottomNavBar = false});

  @override
  State<MoneyPage> createState() => _MoneyPageState();
}

class _MoneyPageState extends State<MoneyPage> {
  int _currentTabIndex = 0; // 0=Accounts, 1=Net Worth
  String? _selectedAccountId;
  bool _isSessionUnlocked = false;
  int _bottomNavIndex = 2;

  Future<void> _onAccountSelected(String? accountId) async {
    if (accountId == null) {
      setState(() => _selectedAccountId = null);
      return;
    }
    if (_isSessionUnlocked) {
      setState(() => _selectedAccountId = accountId);
    } else {
      final bool? isVerified = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MpinVerificationPage())
      );
      if (isVerified == true) {
        setState(() {
          _isSessionUnlocked = true;
          _selectedAccountId = accountId;
        });
      }
    }
  }

  void _onBottomNavTapped(int index) {
    if (index == _bottomNavIndex) return;

    setState(() => _bottomNavIndex = index);

    // FIX: Instead of pushing naked pages, we restart HomePage at the specific tab
    switch (index) {
      case 0: // Home
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 0)),
                (route) => false
        );
        break;
      case 1: // Transfers
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 1)),
                (route) => false
        );
        break;
      case 2: // Money (Stay here, do nothing)
        break;
      case 3: // You (Profile)
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomePage(initialIndex: 3)),
                (route) => false
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- HEADER ---
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Money", style: TextStyle(color: Color(0xFF163C46), fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: -0.5)),
                        _buildIconBtn(Icons.settings_outlined),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity, height: 48, padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          _buildTabItem("Accounts", 0),
                          _buildTabItem("Net Worth", 1),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // --- CONTENT ---
            if (_currentTabIndex == 0) ...[
              _buildAccountsView(user),
              SliverToBoxAdapter(child: _AnalysisSection(userUid: user?.uid)),
            ] else ...[
              _buildNetWorthView(user),
            ]
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNavBar
          ? BottomNavigationBar(
        currentIndex: 2,
        onTap: _onBottomNavTapped,
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
      )
          : null,
    );
  }

  Widget _buildAccountsView(User? user) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('accounts').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
          var docs = snapshot.data!.docs;
          double totalBalance = 0;
          for (var doc in docs) { totalBalance += ((doc.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble(); }

          double displayBalance = totalBalance;
          if (_selectedAccountId != null && docs.any((d) => d.id == _selectedAccountId)) {
            var selectedDoc = docs.firstWhere((d) => d.id == _selectedAccountId);
            displayBalance = ((selectedDoc.data() as Map<String, dynamic>)['balance'] ?? 0).toDouble();
          }

          return Column(
            children: [
              SizedBox(height: 45, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 24), children: [
                _buildFilterChip("All", Icons.account_balance_wallet, _selectedAccountId == null, Colors.black, () => _onAccountSelected(null)),
                ...docs.map((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  return _buildFilterChip(data['name'] ?? "Bank", Icons.account_balance, _selectedAccountId == doc.id, Color(data['color'] ?? 0xFF000000), () => _onAccountSelected(doc.id));
                }),
                GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBankAccountPage())), child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 16), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(24)), alignment: Alignment.center, child: const Text("Add accounts", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)))),
              ])),
              const SizedBox(height: 30),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("Total Balance", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.black54)),
                const SizedBox(height: 8),
                Row(children: [Text("₹${displayBalance.toStringAsFixed(2)}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.black, letterSpacing: -1)), const SizedBox(width: 8), const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.black)]),
                const SizedBox(height: 12),
                if (_selectedAccountId == null) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: docs.map((doc) { var data = doc.data() as Map<String, dynamic>; double bal = (data['balance'] ?? 0).toDouble(); return Container(margin: const EdgeInsets.only(right: 16), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 14, height: 14, decoration: BoxDecoration(color: Color(data['color'] ?? 0xFF000000), shape: BoxShape.circle), alignment: Alignment.center, child: Text((data['name'] ?? "B")[0], style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))), const SizedBox(width: 6), Text(_isSessionUnlocked ? "₹${bal.toStringAsFixed(1)}" : "••••", style: const TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500))])); }).toList())),
              ])),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNetWorthView(User? user) {
    return SliverToBoxAdapter(
      child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('accounts').snapshots(),
          builder: (context, accSnapshot) {
            return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('pots').snapshots(),
                builder: (context, potSnapshot) {
                  double totalBankBalance = 0; double totalCashBalance = 0; int bankCount = 0;
                  if (accSnapshot.hasData) {
                    for (var doc in accSnapshot.data!.docs) {
                      var data = doc.data() as Map<String, dynamic>;
                      double bal = (data['balance'] ?? 0).toDouble();
                      String type = (data['type'] ?? '').toString().toLowerCase();
                      String name = (data['name'] ?? '').toString().toLowerCase();
                      if (type == 'cash' || name.contains('cash')) { totalCashBalance += bal; } else { totalBankBalance += bal; bankCount++; }
                    }
                  }
                  double totalPotsBalance = 0; int potCount = 0;
                  if (potSnapshot.hasData) { for (var doc in potSnapshot.data!.docs) { totalPotsBalance += (doc.data() as Map<String, dynamic>)['currentAmount'] ?? 0; potCount++; } }
                  double totalNetWorth = totalBankBalance + totalCashBalance + totalPotsBalance;

                  return Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 10), const Text("Net Worth", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 4), Text("₹${totalNetWorth.toStringAsFixed(2)}", style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w400, color: Colors.black, letterSpacing: -1)), const SizedBox(height: 30),
                    _buildSectionHeader("Assets", "₹${totalNetWorth.toStringAsFixed(2)}"),
                    _buildAssetTile(Icons.account_balance, "Bank Balances", "₹${totalBankBalance.toStringAsFixed(2)}", "$bankCount accounts"), const Divider(height: 1),
                    _buildAssetTile(Icons.money, "Cash in Hand", "₹${totalCashBalance.toStringAsFixed(2)}", ""), const Divider(height: 1),
                    GestureDetector(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PotsDashboardPage())), child: Container(color: Colors.transparent, child: _buildAssetTile(Icons.savings_outlined, "Pots", "₹${totalPotsBalance.toStringAsFixed(2)}", "$potCount pots"))), const SizedBox(height: 40),
                  ]));
                }
            );
          }
      ),
    );
  }

  Widget _buildTabItem(String title, int index) {
    bool isSelected = _currentTabIndex == index;
    return Expanded(child: GestureDetector(onTap: () => setState(() => _currentTabIndex = index), child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(12), boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : []), child: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? Colors.black : Colors.grey[600], fontSize: 14)))));
  }
  Widget _buildFilterChip(String label, IconData icon, bool isSelected, Color color, VoidCallback onTap) { return GestureDetector(onTap: onTap, child: Container(margin: const EdgeInsets.only(right: 12), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4), decoration: BoxDecoration(color: isSelected ? const Color(0xFF212121) : Colors.white, borderRadius: BorderRadius.circular(30)), child: Row(children: [Container(height: 32, width: 32, decoration: BoxDecoration(color: isSelected ? Colors.white.withOpacity(0.2) : color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: isSelected ? Colors.white : color)), const SizedBox(width: 8), Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.w600, fontSize: 13)), const SizedBox(width: 12)]))); }
  Widget _buildIconBtn(IconData icon) { return Container(width: 40, height: 40, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300), color: Colors.white), child: Icon(icon, size: 20, color: Colors.black87)); }
  Widget _buildSectionHeader(String title, String amount) { return Container(padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)), Text(amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))])); }
  Widget _buildAssetTile(IconData icon, String title, String value, String subtitle) { return Padding(padding: const EdgeInsets.symmetric(vertical: 16.0), child: Row(children: [Icon(icon, color: Colors.grey[600], size: 22), const SizedBox(width: 16), Expanded(child: Text(title, style: const TextStyle(fontSize: 15, color: Colors.black87))), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)), if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey))]), const SizedBox(width: 8), const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)])); }
}

// =========================================================
// =============  ANALYSIS SECTION  ========================
// =========================================================

class _AnalysisSection extends StatefulWidget {
  final String? userUid;
  const _AnalysisSection({required this.userUid});

  @override
  State<_AnalysisSection> createState() => _AnalysisSectionState();
}

class _AnalysisSectionState extends State<_AnalysisSection> {
  int _selectedGraphTab = 0;
  int _selectedViewMode = 0;
  bool _showAllCategories = false;
  int? _selectedDayIndex;
  Offset? _touchPosition;
  DateTime _selectedDate = DateTime.now();
  int _selectedYear = DateTime.now().year;

  // --- 1. ICON MAP ---
  static final Map<String, IconData> _categoryIcons = {
    'Food & drinks': Icons.fastfood_rounded, 'Groceries': Icons.shopping_basket_rounded, 'Fuel': Icons.local_gas_station_rounded,
    'Shopping': Icons.shopping_bag_rounded, 'Entertainment': Icons.movie_filter_rounded, 'Bills': Icons.lightbulb_rounded,
    'Commute': Icons.directions_car_rounded, 'Rent': Icons.home_rounded, 'Medical': Icons.medical_services_rounded,
    'Education': Icons.school_rounded, 'Pets': Icons.pets_rounded, 'Personal': Icons.face_rounded, 'Tools': Icons.build_circle_rounded,
    'Travel': Icons.flight_takeoff_rounded, 'Fees': Icons.receipt_long_rounded, 'Gifts': Icons.card_giftcard_rounded,
    'Random': Icons.shuffle_rounded, 'Transfer': Icons.person_rounded,
  };

  // --- 2. COLOR MAP ---
  static final Map<String, Color> _categoryColors = {
    'Food & drinks': const Color(0xFF000000), 'Groceries': const Color(0xFF2EC4B6), 'Fuel': const Color(0xFFE71D36), 'Shopping': const Color(0xFF9D4EDD),
    'Entertainment': const Color(0xFFFF006E), 'Bills': const Color(0xFFFFBE0B), 'Commute': const Color(0xFF3A86FF), 'Rent': const Color(0xFF06D6A0),
    'Medical': const Color(0xFFEF476F), 'Education': const Color(0xFF118AB2), 'Pets': const Color(0xFF8D5B4C), 'Personal': const Color(0xFFFF5400),
    'Tools': const Color(0xFF607D8B), 'Travel': const Color(0xFF00B4D8), 'Fees': const Color(0xFF9E9E9E), 'Gifts': const Color(0xFFFF7096),
    'Random': const Color(0xFF607D8B), 'Transfer': const Color(0xFF3F51B5),
  };

  void _changeDate(int offset) {
    setState(() {
      _selectedDayIndex = null; _touchPosition = null;
      if (_selectedViewMode == 0) _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      else _selectedYear += offset;
    });
  }

  String get _budgetDocId => "${_selectedDate.year}_${_selectedDate.month.toString().padLeft(2, '0')}";

  Future<void> _showBudgetDialog(BuildContext context, double currentBudget) async {
    TextEditingController controller = TextEditingController(text: currentBudget > 0 ? currentBudget.toStringAsFixed(0) : '');
    return showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Update Budget", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A1A2E))), GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: Colors.grey))]),
              const SizedBox(height: 24),
              TextField(controller: controller, keyboardType: TextInputType.number, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), decoration: InputDecoration(labelText: "Enter amount", prefixText: "₹ ", filled: true, fillColor: Colors.grey[50], border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () async { double? newAmount = double.tryParse(controller.text.replaceAll(',', '')); if (newAmount != null) { await FirebaseFirestore.instance.collection('users').doc(widget.userUid).collection('budgets').doc(_budgetDocId).set({'amount': newAmount}); } if (mounted) Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE57373), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)))),
              const SizedBox(height: 16),
              Center(child: GestureDetector(onTap: () async { await FirebaseFirestore.instance.collection('users').doc(widget.userUid).collection('budgets').doc(_budgetDocId).delete(); if (mounted) Navigator.pop(context); }, child: Text("Remove ${_getMonthName(_selectedDate.month)}'s Budget", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.w500, decoration: TextDecoration.underline, decorationColor: Colors.grey[400])))),
              const SizedBox(height: 10),
            ]),
          ),
        );
      },
    );
  }

  // --- 3. CATEGORY STYLE HELPER (UPDATED LOGIC) ---
  Map<String, dynamic> _getCategoryStyle(String category, int tabIndex) {
    // A. INVESTED TAB (Tab 1) -> Pot Deposits
    if (tabIndex == 1) {
      return {
        'icon': Icons.savings_rounded,
        'color': const Color(0xFF3F51B5), // Indigo
        'bgColor': const Color(0xFFE8EAF6),
        'textColor': Colors.red.shade700 // Negative sign logic
      };
    }

    // B. INCOME TAB (Tab 2) -> Income or Withdraw
    if (tabIndex == 2) {
      return {
        'icon': Icons.downloading_rounded,
        'color': const Color(0xFF1B5E20), // Dark Green
        'bgColor': const Color(0xFFE8F5E9),
        'textColor': const Color(0xFF2E7D32) // Positive Green
      };
    }

    // C. SPENDS TAB (Tab 0)

    // Check for Self Transfer (excluded)
    if (category == 'Self transfers') {
      return {
        'icon': Icons.swap_horiz_rounded,
        'color': const Color(0xFF2E7D32),
        'bgColor': const Color(0xFFE8F5E9),
        'textColor': Colors.black
      };
    }

    // Check for Expense Categories from Map
    if (_categoryIcons.containsKey(category)) {
      Color baseColor = _categoryColors[category]!;
      return {
        'icon': _categoryIcons[category],
        'color': baseColor,
        'bgColor': baseColor.withOpacity(0.1),
        'textColor': Colors.red.shade700 // Expense
      };
    }

    // Fallback Expense
    return {
      'icon': Icons.category_rounded,
      'color': Colors.grey,
      'bgColor': Colors.grey.withOpacity(0.1),
      'textColor': Colors.red.shade700
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.userUid == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(widget.userUid).collection('transactions').orderBy('date', descending: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 250, child: Center(child: CircularProgressIndicator()));
        var docs = snapshot.data!.docs;

        return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(widget.userUid).collection('budgets').doc(_budgetDocId).snapshots(),
            builder: (context, budgetSnapshot) {
              double budgetAmount = 0;
              if (budgetSnapshot.hasData && budgetSnapshot.data!.exists) {
                budgetAmount = (budgetSnapshot.data!.data() as Map<String, dynamic>)['amount']?.toDouble() ?? 0;
              }

              Map<int, double> dailySpends = {}; Map<int, double> dailyInvested = {}; Map<int, double> dailyIncome = {};
              Map<int, double> lastMonthDailySpends = {}; Map<int, double> lastMonthDailyInvested = {}; Map<int, double> lastMonthDailyIncome = {};
              Map<String, double> categoryBreakdown = {};

              double totalSpendsMonth = 0; double totalInvestedMonth = 0; double totalIncomeMonth = 0;
              double totalSpendsLastMonth = 0; double totalInvestedLastMonth = 0; double totalIncomeLastMonth = 0;
              double excludedTotal = 0;

              Map<int, double> monthlySpendsCurrentYear = {}; Map<int, double> monthlySpendsLastYear = {};
              for(int i=1; i<=12; i++) { monthlySpendsCurrentYear[i] = 0.0; monthlySpendsLastYear[i] = 0.0; }
              for (int i = 1; i <= 31; i++) { dailySpends[i] = 0.0; dailyInvested[i] = 0.0; dailyIncome[i] = 0.0; lastMonthDailySpends[i] = 0.0; lastMonthDailyInvested[i] = 0.0; lastMonthDailyIncome[i] = 0.0; }

              DateTime now = DateTime.now();
              DateTime lastMonthDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);

              for (var doc in docs) {
                var data = doc.data() as Map<String, dynamic>;
                Timestamp? ts = data['date']; if (ts == null) continue;
                DateTime date = ts.toDate();
                double amount = (data['amount'] ?? 0).toDouble();
                String type = data['type'] ?? '';
                String category = data['category'] ?? 'Uncategorised';

                bool isExpense = type == 'expense';
                bool isInvest = type == 'pot_deposit';
                bool isIncome = type == 'income';
                bool isPotWithdraw = type == 'pot_withdraw';
                bool isTransfer = type == 'self_transfer';

                if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
                  if (isExpense) {
                    dailySpends[date.day] = (dailySpends[date.day] ?? 0) + amount;
                    totalSpendsMonth += amount;
                    if (_selectedGraphTab == 0) categoryBreakdown[category] = (categoryBreakdown[category] ?? 0) + amount;
                  }
                  else if (isInvest) {
                    dailyInvested[date.day] = (dailyInvested[date.day] ?? 0) + amount;
                    totalInvestedMonth += amount;
                    if (_selectedGraphTab == 1) { String name = data['note'] ?? "Pot Deposit"; categoryBreakdown[name] = (categoryBreakdown[name] ?? 0) + amount; }
                  }
                  else if (isIncome || isPotWithdraw) {
                    dailyIncome[date.day] = (dailyIncome[date.day] ?? 0) + amount;
                    totalIncomeMonth += amount;
                    if (_selectedGraphTab == 2) {
                      String label = isPotWithdraw ? "Withdraw from Pots" : category;
                      categoryBreakdown[label] = (categoryBreakdown[label] ?? 0) + amount;
                    }
                  }
                  if (isTransfer) excludedTotal += amount;
                }
                if (date.year == lastMonthDate.year && date.month == lastMonthDate.month) {
                  if (isExpense) { lastMonthDailySpends[date.day] = (lastMonthDailySpends[date.day] ?? 0) + amount; totalSpendsLastMonth += amount; }
                  else if (isInvest) { lastMonthDailyInvested[date.day] = (lastMonthDailyInvested[date.day] ?? 0) + amount; totalInvestedLastMonth += amount; }
                  else if (isIncome || isPotWithdraw) { lastMonthDailyIncome[date.day] = (lastMonthDailyIncome[date.day] ?? 0) + amount; totalIncomeLastMonth += amount; }
                }

                if (date.year == _selectedYear) {
                  if (isExpense && _selectedGraphTab==0) monthlySpendsCurrentYear[date.month] = (monthlySpendsCurrentYear[date.month] ?? 0) + amount;
                  else if (isInvest && _selectedGraphTab==1) monthlySpendsCurrentYear[date.month] = (monthlySpendsCurrentYear[date.month] ?? 0) + amount;
                  else if ((isIncome || isPotWithdraw) && _selectedGraphTab==2) monthlySpendsCurrentYear[date.month] = (monthlySpendsCurrentYear[date.month] ?? 0) + amount;
                } else if (date.year == _selectedYear - 1) {
                  if (isExpense && _selectedGraphTab==0) monthlySpendsLastYear[date.month] = (monthlySpendsLastYear[date.month] ?? 0) + amount;
                  else if (isInvest && _selectedGraphTab==1) monthlySpendsLastYear[date.month] = (monthlySpendsLastYear[date.month] ?? 0) + amount;
                  else if ((isIncome || isPotWithdraw) && _selectedGraphTab==2) monthlySpendsLastYear[date.month] = (monthlySpendsLastYear[date.month] ?? 0) + amount;
                }
              }

              Map<int, double> activeDailyMap; Map<int, double> activeLastMonthMap; double activeCurrentTotal; double activeLastMonthTotal; String graphTitle;
              switch (_selectedGraphTab) {
                case 1: activeDailyMap = dailyInvested; activeLastMonthMap = lastMonthDailyInvested; activeCurrentTotal = totalInvestedMonth; activeLastMonthTotal = totalInvestedLastMonth; graphTitle = "Invested Trend"; break;
                case 2: activeDailyMap = dailyIncome; activeLastMonthMap = lastMonthDailyIncome; activeCurrentTotal = totalIncomeMonth; activeLastMonthTotal = totalIncomeLastMonth; graphTitle = "Income Trend"; break;
                case 0: default: activeDailyMap = dailySpends; activeLastMonthMap = lastMonthDailySpends; activeCurrentTotal = totalSpendsMonth; activeLastMonthTotal = totalSpendsLastMonth; graphTitle = "Spends Trend"; break;
              }

              bool isOverBudget = false; Color statusColor = Colors.green; Color graphLineColor = const Color(0xFF163C46);
              if (_selectedGraphTab == 0 && budgetAmount > 0) { if (activeCurrentTotal > budgetAmount) { isOverBudget = true; statusColor = Colors.red; graphLineColor = Colors.red; } }

              List<double> chartData = []; List<double> lastMonthChartData = []; double runningTotal = 0; double lastMonthRunningTotal = 0; double maxDataValue = 0;
              int daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
              for (int i = 1; i <= daysInMonth; i++) { if (_isCurrentMonth(_selectedDate) && i > now.day) break; runningTotal += activeDailyMap[i]!; chartData.add(runningTotal); if (runningTotal > maxDataValue) maxDataValue = runningTotal; }
              for (int i = 1; i <= 31; i++) { lastMonthRunningTotal += activeLastMonthMap[i]!; lastMonthChartData.add(lastMonthRunningTotal); if (lastMonthRunningTotal > maxDataValue) maxDataValue = lastMonthRunningTotal; }
              if (_selectedGraphTab == 0 && budgetAmount > maxDataValue) maxDataValue = budgetAmount;
              if (maxDataValue == 0) maxDataValue = 1000;

              var sortedEntries = categoryBreakdown.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
              bool showExpandButton = _selectedGraphTab == 0 && sortedEntries.length > 5;
              int itemCount = (_selectedGraphTab != 0 || _showAllCategories) ? sortedEntries.length : (sortedEntries.length > 5 ? 5 : sortedEntries.length);

              return Container(
                  width: double.infinity, margin: const EdgeInsets.only(top: 10),
                  decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SizedBox(height: 10),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeDate(-1)),
                      Text(_selectedViewMode == 0 ? "${_getMonthName(_selectedDate.month)} ${_selectedDate.year}" : "${_selectedYear}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: (_selectedViewMode == 0 && _isCurrentMonth(_selectedDate)) || (_selectedViewMode == 1 && _selectedYear == now.year) ? null : () => _changeDate(1)),
                    ])),

                    StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('users').doc(widget.userUid).collection('pots').snapshots(),
                        builder: (context, potSnapshot) {
                          double investedAmount = 0;
                          if (potSnapshot.hasData) { for (var doc in potSnapshot.data!.docs) { investedAmount += (doc.data() as Map<String, dynamic>)['currentAmount'] ?? 0; } }
                          if (_isCurrentMonth(_selectedDate)) totalInvestedMonth = investedAmount;

                          return Container(
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 10), padding: const EdgeInsets.all(4), height: 60,
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
                            child: Row(children: [
                              Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGraphTab = 0), child: Container(decoration: BoxDecoration(color: _selectedGraphTab == 0 ? const Color(0xFF1A1A2E) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: _buildStatItem("Spends", "₹${_compactAmount(totalSpendsMonth)}", _selectedGraphTab == 0)))),
                              Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGraphTab = 1), child: Container(decoration: BoxDecoration(color: _selectedGraphTab == 1 ? const Color(0xFF1A1A2E) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: _buildStatItem("Invested", "₹${_compactAmount(totalInvestedMonth)}", _selectedGraphTab == 1)))),
                              Expanded(child: GestureDetector(onTap: () => setState(() => _selectedGraphTab = 2), child: Container(decoration: BoxDecoration(color: _selectedGraphTab == 2 ? const Color(0xFF1A1A2E) : Colors.transparent, borderRadius: BorderRadius.circular(12)), child: _buildStatItem("Incoming", "₹${_compactAmount(totalIncomeMonth)}", _selectedGraphTab == 2)))),
                            ]),
                          );
                        }
                    ),

                    const SizedBox(height: 10),

                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text("This month so far", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 4),
                        if (_selectedGraphTab == 0 && budgetAmount > 0 && _selectedViewMode == 0) ...[
                          Row(children: [RichText(text: TextSpan(style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), children: [TextSpan(text: "₹${_compactAmount(activeCurrentTotal)}", style: TextStyle(color: statusColor)), TextSpan(text: " / ₹${_compactAmount(budgetAmount)}", style: const TextStyle(color: Colors.black))])), const SizedBox(width: 8), GestureDetector(onTap: _isCurrentMonth(_selectedDate) ? () => _showBudgetDialog(context, budgetAmount) : null, child: Icon(Icons.edit, size: 16, color: _isCurrentMonth(_selectedDate) ? Colors.black : Colors.grey))])
                        ] else ...[
                          RichText(text: TextSpan(style: const TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold), children: [TextSpan(text: "₹${_compactAmount(activeCurrentTotal)}"), if (_selectedGraphTab == 0 && budgetAmount == 0 && _selectedViewMode == 0 && _isCurrentMonth(_selectedDate)) WidgetSpan(child: GestureDetector(onTap: () => _showBudgetDialog(context, 0), child: Padding(padding: const EdgeInsets.only(left:8.0), child: Icon(Icons.add_circle_outline, size: 16, color: Colors.grey))))]))
                        ]
                      ]),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(_selectedViewMode == 0 ? "Last month" : "${_getMonthName(_selectedDate.month).substring(0, 3)} ${_selectedYear - 1}", style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 4),
                        Text("₹${_compactAmount(activeLastMonthTotal)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ]),
                    ])),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 250,
                          width: double.infinity,
                          child: _selectedViewMode == 0
                              ? LayoutBuilder(builder: (context, constraints) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanDown: (details) => _updateTouch(details.localPosition, constraints.maxWidth, chartData.length),
                              onPanUpdate: (details) => _updateTouch(details.localPosition, constraints.maxWidth, chartData.length),
                              onPanEnd: (_) => setState(() { _selectedDayIndex = null; _touchPosition = null; }),
                              child: RepaintBoundary(child: CustomPaint(painter: _InteractiveChartPainter(
                                  dataPoints: chartData,
                                  lastMonthDataPoints: lastMonthChartData,
                                  dailySpends: activeDailyMap,
                                  selectedIndex: _selectedDayIndex,
                                  touchX: _touchPosition?.dx,
                                  lineColor: graphLineColor,
                                  maxDataValue: maxDataValue,
                                  monthName: _getMonthName(_selectedDate.month).substring(0,3),
                                  prevMonthName: _getMonthName(lastMonthDate.month).substring(0,3),
                                  chartLabel: _selectedGraphTab == 0 ? "Spends" : (_selectedGraphTab == 1 ? "Invested" : "Income"),
                                  budgetAmount: (_selectedGraphTab == 0) ? budgetAmount : 0
                              ))),
                            );
                          })
                              : RepaintBoundary(child: CustomPaint(painter: _MonthlyBarChartPainter(currentYearData: monthlySpendsCurrentYear, lastYearData: monthlySpendsLastYear))),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 20),

                    Center(child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: Colors.black, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisSize: MainAxisSize.min, children: [_buildViewModeBtn("Daily", 0), _buildViewModeBtn("Monthly", 1)]))),
                    const SizedBox(height: 30), const Divider(), const SizedBox(height: 20),

                    Padding(padding: const EdgeInsets.symmetric(horizontal: 24.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(_selectedGraphTab == 0 ? "Total spends in ${_getMonthName(_selectedDate.month)}" : (_selectedGraphTab == 1 ? "Total invested" : "Total income"), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)), Text("₹${activeCurrentTotal.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15))]),
                      const SizedBox(height: 20),

                      if (categoryBreakdown.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(20), child: Text("No data available", style: TextStyle(color: Colors.grey)))),

                      ...sortedEntries.take(itemCount).map((entry) {
                        double percentage = activeCurrentTotal > 0 ? (entry.value / activeCurrentTotal * 100) : 0;
                        var style = _getCategoryStyle(entry.key, _selectedGraphTab);
                        return _buildCategoryTile(entry.key, entry.value, percentage, style);
                      }),

                      if (showExpandButton) ...[
                        const SizedBox(height: 16),
                        SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () { setState(() { _showAllCategories = !_showAllCategories; }); }, style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), padding: const EdgeInsets.symmetric(vertical: 12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_showAllCategories ? "Show less" : "Show more", style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), Icon(_showAllCategories ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.black, size: 18)])))
                      ],

                      const SizedBox(height: 30),
                      if (_selectedGraphTab == 0) ...[Text("Not included in Spends", style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)), const SizedBox(height: 16), _buildExcludedTile("Self transfers", excludedTotal)]
                    ])),
                    const SizedBox(height: 40),
                  ],
                  ));
              }
        );
      },
    );
  }

  bool _isCurrentMonth(DateTime date) => date.year == DateTime.now().year && date.month == DateTime.now().month;
  String _getMonthName(int month) { const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]; return months[month - 1]; }
  void _updateTouch(Offset localPosition, double width, int dataLength) { if (dataLength == 0) return; double stepX = width / (dataLength > 1 ? dataLength - 1 : 1); int index = (localPosition.dx / stepX).round().clamp(0, dataLength - 1); if (_selectedDayIndex != index) { setState(() { _selectedDayIndex = index; _touchPosition = localPosition; }); } }

  Widget _buildCategoryTile(String category, double amount, double percentage, Map<String, dynamic> style) {
    return Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
            children: [
              Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: style['bgColor'], borderRadius: BorderRadius.circular(8)),
                  child: Icon(style['icon'], size: 18, color: style['color'])
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(category, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
              Text("${percentage.toStringAsFixed(0)}%", style: TextStyle(fontSize: 13, color: Colors.grey[500])),
              const SizedBox(width: 24),
              Text("₹${amount.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: style['textColor']))
            ]
        )
    );
  }

  Widget _buildExcludedTile(String title, double amount) { return Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.swap_horiz_rounded, size: 18, color: Color(0xFF2E7D32))), const SizedBox(width: 12), Expanded(child: Text(title, style: TextStyle(fontSize: 14, color: Colors.grey[700]))), Text("₹${amount.toStringAsFixed(0)}", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[500]))]); }
  Widget _buildStatItem(String label, String value, bool isSelected) { Color textColor = isSelected ? Colors.white : Colors.black; Color subTextColor = isSelected ? Colors.grey[400]! : Colors.grey[600]!; return Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: TextStyle(fontSize: 11, color: subTextColor)), Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: textColor))]); }
  Widget _buildViewModeBtn(String text, int index) { bool isSelected = _selectedViewMode == index; return GestureDetector(onTap: () => setState(() => _selectedViewMode = index), child: AnimatedContainer(duration: const Duration(milliseconds: 200), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), decoration: BoxDecoration(color: isSelected ? Colors.black : Colors.transparent, borderRadius: BorderRadius.circular(16)), child: Text(text, style: TextStyle(color: isSelected ? Colors.white : Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)))); }
  String _compactAmount(double amount) { if (amount >= 1000) return "${(amount / 1000).toStringAsFixed(1)}K"; return amount.toStringAsFixed(0); }
}

class _InteractiveChartPainter extends CustomPainter {
  final List<double> dataPoints; final List<double> lastMonthDataPoints; final Map<int, double> dailySpends; final int? selectedIndex; final double? touchX; final Color lineColor; final double maxDataValue; final String monthName; final String prevMonthName; final String chartLabel; final double budgetAmount;
  _InteractiveChartPainter({required this.dataPoints, required this.lastMonthDataPoints, required this.dailySpends, required this.selectedIndex, required this.touchX, required this.lineColor, required this.maxDataValue, required this.monthName, required this.prevMonthName, required this.chartLabel, required this.budgetAmount});

  @override
  void paint(Canvas canvas, Size size) {
    if (dataPoints.isEmpty && budgetAmount == 0) return;
    final double w = size.width - 40; final double h = size.height; final double chartH = h - 30;
    final paintLine = Paint()..color = lineColor..strokeWidth = 3.0..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final paintFill = Paint()..style = PaintingStyle.fill..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, chartH), [lineColor.withOpacity(0.2), lineColor.withOpacity(0.0)]);
    double maxVal = maxDataValue * 1.1; if (maxVal == 0) maxVal = 100;
    double stepX = w / (dataPoints.isNotEmpty ? (dataPoints.length > 1 ? dataPoints.length - 1 : 1) : 1);

    if (budgetAmount > 0 && chartLabel == "Spends" && budgetAmount <= maxVal) {
      double budgetY = chartH - (budgetAmount / maxVal * chartH);
      Paint budgetPaint = Paint()..color = Colors.blue..strokeWidth = 1.5..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(0, budgetY), Offset(w, budgetY), budgetPaint);
      TextPainter(text: TextSpan(style: TextStyle(color: Colors.blue, fontSize: 10, fontWeight: FontWeight.bold), text: "${(budgetAmount/1000).toStringAsFixed(1)}K"), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, Offset(w + 5, budgetY - 6));
    }

    final textStyle = TextStyle(color: Colors.grey, fontSize: 10);
    for (int i = 1; i <= 4; i++) {
      double value = maxVal / 4 * i; double y = chartH - (chartH / 4 * i);
      canvas.drawLine(Offset(0, y), Offset(w, y), Paint()..color = Colors.grey.withOpacity(0.2)..strokeWidth = 1);
      String label = (value >= 1000) ? "${(value/1000).toStringAsFixed(1)}K" : value.toStringAsFixed(0);
      TextPainter(text: TextSpan(style: textStyle, text: label), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, Offset(w + 5, y - 6));
    }

    if (dataPoints.isEmpty) return;
    final path = Path(); final fillPath = Path();
    path.moveTo(0, chartH - (dataPoints[0] / maxVal * chartH)); fillPath.moveTo(0, chartH); fillPath.lineTo(0, chartH - (dataPoints[0] / maxVal * chartH));
    for (int i = 0; i < dataPoints.length - 1; i++) {
      double x1 = i * stepX; double y1 = chartH - (dataPoints[i] / maxVal * chartH); double x2 = (i + 1) * stepX; double y2 = chartH - (dataPoints[i + 1] / maxVal * chartH);
      path.cubicTo(x1 + stepX / 2, y1, x1 + stepX / 2, y2, x2, y2); fillPath.cubicTo(x1 + stepX / 2, y1, x1 + stepX / 2, y2, x2, y2);
    }
    fillPath.lineTo((dataPoints.length - 1) * stepX, chartH); fillPath.close(); canvas.drawPath(fillPath, paintFill); canvas.drawPath(path, paintLine);

    List<String> labels = ["1", "15", "30"]; List<double> labelX = [0, w/2, w - 10];
    for(int i=0; i<labels.length; i++) { TextPainter(text: TextSpan(style: TextStyle(color: Colors.grey, fontSize: 11), text: "${labels[i]} $monthName"), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, Offset(labelX[i], chartH + 10)); }

    if (selectedIndex != null && selectedIndex! < dataPoints.length) {
      double x = selectedIndex! * stepX; double y = chartH - (dataPoints[selectedIndex!] / maxVal * chartH);
      Paint dashedPaint = Paint()..color = Colors.green..strokeWidth = 1.5..style = PaintingStyle.stroke;
      double startY = y; while (startY < chartH) { canvas.drawLine(Offset(x, startY), Offset(x, startY + 4), dashedPaint); startY += 8; }
      canvas.drawCircle(Offset(x, y), 5, Paint()..color = Colors.green); canvas.drawCircle(Offset(x, y), 3, Paint()..color = Colors.white);

      double boxW = 220; double boxH = 90; double boxX = x - boxW / 2; double boxY = y - 110;
      if (boxX < 0) boxX = 10; if (boxX + boxW > w) boxX = w - boxW - 10; if (boxY < 0) boxY = y + 20;
      RRect boxRect = RRect.fromRectAndRadius(Rect.fromLTWH(boxX, boxY, boxW, boxH), const Radius.circular(12));
      canvas.drawRRect(boxRect, Paint()..color = const Color(0xFF1A1A2E)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)); canvas.drawRRect(boxRect, Paint()..color = const Color(0xFF1A1A2E));

      int day = selectedIndex! + 1; double currentTotal = dataPoints[selectedIndex!]; double daily = dailySpends[day] ?? 0;
      double lastMonthVal = (selectedIndex! < lastMonthDataPoints.length) ? lastMonthDataPoints[selectedIndex!] : (lastMonthDataPoints.isNotEmpty ? lastMonthDataPoints.last : 0);

      _drawText(canvas, chartLabel, Offset(boxX + 12, boxY + 10), fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold);
      canvas.drawCircle(Offset(boxX + 16, boxY + 32), 4, Paint()..color = Colors.green); _drawText(canvas, "1 $monthName - $day $monthName", Offset(boxX + 26, boxY + 26), fontSize: 10, color: Colors.grey); _drawText(canvas, "₹${currentTotal.toStringAsFixed(0)}", Offset(boxX + 130, boxY + 26), fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white);
      canvas.drawCircle(Offset(boxX + 16, boxY + 52), 4, Paint()..color = Colors.white); _drawText(canvas, "1 $prevMonthName - $day $prevMonthName", Offset(boxX + 26, boxY + 46), fontSize: 10, color: Colors.grey); _drawText(canvas, "₹${lastMonthVal.toStringAsFixed(0)}", Offset(boxX + 130, boxY + 46), fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white);
      canvas.drawLine(Offset(boxX + 170, boxY + 10), Offset(boxX + 170, boxY + 80), Paint()..color = Colors.grey.withOpacity(0.3));
      _drawText(canvas, "On $day $monthName", Offset(boxX + 175, boxY + 26), fontSize: 9, color: Colors.grey); _drawText(canvas, "₹${daily.toStringAsFixed(0)}", Offset(boxX + 175, boxY + 40), fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white);
    }
  }
  void _drawText(Canvas canvas, String text, Offset pos, {double fontSize = 12, Color color = Colors.black, FontWeight fontWeight = FontWeight.normal}) { TextPainter(text: TextSpan(style: TextStyle(color: color, fontSize: fontSize, fontWeight: fontWeight), text: text), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, pos); }
  @override bool shouldRepaint(covariant _InteractiveChartPainter oldDelegate) => true;
}

class _MonthlyBarChartPainter extends CustomPainter {
  final Map<int, double> currentYearData; final Map<int, double> lastYearData;
  _MonthlyBarChartPainter({required this.currentYearData, required this.lastYearData});

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width - 40; final double h = size.height; final double chartH = h - 30;
    double maxVal = 0; currentYearData.forEach((k,v) { if(v > maxVal) maxVal = v; }); lastYearData.forEach((k,v) { if(v > maxVal) maxVal = v; });
    if(maxVal == 0) maxVal = 1000; maxVal *= 1.1;

    final textStyle = TextStyle(color: Colors.grey, fontSize: 10);
    for (int i = 1; i <= 4; i++) {
      double value = maxVal / 4 * i; double y = chartH - (chartH / 4 * i);
      canvas.drawLine(Offset(0, y), Offset(w, y), Paint()..color = Colors.grey.withOpacity(0.2)..strokeWidth = 1);
      String label = (value >= 1000) ? "${(value/1000).toStringAsFixed(1)}K" : value.toStringAsFixed(0);
      TextPainter(text: TextSpan(style: textStyle, text: label), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, Offset(w + 5, y - 6));
    }

    double barWidth = (w / 12) * 0.3; double spacing = (w / 12);
    for (int i = 1; i <= 12; i++) {
      double xCenter = (i - 1) * spacing + (spacing / 2);
      double lastH = (lastYearData[i]! / maxVal) * chartH;
      if (lastH > 0) { RRect lastRect = RRect.fromRectAndRadius(Rect.fromLTWH(xCenter - barWidth, chartH - lastH, barWidth, lastH), Radius.circular(4)); canvas.drawRRect(lastRect, Paint()..color = Colors.grey[300]!); }
      double currH = (currentYearData[i]! / maxVal) * chartH;
      if (currH > 0) { RRect currRect = RRect.fromRectAndRadius(Rect.fromLTWH(xCenter, chartH - currH, barWidth, currH), Radius.circular(4)); canvas.drawRRect(currRect, Paint()..color = Color(0xFF163C46)); }
      if (i % 2 != 0) { String monthName = DateFormat('MMM').format(DateTime(2024, i, 1)); TextPainter(text: TextSpan(style: textStyle, text: monthName), textDirection: ui.TextDirection.ltr)..layout()..paint(canvas, Offset(xCenter - 10, chartH + 10)); }
    }
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}