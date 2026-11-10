import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/cure.dart';
import '../models/disease.dart';
import '../models/surah_info.dart';
import 'recitation_screen.dart';

class RecitationDraftItem {
  final String source; // 'Surah', 'Hadith', 'Darood'
  final String title;
  final int ayatFrom;
  final int ayatTo;
  final int count;
  final String instructions;

  RecitationDraftItem({
    required this.source,
    required this.title,
    required this.ayatFrom,
    required this.ayatTo,
    required this.count,
    required this.instructions,
  });
}

class CureManagementScreen extends StatefulWidget {
  final Disease disease;

  const CureManagementScreen({super.key, required this.disease});

  @override
  State<CureManagementScreen> createState() => _CureManagementScreenState();
}

class _CureManagementScreenState extends State<CureManagementScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final TextEditingController searchController = TextEditingController();

  List<Cure> cures = [];
  List<SurahInfo> surahs = [];
  String searchQuery = '';
  bool isLoading = true;

  static const Color primaryGreen = Color(0xFF0B492C);
  static const Color surfaceGrey = Color(0xFFF4F6FA);
  static const Color textMain = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color deleteRed = Color(0xFFB91C1C);

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    if (widget.disease.id == null) return;

    final cureData = await dbHelper.fetchCuresByDiseaseId(widget.disease.id!);
    final surahData = await dbHelper.fetchSurahInfoList();

    if (!mounted) return;
    setState(() {
      cures = cureData;
      surahs = surahData;
      isLoading = false;
    });
  }

  Future<void> loadCures() async {
    if (widget.disease.id == null) return;

    final cureData = await dbHelper.fetchCuresByDiseaseId(widget.disease.id!);
    if (!mounted) return;
    setState(() {
      cures = cureData;
    });
  }

  List<Cure> get filteredCures {
    if (searchQuery.isEmpty) return cures;
    final q = searchQuery.toLowerCase();
    return cures.where((c) {
      final matchesName = c.surahName.toLowerCase().contains(q);
      final matchesInstructions = c.instructions.toLowerCase().contains(q);
      final matchesItems = c.items.any((it) =>
          it.title.toLowerCase().contains(q) ||
          it.instructions.toLowerCase().contains(q));
      return matchesName ||
          matchesInstructions ||
          matchesItems ||
          '${c.ayatFrom}-${c.ayatTo}'.contains(q);
    }).toList();
  }

  int get totalRecitations {
    return cures.fold(0, (sum, item) => sum + item.targetCount);
  }

  String get pageTitle {
    final name = widget.disease.diseaseName.trim();
    if (name.toLowerCase().endsWith('disease') ||
        name.toLowerCase().endsWith('diseases')) {
      return name;
    }
    return '$name Diseases';
  }

  void openRecitation(Cure cure) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RecitationScreen(disease: widget.disease, cure: cure),
      ),
    );
  }

  Future<void> openCureDialog({Cure? cure}) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AddCureDialog(
          disease: widget.disease,
          surahs: surahs,
          cure: cure,
          onSaveChain: (items, cureTitle) async {
            if (items.isEmpty) return;

            final overallTitle = cureTitle.trim().isNotEmpty
                ? cureTitle.trim()
                : items.first.title;

            final recitationItems = items
                .map((i) => RecitationItem(
                      source: i.source,
                      title: i.title,
                      ayatFrom: i.ayatFrom,
                      ayatTo: i.ayatTo,
                      count: i.count,
                      instructions: i.instructions,
                    ))
                .toList();

            final totalRecitationsCount =
                items.fold(0, (sum, it) => sum + it.count);

            final newCure = Cure(
              cureId: cure?.cureId,
              diseaseId: widget.disease.id!,
              surahName: overallTitle,
              ayatFrom: items.first.ayatFrom,
              ayatTo: items.first.ayatTo,
              recommendedTime: '',
              targetCount: totalRecitationsCount,
              instructions: jsonEncode(
                recitationItems.map((i) => i.toMap()).toList(),
              ),
              items: recitationItems,
            );

            if (cure != null && cure.cureId != null) {
              await dbHelper.updateCure(newCure);
            } else {
              await dbHelper.insertCure(newCure);
            }
            await loadCures();
          },
        );
      },
    );
  }

  Future<void> deleteCure(Cure cure) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Delete Cure'),
          content: Text(
            'Are you sure you want to delete cure for ${cure.surahName.isNotEmpty ? cure.surahName : "this disease"}?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: deleteRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true || cure.cureId == null) return;
    await dbHelper.deleteCure(cure.cureId!);
    await loadCures();
  }

  Widget buildDiseaseImage() {
    final imageName = widget.disease.imageName?.trim() ?? '';

    if (imageName.isNotEmpty && File(imageName).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(imageName),
          width: double.infinity,
          height: 180,
          fit: BoxFit.cover,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFEAF5F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.medication_liquid_outlined,
                  color: primaryGreen,
                  size: 36,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.disease.diseaseName,
                style: const TextStyle(
                  color: primaryGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildCureItem(Cure cure, int index) {
    final isChain = cure.items.length > 1;
    final cureNumber = 'Cure ${index + 1}';
    final hasCustomName = cure.surahName.isNotEmpty &&
        cure.surahName.toLowerCase() != cureNumber.toLowerCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Cure Number & Custom Title, Recitations count and Trash icon
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Text(
                      cureNumber,
                      style: const TextStyle(
                        color: textMain,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasCustomName) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            cure.surahName,
                            style: const TextStyle(
                              color: Color(0xFF4B5563),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                '${cure.targetCount} recitations',
                style: const TextStyle(
                  color: primaryGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Body: Chain items or single item details
          if (isChain) ...[
            ...List.generate(cure.items.length, (stepIdx) {
              final item = cure.items[stepIdx];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: surfaceGrey,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: primaryGreen,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${stepIdx + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              color: textMain,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8F5E9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  item.source,
                                  style: const TextStyle(
                                    color: Color(0xFF2E7D32),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  item.source == 'Surah'
                                      ? (item.ayatFrom == item.ayatTo
                                          ? (item.ayatFrom == 0
                                              ? 'Full Surah'
                                              : 'Ayat ${item.ayatFrom}')
                                          : 'Ayat ${item.ayatFrom}-${item.ayatTo}')
                                      : 'Recitation',
                                  style: const TextStyle(
                                    color: textMuted,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${item.count} recitations',
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (cure.instructions.isNotEmpty &&
                    !cure.instructions.startsWith('['))
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Text(
                      cure.instructions,
                      style: const TextStyle(
                        color: Color(0xFF4B5563),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    cure.items.isNotEmpty ? cure.items.first.source : 'Surah',
                    style: const TextStyle(
                      color: Color(0xFF2E7D32),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              cure.ayatFrom == cure.ayatTo
                  ? (cure.ayatFrom == 0
                      ? 'Recitation'
                      : 'Surah · Ayat ${cure.ayatFrom}')
                  : 'Surah · Ayat ${cure.ayatFrom}-${cure.ayatTo}',
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Action button: ONLY Start Treatment (full width, NO Add Cure button on card)
          SizedBox(
            width: double.infinity,
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () => openRecitation(cure),
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text(
                'Start Treatment',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: surfaceGrey,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: Back arrow, Disease Title, and "+ Add Disease" button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(Icons.arrow_back, color: textMain, size: 24),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pageTitle,
                      style: const TextStyle(
                        color: textMain,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // Search bar: "Search in Eye..."
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: TextField(
                controller: searchController,
                onChanged: (val) {
                  setState(() {
                    searchQuery = val.trim();
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search in ${widget.disease.diseaseName}...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: primaryGreen, width: 1.4),
                  ),
                ),
              ),
            ),

            // Main Card Container
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Disease Image
                            buildDiseaseImage(),
                            const SizedBox(height: 14),

                            // Disease Name and Recommended Badge
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  widget.disease.diseaseName,
                                  style: const TextStyle(
                                    color: primaryGreen,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: primaryGreen,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Recommended',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Section Title: Treatment Items (count)
                            Text(
                              'Treatment Items (${filteredCures.length})',
                              style: const TextStyle(
                                color: textMain,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // List of Cures (Cure 1, Cure 2, etc.)
                            if (filteredCures.isEmpty)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 28,
                                  horizontal: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: surfaceGrey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    const Icon(
                                      Icons.healing_outlined,
                                      color: textMuted,
                                      size: 36,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      searchQuery.isNotEmpty
                                          ? 'No matching cures found'
                                          : 'No cures added yet for this disease',
                                      style: const TextStyle(
                                        color: textMuted,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              ...List.generate(filteredCures.length, (index) {
                                return buildCureItem(filteredCures[index], index);
                              }),

                            const SizedBox(height: 10),

                            // Total Recitation count
                            Text(
                              'Total Recitation: $totalRecitations',
                              style: const TextStyle(
                                color: primaryGreen,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bottom Main Action: Start Treatment
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: cures.isEmpty
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Please add a cure first',
                                            ),
                                          ),
                                        );
                                      }
                                    : () {
                                        openRecitation(
                                          filteredCures.isNotEmpty
                                              ? filteredCures.first
                                              : cures.first,
                                        );
                                      },
                                icon: const Icon(Icons.play_arrow, size: 20),
                                label: const Text(
                                  'Start Treatment',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Bottom Secondary Action: + Add Cure
                            SizedBox(
                              width: double.infinity,
                              height: 46,
                              child: OutlinedButton.icon(
                                onPressed: () => openCureDialog(),
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text(
                                  'Add Cure',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: primaryGreen,
                                  backgroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: primaryGreen,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddCureDialog extends StatefulWidget {
  final Disease disease;
  final List<SurahInfo> surahs;
  final Cure? cure;
  final Future<void> Function(List<RecitationDraftItem> items, String cureTitle)
      onSaveChain;

  const AddCureDialog({
    super.key,
    required this.disease,
    required this.surahs,
    this.cure,
    required this.onSaveChain,
  });

  @override
  State<AddCureDialog> createState() => _AddCureDialogState();
}

class _AddCureDialogState extends State<AddCureDialog> {
  static const Color primaryGreen = Color(0xFF0B492C);
  static const Color textMain = Color(0xFF111827);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color borderGrey = Color(0xFFD1D5DB);
  static const Color cardBorder = Color(0xFFE5E7EB);
  static const Color deleteRed = Color(0xFFB91C1C);

  late final TextEditingController diseaseNameController;
  late final TextEditingController cureTitleController;
  late final TextEditingController bookNameController;
  late final TextEditingController hadithNumberController;
  late final TextEditingController daroodNameController;
  late final TextEditingController countController;

  final List<RecitationDraftItem> recitationItems = [];

  String selectedSource = 'Surah';
  SurahInfo? selectedSurah;
  int? selectedAyatFrom;
  int? selectedAyatTo;
  String? errorText;

  @override
  void initState() {
    super.initState();
    diseaseNameController =
        TextEditingController(text: widget.disease.diseaseName);
    cureTitleController =
        TextEditingController(text: widget.cure?.surahName ?? '');
    bookNameController = TextEditingController(text: 'Sahih Bukhari');
    hadithNumberController = TextEditingController(
      text: widget.cure != null &&
              widget.cure!.instructions.toLowerCase().contains('hadith')
          ? widget.cure!.instructions.replaceAll('Hadith:', '').trim()
          : '',
    );
    daroodNameController = TextEditingController(
      text: widget.cure != null &&
              widget.cure!.instructions.toLowerCase().contains('darood')
          ? widget.cure!.instructions.replaceAll('Darood:', '').trim()
          : 'Darood Ibrahimi',
    );
    countController = TextEditingController(
      text: widget.cure != null ? widget.cure!.targetCount.toString() : '7',
    );

    if (widget.cure != null) {
      if (widget.cure!.instructions.toLowerCase().contains('hadith') ||
          widget.cure!.surahName.toLowerCase().contains('hadith')) {
        selectedSource = 'Hadith';
        recitationItems.add(
          RecitationDraftItem(
            source: 'Hadith',
            title: widget.cure!.surahName,
            ayatFrom: 0,
            ayatTo: 0,
            count: widget.cure!.targetCount,
            instructions: widget.cure!.instructions,
          ),
        );
      } else if (widget.cure!.instructions.toLowerCase().contains('darood') ||
          widget.cure!.surahName.toLowerCase().contains('darood')) {
        selectedSource = 'Darood';
        recitationItems.add(
          RecitationDraftItem(
            source: 'Darood',
            title: widget.cure!.surahName,
            ayatFrom: 0,
            ayatTo: 0,
            count: widget.cure!.targetCount,
            instructions: widget.cure!.instructions,
          ),
        );
      } else {
        selectedSource = 'Surah';
        if (widget.surahs.isNotEmpty) {
          selectedSurah = widget.surahs.firstWhere(
            (s) => s.surahName == widget.cure!.surahName,
            orElse: () => widget.surahs.first,
          );
          selectedAyatFrom = widget.cure!.ayatFrom;
          selectedAyatTo = widget.cure!.ayatTo;
        }
        recitationItems.add(
          RecitationDraftItem(
            source: 'Surah',
            title: widget.cure!.surahName,
            ayatFrom: widget.cure!.ayatFrom,
            ayatTo: widget.cure!.ayatTo,
            count: widget.cure!.targetCount,
            instructions: widget.cure!.instructions,
          ),
        );
      }
    } else {
      if (widget.surahs.isNotEmpty) {
        selectedSurah = widget.surahs.first;
        selectedAyatFrom = 1;
        selectedAyatTo = 1;
      }
    }
  }

  @override
  void dispose() {
    diseaseNameController.dispose();
    cureTitleController.dispose();
    bookNameController.dispose();
    hadithNumberController.dispose();
    daroodNameController.dispose();
    countController.dispose();
    super.dispose();
  }

  List<int> ayahNumbers() {
    final count = selectedSurah?.ayahCount ?? 0;
    return List.generate(count, (index) => index + 1);
  }

  InputDecoration fieldStyle({
    required String labelText,
    String? hintText,
    String? helperText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 13,
      ),
      helperText: helperText,
      helperStyle: const TextStyle(
        color: Color(0xFF6B7280),
        fontSize: 11,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryGreen, width: 1.4),
      ),
    );
  }

  RecitationDraftItem? createDraftItem() {
    final count = int.tryParse(countController.text.trim());
    if (count == null || count <= 0) {
      setState(() {
        errorText = 'Please enter a valid count';
      });
      return null;
    }

    String title = '';
    String instructions = '';
    int ayatFrom = 1;
    int ayatTo = 1;

    if (selectedSource == 'Surah') {
      if (selectedSurah == null) {
        setState(() {
          errorText = 'Please select a Surah';
        });
        return null;
      }
      title = selectedSurah!.surahName;
      ayatFrom = selectedAyatFrom ?? 1;
      ayatTo = selectedAyatTo ?? 1;
      instructions = 'Surah · Ayat $ayatFrom-$ayatTo';
    } else if (selectedSource == 'Hadith') {
      if (bookNameController.text.trim().isEmpty ||
          hadithNumberController.text.trim().isEmpty) {
        setState(() {
          errorText = 'Please enter book name and hadith number';
        });
        return null;
      }
      final hadithInfo =
          '${bookNameController.text.trim()} #${hadithNumberController.text.trim()}';
      title = 'Hadith: $hadithInfo';
      instructions = 'Hadith: $hadithInfo';
      ayatFrom = 0;
      ayatTo = 0;
    } else if (selectedSource == 'Darood') {
      if (daroodNameController.text.trim().isEmpty) {
        setState(() {
          errorText = 'Please enter Darood name';
        });
        return null;
      }
      title = 'Darood: ${daroodNameController.text.trim()}';
      instructions = 'Darood: ${daroodNameController.text.trim()}';
      ayatFrom = 0;
      ayatTo = 0;
    }

    return RecitationDraftItem(
      source: selectedSource,
      title: title,
      ayatFrom: ayatFrom,
      ayatTo: ayatTo,
      count: count,
      instructions: instructions,
    );
  }

  void addToRecitationCard() {
    final item = createDraftItem();
    if (item == null) return;

    setState(() {
      recitationItems.add(item);
      errorText = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added to chain (${recitationItems.length} items total)',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: primaryGreen,
      ),
    );
  }

  Future<void> saveCompleteCure() async {
    // If user has not pressed "Add to Recitation Card", try adding current input
    if (recitationItems.isEmpty) {
      final currentItem = createDraftItem();
      if (currentItem != null) {
        recitationItems.add(currentItem);
      } else {
        setState(() {
          errorText = 'Please add at least one recitation item to the cure';
        });
        return;
      }
    }

    final overallTitle = cureTitleController.text.trim();
    await widget.onSaveChain(recitationItems, overallTitle);

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dialog Header: Add Cure & Close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Add Cure',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textMain,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: textMuted, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Add Quranic Surah, Hadith, or Darood for spiritual healing',
                  style: TextStyle(
                    fontSize: 12,
                    color: textMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, thickness: 1, color: cardBorder),
                const SizedBox(height: 14),

                // Disease Name Field (Read-only prefilled)
                TextField(
                  controller: diseaseNameController,
                  readOnly: true,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textMain,
                  ),
                  decoration: fieldStyle(
                    labelText: 'Disease Name',
                    helperText: 'Selected disease for this cure',
                  ),
                ),
                const SizedBox(height: 14),

                // Cure Title *
                TextField(
                  controller: cureTitleController,
                  style: const TextStyle(fontSize: 14, color: textMain),
                  decoration: fieldStyle(
                    labelText: 'Cure Title *',
                    hintText: 'e.g. Headache / Pain Cure',
                  ),
                ),
                const SizedBox(height: 14),

                // Source * Dropdown (Surah, Hadith, Darood)
                DropdownButtonFormField<String>(
                  initialValue: selectedSource,
                  decoration: fieldStyle(
                    labelText: 'Source *',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'Surah',
                      child: Text('Surah'),
                    ),
                    DropdownMenuItem(
                      value: 'Hadith',
                      child: Text('Hadith'),
                    ),
                    DropdownMenuItem(
                      value: 'Darood',
                      child: Text('Darood'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        selectedSource = val;
                        errorText = null;
                      });
                    }
                  },
                ),
                const SizedBox(height: 14),

                // Source-specific Dynamic Container (Light tinted background)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (selectedSource == 'Surah') ...[
                        // Surah selection
                        DropdownButtonFormField<SurahInfo>(
                          key: ValueKey(selectedSurah?.surahId),
                          initialValue: selectedSurah,
                          isExpanded: true,
                          decoration: fieldStyle(
                            labelText: 'Select Surah *',
                          ),
                          items: widget.surahs.map((surah) {
                            return DropdownMenuItem(
                              value: surah,
                              child: Text(
                                surah.surahName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSurah = value;
                              selectedAyatFrom = value == null ? null : 1;
                              selectedAyatTo = value == null ? null : 1;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('from-${selectedSurah?.surahId}'),
                                initialValue: ayahNumbers().contains(selectedAyatFrom)
                                    ? selectedAyatFrom
                                    : null,
                                decoration: fieldStyle(
                                  labelText: 'Ayat From *',
                                ),
                                items: ayahNumbers().map((number) {
                                  return DropdownMenuItem(
                                    value: number,
                                    child: Text('$number'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedAyatFrom = value;
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                key: ValueKey('to-${selectedSurah?.surahId}'),
                                initialValue: ayahNumbers().contains(selectedAyatTo)
                                    ? selectedAyatTo
                                    : null,
                                decoration: fieldStyle(
                                  labelText: 'Ayat To *',
                                ),
                                items: ayahNumbers().map((number) {
                                  return DropdownMenuItem(
                                    value: number,
                                    child: Text('$number'),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    selectedAyatTo = value;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ] else if (selectedSource == 'Hadith') ...[
                        // Hadith book & number
                        DropdownButtonFormField<String>(
                          initialValue: bookNameController.text.isNotEmpty
                              ? bookNameController.text
                              : 'Sahih Bukhari',
                          decoration: fieldStyle(
                            labelText: 'Book Name *',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Sahih Bukhari',
                              child: Text('Sahih Bukhari'),
                            ),
                            DropdownMenuItem(
                              value: 'Sahih Muslim',
                              child: Text('Sahih Muslim'),
                            ),
                            DropdownMenuItem(
                              value: 'Sunan Abi Dawud',
                              child: Text('Sunan Abi Dawud'),
                            ),
                            DropdownMenuItem(
                              value: 'Jami` at-Tirmidhi',
                              child: Text('Jami` at-Tirmidhi'),
                            ),
                            DropdownMenuItem(
                              value: 'Sunan an-Nasa\'i',
                              child: Text('Sunan an-Nasa\'i'),
                            ),
                            DropdownMenuItem(
                              value: 'Sunan Ibn Majah',
                              child: Text('Sunan Ibn Majah'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                bookNameController.text = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: hadithNumberController,
                          decoration: fieldStyle(
                            labelText: 'Hadith Number *',
                            hintText: 'e.g. 5686',
                          ),
                        ),
                      ] else if (selectedSource == 'Darood') ...[
                        DropdownButtonFormField<String>(
                          initialValue: daroodNameController.text.isNotEmpty
                              ? daroodNameController.text
                              : 'Darood Ibrahimi',
                          decoration: fieldStyle(
                            labelText: 'Darood Name *',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Darood Ibrahimi',
                              child: Text('Darood Ibrahimi'),
                            ),
                            DropdownMenuItem(
                              value: 'Darood-e-Taj',
                              child: Text('Darood-e-Taj'),
                            ),
                            DropdownMenuItem(
                              value: 'Darood-e-Tanjeena',
                              child: Text('Darood-e-Tanjeena'),
                            ),
                            DropdownMenuItem(
                              value: 'Darood-e-Mahi',
                              child: Text('Darood-e-Mahi'),
                            ),
                            DropdownMenuItem(
                              value: 'Darood-e-Shifa',
                              child: Text('Darood-e-Shifa'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                daroodNameController.text = val;
                              });
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 12),

                      // Count * (Helper: Number of recitations required)
                      TextField(
                        controller: countController,
                        keyboardType: TextInputType.number,
                        decoration: fieldStyle(
                          labelText: 'Count *',
                          hintText: '7',
                          helperText: 'Number of recitations required',
                        ),
                      ),
                    ],
                  ),
                ),

                if (errorText != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    errorText!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 16),

                // Action 1: + Add to Recitation Card
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: OutlinedButton(
                    onPressed: addToRecitationCard,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryGreen,
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: primaryGreen,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 18, color: primaryGreen),
                        SizedBox(width: 6),
                        Text(
                          '+ Add to Recitation Card',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Recitation Chain Items List shown right below the button
                if (recitationItems.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recitation Chain (${recitationItems.length})',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                      Text(
                        'Total: ${recitationItems.fold(0, (sum, it) => sum + it.count)} recitations',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...List.generate(recitationItems.length, (index) {
                    final item = recitationItems[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: primaryGreen,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.source == 'Surah'
                                      ? 'Ayat ${item.ayatFrom} to ${item.ayatTo} · ${item.count} recitations'
                                      : '${item.source} · ${item.count} recitations',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: deleteRed,
                              size: 20,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Delete item',
                            onPressed: () {
                              setState(() {
                                recitationItems.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const SizedBox(height: 14),

                // Action 2: 💾 Save Complete Cure
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: ElevatedButton(
                    onPressed: saveCompleteCure,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save_outlined, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Save Complete Cure',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
