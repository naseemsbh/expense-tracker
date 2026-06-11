import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'pay_anyone_page.dart';
import 'add_expense_page.dart';
import 'self_transfer_page.dart';
import '../../../../features/transactions/presentation/pages/all_transactions_page.dart';
import '../../../../features/pots/presentation/pages/create_pot_category_page.dart';
import '../../../../features/pots/presentation/pages/pots_dashboard_page.dart';
// 1. ADD IMPORT
import 'transaction_details_page.dart';

class TransfersPage extends StatelessWidget {
  const TransfersPage({super.key});

  // --- ICON MAP ---
  static final Map<String, IconData> _categoryIcons = {
    'Food & drinks': Icons.fastfood_rounded, 'Groceries': Icons.shopping_basket_rounded, 'Fuel': Icons.local_gas_station_rounded,
    'Shopping': Icons.shopping_bag_rounded, 'Entertainment': Icons.movie_filter_rounded, 'Bills': Icons.lightbulb_rounded,
    'Commute': Icons.directions_car_rounded, 'Rent': Icons.home_rounded, 'Medical': Icons.medical_services_rounded,
    'Education': Icons.school_rounded, 'Pets': Icons.pets_rounded, 'Personal': Icons.face_rounded, 'Tools': Icons.build_circle_rounded,
    'Travel': Icons.flight_takeoff_rounded, 'Fees': Icons.receipt_long_rounded, 'Gifts': Icons.card_giftcard_rounded,
    'Random': Icons.shuffle_rounded, 'Transfer': Icons.person_rounded,
  };

  // --- COLOR MAP ---
  static final Map<String, Color> _categoryColors = {
    'Food & drinks': const Color(0xFF000000), 'Groceries': const Color(0xFF2EC4B6), 'Fuel': const Color(0xFFE71D36),
    'Shopping': const Color(0xFF9D4EDD), 'Entertainment': const Color(0xFFFF006E), 'Bills': const Color(0xFFFFBE0B),
    'Commute': const Color(0xFF3A86FF), 'Rent': const Color(0xFF06D6A0), 'Medical': const Color(0xFFEF476F),
    'Education': const Color(0xFF118AB2), 'Pets': const Color(0xFF8D5B4C), 'Personal': const Color(0xFFFF5400),
    'Tools': const Color(0xFF607D8B), 'Travel': const Color(0xFF00B4D8), 'Fees': const Color(0xFF9E9E9E),
    'Gifts': const Color(0xFFFF7096), 'Random': const Color(0xFF607D8B), 'Transfer': const Color(0xFF3F51B5),
  };

  // --- SMART POTS NAVIGATION ---
  Future<void> _handlePotsClick(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users').doc(user.uid).collection('pots').limit(1).get();

    if (!context.mounted) return;

    if (snapshot.docs.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const PotsDashboardPage()));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const CreatePotCategoryPage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              const SizedBox(height: 10),
              const Text("Payments", style: TextStyle(color: Color(0xFF163C46), fontSize: 32, fontWeight: FontWeight.w400, letterSpacing: -0.5)),
              const SizedBox(height: 20),

              // --- SEARCH BAR ---
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PayAnyonePage())),
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(26), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2))]),
                  child: const Row(children: [SizedBox(width: 20), Icon(Icons.search, color: Colors.grey, size: 22), SizedBox(width: 12), Text("Pay to ...", style: TextStyle(color: Colors.grey, fontSize: 16))]),
                ),
              ),
              const SizedBox(height: 25),

              // --- GRID ---
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.70,
                children: [
                  _buildGridItem(Icons.perm_contact_calendar_outlined, "Pay to\nContacts", color: const Color(0xFF1565C0), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PayAnyonePage()))),
                  _buildGridItem(Icons.add_card, "Add\nExpense", color: const Color(0xFFE65100), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddExpensePage()))),
                  _buildGridItem(Icons.swap_horiz_outlined, "Self\nTransfer", color: const Color(0xFF2E7D32), onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SelfTransferPage()))),
                  _buildGridItem(Icons.savings_outlined, "Pots", color: const Color(0xFFF9A825), onTap: () => _handlePotsClick(context)),
                  _buildGridItem(Icons.handshake_outlined, "Lent/\nDebt", color: const Color(0xFFC62828)),
                  _buildGridItem(Icons.groups_outlined, "Split\nCollections", color: const Color(0xFF6A1B9A)),
                  _buildGridItem(Icons.autorenew_rounded, "Auto\nPay", color: const Color(0xFF00838F)),
                  _buildGridItem(Icons.airplane_ticket_outlined, "Events", color: const Color(0xFFAD1457)),
                ],
              ),

              const SizedBox(height: 20),

              // --- LIST HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Transaction History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF163C46))),
                  TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AllTransactionsPage())),
                      child: const Text("View All", style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.w600))
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // --- TRANSACTION LIST ---
              if (user != null)
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').doc(user.uid).collection('transactions').orderBy('date', descending: true).limit(20).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No transactions yet", style: TextStyle(color: Colors.grey)));

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: snapshot.data!.docs.length,
                        itemBuilder: (context, index) {
                          var doc = snapshot.data!.docs[index];
                          var data = doc.data() as Map<String, dynamic>;
                          // 2. PASS CONTEXT AND ID
                          return _buildTransactionTile(context, doc.id, data);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem(IconData icon, String label, {required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            height: 56, width: 56,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF455A64), height: 1.1)),
        ],
      ),
    );
  }

  // 3. UPDATED SIGNATURE: Accept context and docId
  Widget _buildTransactionTile(BuildContext context, String docId, Map<String, dynamic> data) {
    String type = data['type'] ?? '';

    // Determine Categories
    bool isSelfTransfer = type == 'self_transfer';
    bool isExpense = type == 'expense';
    bool isPotDeposit = type == 'pot_deposit';
    bool isPotWithdraw = type == 'pot_withdraw' || type == 'pot_close';

    double amount = (data['amount'] ?? 0).toDouble();
    String category = data['category'] ?? "General";
    String note = data['note'] ?? category;

    if (note.contains(":")) {
      note = note.split(":")[1].trim();
    } else if (note.startsWith("Paid to")) {
      note = note.replaceFirst("Paid to ", "");
    } else if (note.startsWith("Received from")) {
      note = note.replaceFirst("Received from ", "");
    }

    String dateString = "Just now";
    if (data['date'] != null) {
      DateTime date = (data['date'] as Timestamp).toDate();
      dateString = "${date.day}/${date.month} • ${date.hour > 12 ? date.hour - 12 : date.hour}:${date.minute.toString().padLeft(2, '0')} ${date.hour >= 12 ? 'pm' : 'am'}";
    }

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

    // 4. WRAP IN GESTURE DETECTOR
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
}