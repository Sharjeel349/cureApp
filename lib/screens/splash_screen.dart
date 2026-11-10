import 'package:flutter/material.dart';

import 'app_style.dart';
import 'diseases_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  void openDiseasesScreen(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const DiseasesScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 42),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: darkGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(Icons.menu_book, color: gold, size: 64),
              ),
              const SizedBox(height: 36),
              const Text(
                'Quranic Cure',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textDark,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'الشفاء بالقرآن',
                style: TextStyle(color: gold, fontSize: 18),
              ),
              const SizedBox(height: 14),
              const Text(
                'Healing through the Holy Quran',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 16),
              ),
              const SizedBox(height: 52),
              SizedBox(
                width: double.infinity,
                height: 70,
                child: ElevatedButton(
                  onPressed: () => openDiseasesScreen(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: darkGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Start Healing',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
