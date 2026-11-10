import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/cure.dart';
import '../models/disease.dart';
import '../models/log_entry.dart';
import 'app_style.dart';
import 'logs_screen.dart';

class RecitationScreen extends StatefulWidget {
  final Disease disease;
  final Cure cure;
  final LogEntry? log;

  const RecitationScreen({
    super.key,
    required this.disease,
    required this.cure,
    this.log,
  });

  @override
  State<RecitationScreen> createState() => _RecitationScreenState();
}

class _RecitationScreenState extends State<RecitationScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  int currentStepIndex = 0;
  int currentStepCount = 0;
  int? logId;
  String ayahText = '';
  bool isLoading = true;
  bool isSaving = false;

  List<RecitationItem> get chainItems {
    if (widget.cure.items.isNotEmpty) {
      return widget.cure.items;
    }
    return [
      RecitationItem(
        source: widget.cure.instructions.toLowerCase().contains('hadith')
            ? 'Hadith'
            : widget.cure.instructions.toLowerCase().contains('darood')
                ? 'Darood'
                : 'Surah',
        title: widget.cure.surahName,
        ayatFrom: widget.cure.ayatFrom,
        ayatTo: widget.cure.ayatTo,
        count: widget.cure.targetCount,
        instructions: widget.cure.instructions,
      )
    ];
  }

  int get totalSteps => chainItems.length;

  RecitationItem get currentItem {
    if (currentStepIndex < chainItems.length) {
      return chainItems[currentStepIndex];
    }
    return chainItems.last;
  }

  int get totalRecitedCount {
    int sum = 0;
    for (int i = 0; i < currentStepIndex && i < chainItems.length; i++) {
      sum += chainItems[i].count;
    }
    sum += currentStepCount;
    return sum;
  }

  @override
  void initState() {
    super.initState();
    startRecitation();
  }

  Future<void> loadStepText() async {
    setState(() {
      isLoading = true;
    });

    String text = '';
    final item = currentItem;
    if (item.source == 'Surah') {
      text = await dbHelper.fetchQuranAyahText(
        surahName: item.title,
        ayatFrom: item.ayatFrom,
        ayatTo: item.ayatTo,
      );
    } else {
      text = item.instructions.isNotEmpty ? item.instructions : item.title;
    }

    if (!mounted) return;
    setState(() {
      ayahText = text;
      isLoading = false;
    });
  }

  Future<void> startRecitation() async {
    int newLogId;

    if (widget.log != null) {
      newLogId = widget.log!.id!;
      currentStepCount = widget.log!.currentCount;
    } else {
      newLogId = await dbHelper.startLog(
        diseaseId: widget.disease.id ?? 0,
        cureId: widget.cure.cureId ?? 0,
        diseaseName: widget.disease.diseaseName,
        surahName: widget.cure.surahName,
        targetCount: widget.cure.targetCount,
      );
    }

    logId = newLogId;
    await loadStepText();
  }

  Future<void> updateCount(int value) async {
    if (logId == null) return;

    setState(() {
      currentStepCount = value;
      isSaving = true;
    });

    await dbHelper.updateLogProgress(
      logId: logId!,
      currentCount: totalRecitedCount,
      targetCount: widget.cure.targetCount,
    );

    if (!mounted) return;
    setState(() {
      isSaving = false;
    });
  }

  Future<void> increaseCounter() async {
    if (isSaving || isStepCompleted) return;
    await updateCount(currentStepCount + 1);
  }

  bool get isStepCompleted {
    return currentStepCount >= currentItem.count;
  }

  bool get isAllCompleted {
    return currentStepIndex >= totalSteps - 1 && isStepCompleted;
  }

  Future<void> goToNextStep() async {
    if (currentStepIndex < totalSteps - 1) {
      setState(() {
        currentStepIndex++;
        currentStepCount = 0;
      });
      await loadStepText();
    }
  }

  Future<void> completeRecitation() async {
    if (isSaving) return;

    if (!isAllCompleted) {
      await updateCount(currentItem.count);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LogsScreen()),
    );
  }

  String get arabicText {
    return ayahText.split('\n\n').first.trim();
  }

  String get englishText {
    final parts = ayahText.split('\n\n');
    if (parts.length < 2) return '';
    return parts.sublist(1).join('\n\n').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageCream,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(30, 60, 30, 24),
            color: darkGreen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white70),
                      SizedBox(width: 10),
                      Text(
                        'Back',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  widget.cure.surahName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (totalSteps > 1) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Step ${currentStepIndex + 1} of $totalSteps: ${currentItem.title}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: roundedWhiteBox(radius: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                arabicText.isEmpty
                                    ? currentItem.title
                                    : arabicText,
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  color: textDark,
                                  fontFamily: 'IndoPak',
                                  fontSize: 28,
                                  height: 2.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(20, 30, 20, 30),
                          decoration: roundedWhiteBox(radius: 18),
                          child: Column(
                            children: [
                              Text(
                                totalSteps > 1
                                    ? 'Step ${currentStepIndex + 1}: ${currentItem.title}'
                                    : 'Recited Counter',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: textDark,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 22),
                              GestureDetector(
                                onTap: increaseCounter,
                                child: Container(
                                  width: 170,
                                  height: 170,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: darkGreen,
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${currentItem.count - currentStepCount}',
                                          style: const TextStyle(
                                            color: darkGreen,
                                            fontSize: 44,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                        Text(
                                          '/ ${currentItem.count}',
                                          style: const TextStyle(
                                            color: Color(0xFF4B5563),
                                            fontSize: 24,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                totalSteps > 1
                                    ? 'Total: $totalRecitedCount / ${widget.cure.targetCount} recitations'
                                    : 'Tap circle to count',
                                style: const TextStyle(color: Color(0xFF6B7280)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (currentStepIndex < totalSteps - 1 && isStepCompleted)
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton.icon(
                              onPressed: goToNextStep,
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                'Next Step (${currentStepIndex + 2}/$totalSteps)',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            width: double.infinity,
                            height: 60,
                            child: ElevatedButton(
                              onPressed: completeRecitation,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: darkGreen,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                currentStepIndex < totalSteps - 1
                                    ? 'Next: Complete Step ${currentStepIndex + 1}'
                                    : 'Complete Recitation',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
