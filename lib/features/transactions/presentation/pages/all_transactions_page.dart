import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'transaction_details_page.dart';
import '../../../../features/money/presentation/pages/money_page.dart';

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedAccountId;

  // --- 1. ICON MAP (Added) ---
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

  // --- 2. COLOR MAP (Added for consistent styling) ---
  static final Map<String, Color> _categoryColors = {
    'Food & drinks': const Color(0xFF000000),
    'Groceries': const Color(0xFF2EC4B6),
    'Fuel': const Color(0xFFE71D36),
    'Shopping': const Color(0xFF9D4EDD),
    'Entertainment': const Color(0xFFFF006E),
    'Bills': const Color(0xFFFFBE0B),
    'Commute': const Color(0xFF3A86FF),
    'Rent': const Color(0xFF06D6A0),
    'Medical': const Color(0xFFEF476F),
    'Education': const Color(0xFF118AB2),
    'Pets': const Color(0xFF8D5B4C),
    'Personal': const Color(0xFFFF5400),
    'Tools': const Color(0xFF607D8B),
    'Travel': const Color(0xFF00B4D8),
    'Fees': const Color(0xFF9E9E9E),
    'Gifts': const Color(0xFFFF7096),
    'Random': const Color(0xFF607D8B),
    'Transfer': const Color(0xFF3F51B5),
  };

  void _changeMonth(int offset) {
    setState(() {
      DateTime newDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
      // Prevent future month selection
      if (newDate.isAfter(DateTime.now())) return;
      _selectedDate = newDate;
    });
  }

  String _formatGroupDate(DateTime date) => DateFormat('EEE, d MMM yyyy').format(date);
  String _formatTime(DateTime date) => DateFormat('h:mm a').format(date).toLowerCase();

  bool _isCurrentMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),

      // --- HEADER (CENTERED) ---
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        elevation: 0,
        centerTitle: true, // Centered Title
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            const Text("All transactions", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
                "Few minutes ago • ${DateFormat('h:mm a').format(DateTime.now())}",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11)
            ),
          ],
        ),
        // Removed actions (Filter Icon)
      ),

      body: Column(
        children: [
          Container(
            color: const Color(0xFF1A1A2E),
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                // Account Chips
                SizedBox(
                  height: 40,
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user?.uid).collection('accounts').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const SizedBox();
                      var accounts = snapshot.data!.docs;

                      return ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: [
                          _buildFilterChip("All", null),
                          ...accounts.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;
                            return _buildFilterChip(data['name'] ?? "Bank", doc.id);
                          }),
                          _buildAddAccountChip(),
                        ],
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Month Navigator (Restricted Forward)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left, color: Colors.white), onPressed: () => _changeMonth(-1)),
                      Text(DateFormat('MMMM yyyy').format(_selectedDate), style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                      IconButton(
                          icon: Icon(Icons.chevron_right, color: _isCurrentMonth(_selectedDate) ? Colors.grey : Colors.white),
                          onPressed: _isCurrentMonth(_selectedDate) ? null : () => _changeMonth(1)
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- LIST ---
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('transactions')
                  .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth))
                  .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return _buildEmptyState();

                var docs = snapshot.data!.docs;
                if (_selectedAccountId != null) {
                  docs = docs.where((d) => (d.data() as Map<String, dynamic>)['accountId'] == _selectedAccountId).toList();
                }
                if (docs.isEmpty) return _buildEmptyState();

                Map<String, List<DocumentSnapshot>> groupedTransactions = {};
                for (var doc in docs) {
                  DateTime date = (doc['date'] as Timestamp).toDate();
                  String dateKey = _formatGroupDate(date);
                  if (groupedTransactions[dateKey] == null) groupedTransactions[dateKey] = [];
                  groupedTransactions[dateKey]!.add(doc);
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MoneyPage(showBottomNavBar: true))),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: Row(
                          children: [
                            const Icon(Icons.pie_chart, color: Colors.orangeAccent),
                            const SizedBox(width: 12),
                            const Expanded(child: Text("Track your monthly cashflow", style: TextStyle(fontWeight: FontWeight.w500))),
                            Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey[400]),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),



                    ...groupedTransactions.entries.map((entry) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(entry.key, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          ...entry.value.map((doc) {
                            var data = doc.data() as Map<String, dynamic>;

                            // FIX: Pass doc.id as the first argument
                            return _buildTransactionItem(doc.id, data);
                          }),
                          const SizedBox(height: 10),
                        ],
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String? accountId) {
    bool isSelected = _selectedAccountId == accountId;
    return GestureDetector(
      onTap: () => setState(() => _selectedAccountId = accountId),
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: isSelected ? Colors.white : Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF1A1A2E) : Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }

  Widget _buildAddAccountChip() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(20)),
      alignment: Alignment.center,
      child: const Text("Add accounts", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }

  // --- UPDATED TRANSACTION TILE LOGIC ---
// CHANGE 1: Add 'String docId' to arguments
  Widget _buildTransactionItem(String docId, Map<String, dynamic> data) {
    String type = data['type'] ?? 'expense';
    double amount = (data['amount'] ?? 0).toDouble();
    String category = data['category'] ?? 'Uncategorised';
    String title = data['note'] != null && data['note'].toString().isNotEmpty ? data['note'] : category;
    DateTime date = (data['date'] as Timestamp).toDate();
    String status = data['status'] ?? 'success';

    bool isSelfTransfer = type == 'self_transfer';
    bool isExpense = type == 'expense';
    bool isPotDeposit = type == 'pot_deposit';
    bool isPotWithdraw = type == 'pot_withdraw' || type == 'pot_close';
    bool isIncome = type == 'income';
    bool isFailed = status == 'Failed';

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
      amountTextColor = Colors.black;
      sign = "";
    } else {
      icon = Icons.downloading_rounded;
      iconBgColor = const Color(0xFFE8F5E9);
      iconColor = const Color(0xFF1B5E20);
      amountTextColor = Colors.green[700]!;
      sign = "+";
    }

    // CHANGE 2: Wrap in GestureDetector for navigation
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 10, color: Colors.red[300]),
                      const SizedBox(width: 4),
                      Text(_formatTime(date), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                    ],
                  ),
                  if (category == 'Uncategorised')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("Categorise now", style: TextStyle(color: Colors.blue[700], fontSize: 11, fontWeight: FontWeight.w600)),
                    )
                ],
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                    "$sign₹${amount.toStringAsFixed(2)}",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: amountTextColor
                    )
                ),
                if (isFailed)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(4)),
                    child: Text("Failed", style: TextStyle(color: Colors.red[800], fontSize: 10, fontWeight: FontWeight.bold)),
                  )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 60, color: Colors.grey[300]),
          const SizedBox(height: 10),
          Text("No transactions found", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}