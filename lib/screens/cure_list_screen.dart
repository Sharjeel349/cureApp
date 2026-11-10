import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/cure.dart';
import '../models/disease.dart';
import 'app_style.dart';
import 'recitation_screen.dart';

class CureListScreen extends StatefulWidget {
  final Disease disease;

  const CureListScreen({super.key, required this.disease});

  @override
  State<CureListScreen> createState() => _CureListScreenState();
}

class _CureListScreenState extends State<CureListScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  List<Cure> cures = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadCures();
  }

  Future<void> loadCures() async {
    if (widget.disease.id == null) return;
    final data = await dbHelper.fetchCuresByDiseaseId(widget.disease.id!);

    if (!mounted) return;
    setState(() {
      cures = data;
      isLoading = false;
    });
  }

  String ayahRange(Cure cure) {
    if (cure.ayatFrom == cure.ayatTo) {
      return 'Ayat: ${cure.ayatFrom} | Count: ${cure.targetCount}';
    }
    return 'Ayat: ${cure.ayatFrom}-${cure.ayatTo} | Count: ${cure.targetCount}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pageCream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(30, 70, 30, 34),
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
                const SizedBox(height: 28),
                Text(
                  widget.disease.diseaseName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : cures.isEmpty
                ? const Center(child: Text('No cures available'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                    itemCount: cures.length,
                    itemBuilder: (context, index) {
                      final cure = cures[index];

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(20),
                        decoration: roundedWhiteBox(radius: 14),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            cure.surahName,
                            style: const TextStyle(
                              color: textDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          subtitle: Text(
                            cure.instructions.isEmpty
                                ? ayahRange(cure)
                                : '${ayahRange(cure)}\n${cure.instructions}',
                          ),
                          trailing: const Icon(
                            Icons.chevron_right,
                            color: darkGreen,
                          ),
                          onTap: () => openRecitation(cure),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
