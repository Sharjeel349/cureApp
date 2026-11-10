import 'package:flutter/material.dart';

import '../db/database_helper.dart';
import '../models/cure.dart';
import '../models/disease.dart';
import '../models/log_entry.dart';
import 'app_style.dart';
import 'recitation_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;

  List<LogEntry> logs = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadLogs();
  }

  Future<void> loadLogs() async {
    final data = await dbHelper.fetchLogs();
    if (!mounted) return;

    setState(() {
      logs = data;
      isLoading = false;
    });
  }

  String statusText(LogEntry log) {
    return log.status == 'COMPLETED' ? 'Completed' : 'Partial';
  }

  Color statusColor(LogEntry log) {
    return log.status == 'COMPLETED' ? Colors.green : Colors.orange;
  }

  String dateText(LogEntry log) {
    final value = log.dateEnd ?? log.dateStart ?? '';
    if (value.length >= 10) return value.substring(0, 10);
    return value;
  }

  Future<void> continueLog(LogEntry log) async {
    final diseaseId = log.diseaseId;
    final cureId = log.cureId;

    if (diseaseId == null || cureId == null || diseaseId == 0 || cureId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This partial log cannot be continued')),
      );
      return;
    }

    final Disease? disease = await dbHelper.fetchDiseaseById(diseaseId);
    final Cure? cure = await dbHelper.fetchCureById(cureId);

    if (!mounted) return;

    if (disease == null || cure == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Cure details not found')));
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            RecitationScreen(disease: disease, cure: cure, log: log),
      ),
    );

    await loadLogs();
  }

  DataRow logRow(LogEntry log) {
    final color = statusColor(log);

    return DataRow(
      cells: [
        DataCell(Text(log.diseaseName)),
        DataCell(
          SizedBox(
            width: 76,
            child: Text(
              log.surahName,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        DataCell(Text('${log.currentCount}/${log.targetCount}')),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              statusText(log),
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        DataCell(Text(dateText(log))),
        DataCell(
          log.status == 'COMPLETED'
              ? const Text('-')
              : TextButton(
                  onPressed: () => continueLog(log),
                  child: const Text('Continue'),
                ),
        ),
      ],
    );
  }

  Widget buildTable() {
    if (logs.isEmpty) {
      return const Center(child: Text('No logs yet'));
    }

    return RefreshIndicator(
      onRefresh: loadLogs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 28, 20),
        children: [
          Container(
            decoration: roundedWhiteBox(radius: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 48,
                dataRowMinHeight: 64,
                dataRowMaxHeight: 84,
                columnSpacing: 28,
                headingTextStyle: const TextStyle(
                  color: textDark,
                  fontWeight: FontWeight.w900,
                ),
                columns: const [
                  DataColumn(label: Text('DISEASE')),
                  DataColumn(label: Text('SURAH')),
                  DataColumn(label: Text('COUNT')),
                  DataColumn(label: Text('STATUS')),
                  DataColumn(label: Text('DATE')),
                  DataColumn(label: Text('ACTION')),
                ],
                rows: logs.map(logRow).toList(),
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
      backgroundColor: pageCream,
      bottomNavigationBar: const MockBottomNav(currentIndex: 1),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(30, 82, 30, 34),
            color: darkGreen,
            child: const Text(
              'Logs',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : buildTable(),
          ),
        ],
      ),
    );
  }
}
