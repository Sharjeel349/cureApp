class LogEntry {
  int? id;
  int? diseaseId;
  int? cureId;
  String diseaseName;
  String surahName;
  int targetCount;
  int currentCount;
  String status;
  String? dateStart;
  String? dateEnd;

  LogEntry({
    this.id,
    this.diseaseId,
    this.cureId,
    required this.diseaseName,
    required this.surahName,
    required this.targetCount,
    this.currentCount = 0,
    this.status = 'PENDING',
    this.dateStart,
    this.dateEnd,
  });

  factory LogEntry.fromMap(Map<String, dynamic> map) {
    return LogEntry(
      id: map['Id'],
      diseaseId: map['DiseaseId'],
      cureId: map['CureId'],
      diseaseName: map['DiseaseName'] ?? '',
      surahName: map['SurahName'] ?? '',
      targetCount: map['TargetCount'] ?? 0,
      currentCount: map['CurrentCount'] ?? 0,
      status: map['Status'] ?? 'PENDING',
      dateStart: map['DateStart'],
      dateEnd: map['DateEnd'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'DiseaseId': diseaseId,
      'CureId': cureId,
      'DiseaseName': diseaseName,
      'SurahName': surahName,
      'TargetCount': targetCount,
      'CurrentCount': currentCount,
      'Status': status,
      'DateStart': dateStart,
      'DateEnd': dateEnd,
    };

    if (id != null) {
      map['Id'] = id;
    }

    return map;
  }
}
