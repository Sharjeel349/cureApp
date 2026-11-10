import 'package:flutter/material.dart';

const Color darkGreen = Color(0xFF075F4B);
const Color deepGreen = Color(0xFF005847);
const Color pageCream = Color(0xFFF2EEE7);
const Color gold = Color(0xFFD2AD22);
const Color textDark = Color(0xFF111827);
const Color mutedText = Color(0xFF8B929A);

BoxDecoration roundedWhiteBox({double radius = 12}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04),
        blurRadius: 14,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

InputDecoration formDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD8D3CA)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD8D3CA)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: darkGreen),
    ),
  );
}

class MockBottomNav extends StatelessWidget {
  final int currentIndex;

  const MockBottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: darkGreen,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      onTap: (index) {
        if (index == currentIndex) return;

        if (index == 0) {
          Navigator.popUntil(context, (route) => route.isFirst);
        }

        if (index == 1) {
          Navigator.pushNamed(context, '/logs');
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.description_outlined),
          activeIcon: Icon(Icons.description),
          label: 'Logs',
        ),
      ],
    );
  }
}
