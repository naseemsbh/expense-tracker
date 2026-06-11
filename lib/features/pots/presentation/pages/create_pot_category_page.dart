import 'package:flutter/material.dart';
import 'dart:math';
import 'name_pot_page.dart'; // Import to access PotCategory class

// --- 1. DATA MODEL ---
class PotCategory {
  final String id;
  final String label;
  final String emoji;
  final List<Color> gradientColors;
  final Color accentColor;

  const PotCategory({
    required this.id,
    required this.label,
    required this.emoji,
    required this.gradientColors,
    required this.accentColor,
  });
}

// --- 2. CATEGORIES ---
final List<PotCategory> potCategories = [
  PotCategory(
    id: 'custom',
    label: 'Custom',
    emoji: '⚙️',
    gradientColors: [const Color(0xFF2C3E50), const Color(0xFF000000)],
    accentColor: Colors.grey,
  ),
  PotCategory(
    id: 'holiday',
    label: 'Holiday',
    emoji: '🚀',
    gradientColors: [const Color(0xFF4A00E0), const Color(0xFF12002E)],
    accentColor: const Color(0xFF8E2DE2),
  ),
  PotCategory(
    id: 'emergency',
    label: 'Emergency',
    emoji: '⛑️',
    gradientColors: [const Color(0xFF870000), const Color(0xFF190A05)],
    accentColor: const Color(0xFFFF416C),
  ),
  PotCategory(
    id: 'gift',
    label: 'Gift',
    emoji: '🎁',
    gradientColors: [const Color(0xFF11998e), const Color(0xFF052925)],
    accentColor: const Color(0xFF38ef7d),
  ),
  PotCategory(
    id: 'education',
    label: 'Education',
    emoji: '🎓',
    gradientColors: [const Color(0xFFF2994A), const Color(0xFF4C2A08)],
    accentColor: const Color(0xFFF2C94C),
  ),
  PotCategory(
    id: 'gadget',
    label: 'Gadget',
    emoji: '🎧',
    gradientColors: [const Color(0xFF00C6FF), const Color(0xFF002A45)],
    accentColor: const Color(0xFF0072FF),
  ),
];

// --- 3. PAGE ---
class CreatePotCategoryPage extends StatelessWidget {
  const CreatePotCategoryPage({super.key});

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
        title: const Text("Pots", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.info_outline_rounded, color: Colors.grey), onPressed: () {})
        ],
      ),
      body: Column(
        children: [
          // Header (Reduced Spacing)
          const Text("Pick a category", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text("Start saving for your next big goal", style: TextStyle(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),

          const SizedBox(height: 20), // Reduced gap before grid

          // THE STICKER GRID
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 10), // Reduced top padding
              physics: const NeverScrollableScrollPhysics(), // Disable scrolling
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16, // Tighter horizontal gap
                mainAxisSpacing: 16,  // Tighter vertical gap
                childAspectRatio: 0.85, // Higher number = Shorter cards (Fits better)
              ),
              itemCount: potCategories.length,
              itemBuilder: (context, index) {
                return _SpaceStickerCard(category: potCategories[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. STICKER CARD (Same Cool Design) ---
class _SpaceStickerCard extends StatefulWidget {
  final PotCategory category;
  const _SpaceStickerCard({required this.category});

  @override
  State<_SpaceStickerCard> createState() => _SpaceStickerCardState();
}

class _SpaceStickerCardState extends State<_SpaceStickerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() async {
    await _controller.forward();
    await _controller.reverse();

    // Navigate to NamePotPage
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => NamePotPage(category: widget.category)
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTapUp: (_) => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Column(
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(80), bottom: Radius.circular(20)),
                  border: Border.all(color: const Color(0xFF202020), width: 2.5),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.category.gradientColors,
                  ),
                  boxShadow: [
                    BoxShadow(color: widget.category.gradientColors.first.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 6)),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(76), bottom: Radius.circular(16)),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Positioned.fill(child: _StarField()), // Stars

                      // Glossy Reflection
                      Positioned(
                        top: -40, right: -40,
                        child: Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                  colors: [Colors.white.withOpacity(0.15), Colors.transparent],
                                  begin: Alignment.topRight,
                                  end: Alignment.bottomLeft
                              )
                          ),
                        ),
                      ),

                      // Emoji
                      Text(widget.category.emoji, style: const TextStyle(fontSize: 42)),

                      // Bottom Glow
                      Positioned(
                        bottom: 0,
                        child: Container(
                          width: 80, height: 30,
                          decoration: BoxDecoration(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(40)),
                              boxShadow: [
                                BoxShadow(color: widget.category.accentColor.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)
                              ]
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Label Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: widget.category.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.category.label,
                style: TextStyle(
                  color: widget.category.accentColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- STAR PAINTER (Unchanged) ---
class _StarField extends StatelessWidget {
  const _StarField();
  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _StarPainter());
  }
}

class _StarPainter extends CustomPainter {
  final Random _random = Random();
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.3);
    for (int i = 0; i < 12; i++) {
      canvas.drawCircle(Offset(_random.nextDouble() * size.width, _random.nextDouble() * size.height), _random.nextDouble() * 1.5, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}