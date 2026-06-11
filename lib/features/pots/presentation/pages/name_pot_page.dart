import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'create_pot_category_page.dart'; // Import to access PotCategory class
import 'pot_detail_page.dart';
import 'pots_dashboard_page.dart';

class NamePotPage extends StatefulWidget {
  final PotCategory category;

  const NamePotPage({super.key, required this.category});

  @override
  State<NamePotPage> createState() => _NamePotPageState();
}

class _NamePotPageState extends State<NamePotPage> {
  final TextEditingController _nameController = TextEditingController();
  bool _isCreating = false;

  Future<void> _createPot() async {
    if (_nameController.text.trim().isEmpty) return;

    setState(() => _isCreating = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      DocumentReference docRef = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('pots')
          .add({
        'name': _nameController.text.trim(),
        'category': widget.category.id,
        'currentAmount': 0.0,
        'goalAmount': 0.0,
        'isLocked': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => PotSuccessPage(
            category: widget.category,
            potName: _nameController.text.trim(),
            potId: docRef.id,
          ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    } catch (e) {
      setState(() => _isCreating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error creating pot: $e"), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text("Creating a Pot", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),

            // --- 1. THE HERO STICKER (UPDATED) ---
            Center(
              child: SizedBox(
                height: 200,
                width: 160,
                // Pass the controller text here so it updates live!
                child: _StaticSpaceSticker(
                  category: widget.category,
                  customName: _nameController.text,
                ),
              ),
            ),

            const SizedBox(height: 40),

            // --- 2. NAME INPUT ---
            const Text("Name your pot", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              maxLength: 15,
              // Update state when user types to refresh the sticker
              onChanged: (val) {
                setState(() {});
              },
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              decoration: InputDecoration(
                hintText: "e.g. ${widget.category.label}",
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.black, width: 1.5)),
                filled: true,
                fillColor: Colors.grey[50],
                counterText: "",
              ),
            ),

            const Spacer(),

            // --- 3. CREATE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6F61),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  elevation: 0,
                ),
                onPressed: _isCreating ? null : _createPot,
                child: _isCreating
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text("Create", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// --- UPDATED SUCCESS PAGE ---
class PotSuccessPage extends StatefulWidget {
  final PotCategory category;
  final String potName;
  final String potId;

  const PotSuccessPage({
    super.key,
    required this.category,
    required this.potName,
    required this.potId,
  });

  @override
  State<PotSuccessPage> createState() => _PotSuccessPageState();
}

class _PotSuccessPageState extends State<PotSuccessPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const PotsDashboardPage()),
            (route) => route.isFirst,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PotDetailPage(
            category: widget.category,
            potName: widget.potName,
            potId: widget.potId,
            currentBalance: 0.0,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Stack(
        children: [
          const Positioned.fill(child: _StarFieldFull()),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Center(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.elasticOut,
                  builder: (context, double val, child) {
                    return Transform.scale(
                      scale: val,
                      child: Container(
                        height: 240,
                        width: 190,
                        decoration: BoxDecoration(boxShadow: [BoxShadow(color: widget.category.accentColor.withOpacity(0.6), blurRadius: 50, spreadRadius: 10)]),
                        // Pass the final name to the success sticker too
                        child: _StaticSpaceSticker(
                            category: widget.category,
                            customName: widget.potName
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "${widget.potName}\nPot created!",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, height: 1.2),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- UPDATED STICKER WIDGET ---
class _StaticSpaceSticker extends StatelessWidget {
  final PotCategory category;
  final String? customName; // <--- NEW PARAMETER

  const _StaticSpaceSticker({
    required this.category,
    this.customName,
  });

  @override
  Widget build(BuildContext context) {
    // Determine what text to show
    String displayText = (customName != null && customName!.isNotEmpty)
        ? customName!
        : category.label;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(90), bottom: Radius.circular(20)),
        border: Border.all(color: const Color(0xFF202020), width: 3),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: category.gradientColors),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(86), bottom: Radius.circular(16)),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(child: CustomPaint(painter: _StarPainter())),
            Positioned(
              top: -50, right: -50,
              child: Container(
                width: 150, height: 150,
                decoration: BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.transparent], begin: Alignment.topRight, end: Alignment.bottomLeft)),
              ),
            ),

            // Emoji (Shifted up slightly to make room for text)
            Padding(
              padding: const EdgeInsets.only(bottom: 20.0),
              child: Text(category.emoji, style: const TextStyle(fontSize: 60)),
            ),

            // Label Pill (Dynamic Text)
            Positioned(
              bottom: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                constraints: const BoxConstraints(maxWidth: 140), // Prevent overflow
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  displayText, // <--- USE DYNAMIC TEXT
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: category.gradientColors.first, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- PAINTERS (Unchanged) ---
class _StarFieldFull extends StatelessWidget {
  const _StarFieldFull();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _StarPainterFull());
}

class _StarPainterFull extends CustomPainter {
  final Random _random = Random();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < 50; i++) {
      canvas.drawCircle(Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height), _random.nextDouble() * 2, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _StarPainter extends CustomPainter {
  final Random _random = Random();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < 15; i++) {
      canvas.drawCircle(Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height), _random.nextDouble() * 1.5, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}