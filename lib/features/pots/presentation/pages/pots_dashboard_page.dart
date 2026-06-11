import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'create_pot_category_page.dart'; // To get PotCategory data & navigation
import 'pot_detail_page.dart'; // To navigate to details

class PotsDashboardPage extends StatelessWidget {
  const PotsDashboardPage({super.key});

  // Helper to find the Category styling based on the ID stored in Firebase
  PotCategory _getCategoryById(String id) {
    return potCategories.firstWhere(
          (c) => c.id == id,
      orElse: () => potCategories[0], // Default to custom if not found
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF181B26), // Midnight Theme
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("Your Pots", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('pots')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Colors.white));

          var docs = snapshot.data!.docs;

          // Calculate Total Savings
          double totalSaved = 0;
          for (var doc in docs) {
            totalSaved += (doc.data() as Map<String, dynamic>)['currentAmount'] ?? 0.0;
          }

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. TOTAL SAVINGS HEADER ---
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2C3E50), Color(0xFF000000)], // Subtle Dark Gradient
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Total Saved", style: TextStyle(color: Colors.grey, fontSize: 14)),
                      const SizedBox(height: 8),
                      Text(
                          "₹${totalSaved.toStringAsFixed(0)}",
                          style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold)
                      ),
                      const SizedBox(height: 8),
                      Text(
                          "${docs.length} Active Pots",
                          style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.w600)
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                const Text("All Pots", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                // --- 2. THE GRID ---
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.8, // Tall cards
                    ),
                    // Item count is docs + 1 (for the "Create New" card)
                    itemCount: docs.length + 1,
                    itemBuilder: (context, index) {

                      // --- FIRST ITEM: CREATE NEW POT ---
                      if (index == 0) {
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CreatePotCategoryPage())
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white24, style: BorderStyle.solid), // Dashed look simulated with opacity
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF669DF6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.black, size: 30),
                                ),
                                const SizedBox(height: 16),
                                const Text("Create New", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        );
                      }

                      // --- OTHER ITEMS: EXISTING POTS ---
                      var doc = docs[index - 1]; // Adjust index
                      var data = doc.data() as Map<String, dynamic>;
                      PotCategory theme = _getCategoryById(data['category'] ?? 'custom');
                      double amount = (data['currentAmount'] ?? 0).toDouble();

                      return GestureDetector(
                        onTap: () {
                          // Navigate to Detail Page
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PotDetailPage(
                                    potId: doc.id, // <--- FIXED: PASS THE DOC ID
                                    category: theme,
                                    potName: data['name'],
                                    currentBalance: amount,
                                  )
                              )
                          );
                        },
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(80), bottom: Radius.circular(24)),
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: theme.gradientColors,
                              ),
                              boxShadow: [
                                BoxShadow(color: theme.gradientColors.first.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                              ]
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Emoji
                              Positioned(
                                top: 40,
                                child: Text(theme.emoji, style: const TextStyle(fontSize: 40)),
                              ),

                              // Info at bottom
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.3),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['name'] ?? "Pot",
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                          "₹${amount.toStringAsFixed(0)}",
                                          style: TextStyle(color: theme.accentColor, fontWeight: FontWeight.w900, fontSize: 16)
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}