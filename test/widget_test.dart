import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:demoapp/models/cure.dart';
import 'package:demoapp/screens/add_disease_screen.dart';

void main() {
  testWidgets('AddDiseaseScreen renders all required fields matching design',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AddDiseaseScreen(),
      ),
    );

    // Verify Title and Close icon
    expect(find.text('Add New Disease'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Verify Form Fields and labels
    expect(find.text('Disease Name'), findsOneWidget);
    expect(find.text('Enter disease name'), findsOneWidget);

    expect(find.text('Disease Image'), findsOneWidget);
    expect(find.text('Choose Image from Gallery'), findsOneWidget);
    expect(find.byIcon(Icons.add_photo_alternate_outlined), findsOneWidget);

    expect(find.text('Description'), findsOneWidget);
    expect(find.text('Enter disease description'), findsOneWidget);

    // Verify Action Buttons
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Add Disease'), findsOneWidget);

    // Tap Add Disease without name to test validation
    await tester.tap(find.text('Add Disease'));
    await tester.pump();
    expect(find.text('Please enter a disease name'), findsOneWidget);
  });

  test('Cure correctly serializes and parses chained recitation items into single Cure', () {
    final items = [
      RecitationItem(
        source: 'Hadith',
        title: "Hadith: Jami` at-Tirmidhi #3",
        ayatFrom: 0,
        ayatTo: 0,
        count: 2,
        instructions: 'Recitation',
      ),
      RecitationItem(
        source: 'Surah',
        title: 'Al-Fatihah',
        ayatFrom: 1,
        ayatTo: 2,
        count: 7,
        instructions: 'Surah · Ayat 1-2',
      ),
    ];

    final jsonChain = jsonEncode(items.map((i) => i.toMap()).toList());

    final cure = Cure.fromMap({
      'CureId': 101,
      'DiseaseId': 1,
      'SurahName': 'test1',
      'AyatFrom': 0,
      'AyatTo': 0,
      'RecommendedTime': '',
      'TargetCount': 9,
      'Instructions': jsonChain,
    });

    expect(cure.cureId, 101);
    expect(cure.surahName, 'test1');
    expect(cure.items.length, 2);
    expect(cure.targetCount, 9);
    expect(cure.items[0].title, "Hadith: Jami` at-Tirmidhi #3");
    expect(cure.items[0].count, 2);
    expect(cure.items[1].title, 'Al-Fatihah');
    expect(cure.items[1].count, 7);
  });
}
