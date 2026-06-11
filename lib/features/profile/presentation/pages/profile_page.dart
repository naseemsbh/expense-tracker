import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/features/account/presentation/pages/add_bank_account_page.dart';
import 'package:expense_tracker/features/account/presentation/pages/account_settings_page.dart';
import 'package:expense_tracker/features/auth/presentation/pages/login_page.dart';
import 'package:expense_tracker/features/auth/presentation/pages/mpin_verification_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final User? user = FirebaseAuth.instance.currentUser;
  final Map<String, bool> _visibleBalances = {};

  // Navigate to MPIN Page and wait for result (Used for Check Balance)
  Future<void> _verifyAndExecute({required Function onSuccess}) async {
    final bool? isVerified = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MpinVerificationPage()),
    );

    if (isVerified == true) {
      onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (user == null) return const Scaffold(body: Center(child: Text("Please Login")));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)
        ),
        title: const Text("Profile", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUserHeader(),
            const SizedBox(height: 10),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Text("Your Accounts", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            ),
            const SizedBox(height: 16),

            // --- ACCOUNTS LIST ---
            SizedBox(
              height: 200,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).collection('accounts').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  var allDocs = snapshot.data!.docs;

                  // 1. Filter out Cash (Only show Banks)
                  var bankDocs = allDocs.where((doc) {
                    var data = doc.data() as Map<String, dynamic>;
                    String name = data['name'] ?? "";
                    String type = data['type'] ?? "";
                    return name != "Cash on Hand" && type != "Cash";
                  }).toList();

                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: bankDocs.length + 1,
                    itemBuilder: (context, index) {
                      // Add Button at the end
                      if (index == bankDocs.length) return _buildAddButton();

                      // Bank Cards
                      var doc = bankDocs[index];
                      var data = doc.data() as Map<String, dynamic>;
                      Color cardColor = Color(data['color'] ?? 0xFF4B39EF);
                      bool isPrimary = data['isPrimary'] ?? false;

                      return _buildBankCard(
                        docId: doc.id,
                        name: data['name'] ?? "Bank",
                        digits: data['last4Digits'] ?? "",
                        balance: (data['balance'] ?? 0).toDouble(),
                        isPrimary: isPrimary,
                        color: cardColor,
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30),

            // --- SETTINGS LIST ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("SETTINGS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.2)),
                  const SizedBox(height: 10),
                  _buildJupiterTile(icon: Icons.person_outline, title: "Your Profile", subtitle: "Personal details and saved addresses"),
                  _buildJupiterTile(icon: Icons.settings_outlined, title: "App Settings", subtitle: "Manage PINs, notifications, and more"),
                  _buildJupiterTile(icon: Icons.description_outlined, title: "Statements & Reports", subtitle: "Download monthly PDF/Excel"),
                  _buildJupiterTile(icon: Icons.backup_outlined, title: "Backup & Restore", subtitle: "Manage cloud sync"),
                  _buildJupiterTile(icon: Icons.info_outline, title: "About Us", subtitle: "Terms and conditions"),
                  const SizedBox(height: 20),

                  // Logout
                  InkWell(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (context.mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginPage()), (route) => false);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.logout, color: Colors.red[700]),
                          const SizedBox(width: 16),
                          Text("Log Out", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700])),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard({
    required String docId,
    required String name,
    required String digits,
    required double balance,
    required bool isPrimary,
    required Color color
  }) {
    bool isVisible = _visibleBalances[docId] ?? false;

    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(24), boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(height: 50, width: 50, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.account_balance, color: color, size: 28)),

              // Arrow Icon -> Goes to Account Settings Page
              IconButton(
                icon: const Icon(Icons.chevron_right, color: Colors.white, size: 32),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AccountSettingsPage(docId: docId, bankName: name, last4Digits: digits)));
                },
              ),
            ],
          ),
          const Spacer(),
          Text("$name $digits", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Check Balance -> Asks for MPIN
              GestureDetector(
                onTap: () {
                  if (!isVisible) {
                    _verifyAndExecute(onSuccess: () {
                      setState(() => _visibleBalances[docId] = true);
                      Future.delayed(const Duration(seconds: 5), () { if(mounted) setState(() => _visibleBalances[docId] = false); });
                    });
                  }
                },
                child: Text(isVisible ? "₹ $balance" : "Check balance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              ),
              if (isPrimary) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: Colors.green[100], borderRadius: BorderRadius.circular(8)), child: Text("Primary", style: TextStyle(color: Colors.green[800], fontSize: 12, fontWeight: FontWeight.bold))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddBankAccountPage())),
      child: Container(
        width: 100, margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.grey.shade300)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_circle_outline, size: 30, color: Colors.black), SizedBox(height: 8), Text("Add\nAccount", textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildUserHeader() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(user!.uid).snapshots(),
      builder: (context, snapshot) {
        String name = "User"; String phone = ""; String initial = "?";
        if (snapshot.hasData && snapshot.data!.data() != null) {
          var data = snapshot.data!.data() as Map<String, dynamic>;
          name = data['name'] ?? "User"; phone = data['phone'] ?? "";
          if (name.isNotEmpty) initial = name[0].toUpperCase();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 35,
                backgroundColor: Colors.black,
                child: Text(initial, style: const TextStyle(fontSize: 28, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("+91 $phone", style: const TextStyle(color: Colors.grey, fontSize: 14)),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildJupiterTile({required IconData icon, required String title, required String subtitle}) {
    return Container(margin: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [Icon(icon, size: 24, color: Colors.black87), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black)), const SizedBox(height: 2), Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey))])), const Icon(Icons.chevron_right, color: Colors.grey)]));
  }
}