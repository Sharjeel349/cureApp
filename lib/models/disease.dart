class Disease {
  int? id;
  String diseaseName;
  String? imageName;
  String? description;

  Disease({
    this.id,
    required this.diseaseName,
    this.imageName,
    this.description,
  });

  factory Disease.fromMap(Map<String, dynamic> map) {
    return Disease(
      id: map['Id'],
      diseaseName: map['DiseaseName'] ?? '',
      imageName: map['ImageName'],
      description: map['Description'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'DiseaseName': diseaseName,
      'ImageName': imageName,
      'Description': description,
    };

    if (id != null) {
      map['Id'] = id;
    }

    return map;
  }
}
