import 'dart:convert';

class RecitationItem {
  final String source; // 'Surah', 'Hadith', 'Darood'
  final String title;
  final int ayatFrom;
  final int ayatTo;
  final int count;
  final String instructions;

  RecitationItem({
    required this.source,
    required this.title,
    required this.ayatFrom,
    required this.ayatTo,
    required this.count,
    required this.instructions,
  });

  factory RecitationItem.fromMap(Map<String, dynamic> map) {
    return RecitationItem(
      source: map['source'] ?? 'Surah',
      title: map['title'] ?? '',
      ayatFrom: map['ayatFrom'] ?? 0,
      ayatTo: map['ayatTo'] ?? 0,
      count: map['count'] ?? 1,
      instructions: map['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'source': source,
      'title': title,
      'ayatFrom': ayatFrom,
      'ayatTo': ayatTo,
      'count': count,
      'instructions': instructions,
    };
  }
}

class Cure {
  int? cureId;
  int diseaseId;
  String surahName;
  int ayatFrom;
  int ayatTo;
  String recommendedTime;
  int targetCount;
  String instructions;
  List<RecitationItem> items;

  Cure({
    this.cureId,
    required this.diseaseId,
    required this.surahName,
    required this.ayatFrom,
    required this.ayatTo,
    required this.recommendedTime,
    required this.targetCount,
    required this.instructions,
    List<RecitationItem>? items,
  }) : items = items ?? [];

  factory Cure.fromMap(Map<String, dynamic> map) {
    List<RecitationItem> parsedItems = [];
    final instructionsStr = map['Instructions']?.toString() ?? '';

    if (instructionsStr.trim().startsWith('[') &&
        instructionsStr.trim().endsWith(']')) {
      try {
        final decoded = jsonDecode(instructionsStr.trim()) as List;
        parsedItems = decoded
            .map((item) => RecitationItem.fromMap(item as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final targetCount = map['TargetCount'] ?? 0;
    final surahName = map['SurahName'] ?? '';
    final ayatFrom = map['AyatFrom'] ?? 0;
    final ayatTo = map['AyatTo'] ?? 0;

    if (parsedItems.isEmpty) {
      parsedItems.add(
        RecitationItem(
          source: instructionsStr.toLowerCase().contains('hadith')
              ? 'Hadith'
              : instructionsStr.toLowerCase().contains('darood')
                  ? 'Darood'
                  : 'Surah',
          title: surahName,
          ayatFrom: ayatFrom,
          ayatTo: ayatTo,
          count: targetCount > 0 ? targetCount : 1,
          instructions: instructionsStr,
        ),
      );
    }

    final totalCount = parsedItems.fold(0, (sum, i) => sum + i.count);

    return Cure(
      cureId: map['CureId'],
      diseaseId: map['DiseaseId'] ?? 0,
      surahName: surahName,
      ayatFrom: ayatFrom,
      ayatTo: ayatTo,
      recommendedTime: map['RecommendedTime'] ?? '',
      targetCount: totalCount > 0 ? totalCount : targetCount,
      instructions: instructionsStr,
      items: parsedItems,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'DiseaseId': diseaseId,
      'SurahName': surahName,
      'AyatFrom': ayatFrom,
      'AyatTo': ayatTo,
      'RecommendedTime': recommendedTime,
      'TargetCount': targetCount,
      'Instructions': items.isNotEmpty
          ? jsonEncode(items.map((i) => i.toMap()).toList())
          : instructions,
    };

    if (cureId != null) {
      map['CureId'] = cureId;
    }

    return map;
  }
}
