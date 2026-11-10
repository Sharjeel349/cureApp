import 'dart:io';

import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/disease.dart';
import 'add_disease_screen.dart';
import 'app_style.dart';
import 'cure_managment_screen.dart';

class DiseasesScreen extends StatefulWidget {
  const DiseasesScreen({super.key});

  @override
  State<DiseasesScreen> createState() => _DiseasesScreenState();
}

class _DiseasesScreenState extends State<DiseasesScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final searchController = TextEditingController();

  List<Disease> allDiseases = [];
  List<Disease> filteredDiseases = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadDiseases();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> loadDiseases() async {
    final data = await dbHelper.fetchDiseases();
    if (!mounted) return;

    setState(() {
      allDiseases = data;
      filteredDiseases = data;
      isLoading = false;
    });
  }

  void searchDisease(String value) {
    final query = value.toLowerCase().trim();
    setState(() {
      filteredDiseases = allDiseases.where((disease) {
        return disease.diseaseName.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> openAddDisease() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddDiseaseScreen()),
    );
    await loadDiseases();
  }

  void openCures(Disease disease) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CureManagementScreen(disease: disease),
      ),
    ).then((_) => loadDiseases());
  }

  Future<void> editDisease(Disease disease) async {
    final controller = TextEditingController(text: disease.diseaseName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Disease'),
          content: TextField(
            controller: controller,
            decoration: formDecoration('Disease name'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result == null || result.isEmpty || disease.id == null) return;

    await dbHelper.updateDisease(
      Disease(
        id: disease.id,
        diseaseName: result,
        imageName: disease.imageName,
        description: disease.description,
      ),
    );
    await loadDiseases();
  }

  Future<void> deleteDisease(Disease disease) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Disease'),
          content: Text('Delete ${disease.diseaseName}?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (result != true || disease.id == null) return;
    await dbHelper.deleteDisease(disease.id!);
    await loadDiseases();
  }

  Future<void> showDiseaseOptions(Disease disease) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Disease'),
                onTap: () => Navigator.pop(context, 'edit'),
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete Disease'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
            ],
          ),
        );
      },
    );

    if (action == 'edit') {
      await editDisease(disease);
    } else if (action == 'delete') {
      await deleteDisease(disease);
    }
  }

  IconData iconForDisease(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('fever')) return Icons.psychology_alt_outlined;
    if (lower.contains('eye')) return Icons.visibility_off_outlined;
    if (lower.contains('stomach')) return Icons.medication_liquid_outlined;
    return Icons.sentiment_satisfied_alt_outlined;
  }

  Color cardColor(int index) {
    const colors = [
      Color(0xFFF8E8E5),
      Color(0xFFEAF5F1),
      Color(0xFFE9EBF1),
      Color(0xFFF7F0E4),
    ];
    return colors[index % colors.length];
  }

  Widget diseaseVisual(Disease disease, int index) {
    final imageName = disease.imageName?.trim() ?? '';

    if (imageName.isNotEmpty && File(imageName).existsSync()) {
      return Image.file(
        File(imageName),
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.contain,
      );
    }

    return Container(
      color: cardColor(index),
      child: Center(
        child: Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            iconForDisease(disease.diseaseName),
            color: darkGreen,
            size: 42,
          ),
        ),
      ),
    );
  }

  Widget diseaseCard(Disease disease, int index) {
    return GestureDetector(
      onTap: () => openCures(disease),
      onLongPress: () => showDiseaseOptions(disease),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: diseaseVisual(disease, index)),
            Container(
              height: 56,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                disease.diseaseName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textDark,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageCream,
      bottomNavigationBar: const MockBottomNav(currentIndex: 0),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
            decoration: const BoxDecoration(
              color: darkGreen,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(0),
                bottomRight: Radius.circular(0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Quranic Cure',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                TextField(
                  controller: searchController,
                  onChanged: searchDisease,
                  decoration: InputDecoration(
                    hintText: 'Search diseases...',
                    prefixIcon: const Icon(Icons.search, color: mutedText),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Select Disease',
                          style: TextStyle(
                            color: textDark,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: openAddDisease,
                        icon: const Icon(Icons.add, color: darkGreen),
                        label: const Text(
                          'Add New',
                          style: TextStyle(
                            color: darkGreen,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : filteredDiseases.isEmpty
                        ? const Center(child: Text('No diseases added yet'))
                        : GridView.builder(
                            cacheExtent: 700.0,
                            key: const PageStorageKey('disease-grid'),
                            padding: const EdgeInsets.only(bottom: 18),
                            itemCount: filteredDiseases.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 16,
                                  mainAxisSpacing: 16,
                                  childAspectRatio: 0.86,
                                ),
                            itemBuilder: (context, index) {
                              return diseaseCard(
                                filteredDiseases[index],
                                index,
                              );
                            },
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
