import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../db/database_helper.dart';
import '../models/disease.dart';

class AddDiseaseScreen extends StatefulWidget {
  const AddDiseaseScreen({super.key});

  @override
  State<AddDiseaseScreen> createState() => _AddDiseaseScreenState();
}

class _AddDiseaseScreenState extends State<AddDiseaseScreen> {
  final DatabaseHelper dbHelper = DatabaseHelper.instance;
  final ImagePicker imagePicker = ImagePicker();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();

  String? selectedImagePath;
  String? errorMessage;
  bool isSaving = false;

  static const Color primaryGreen = Color(0xFF0B492C);
  static const Color labelColor = Color(0xFF374151);
  static const Color borderGrey = Color(0xFFD1D5DB);
  static const Color hintGrey = Color(0xFF9CA3AF);

  @override
  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  Future<void> pickDiseaseImage() async {
    try {
      final image = await imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        selectedImagePath = image.path;
      });
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<String?> saveImageToAppFolder() async {
    if (selectedImagePath == null) return null;

    final sourceFile = File(selectedImagePath!);
    if (!await sourceFile.exists()) return null;

    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory('${directory.path}/disease_images');
    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }

    final extension = selectedImagePath!.contains('.')
        ? selectedImagePath!.substring(selectedImagePath!.lastIndexOf('.'))
        : '.jpg';
    final fileName =
        'disease_${DateTime.now().millisecondsSinceEpoch}$extension';
    final savedFile = await sourceFile.copy('${imageDirectory.path}/$fileName');
    return savedFile.path;
  }

  Future<void> saveDisease() async {
    if (isSaving) return;

    final diseaseName = nameController.text.trim();
    if (diseaseName.isEmpty) {
      setState(() {
        errorMessage = 'Please enter a disease name';
      });
      return;
    }

    setState(() {
      isSaving = true;
      errorMessage = null;
    });

    try {
      final savedImagePath = await saveImageToAppFolder();

      final newDisease = Disease(
        diseaseName: diseaseName,
        imageName: savedImagePath,
        description: descriptionController.text.trim().isEmpty
            ? null
            : descriptionController.text.trim(),
      );

      await dbHelper.insertDisease(newDisease);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Disease added successfully'),
          backgroundColor: primaryGreen,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error inserting disease: $e');
      if (!mounted) return;
      setState(() {
        isSaving = false;
        errorMessage = 'Failed to add disease: $e';
      });
    }
  }

  InputDecoration inputStyle({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: hintGrey,
        fontSize: 14,
        fontWeight: FontWeight.normal,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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

  Widget fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: labelColor,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Header: Title and Close 'X' button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add New Disease',
                    style: TextStyle(
                      color: Color(0xFF1F2937),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF4B5563),
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),

            // Form Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Field 1: Disease Name
                    fieldLabel('Disease Name'),
                    TextField(
                      controller: nameController,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      onChanged: (_) {
                        if (errorMessage != null) {
                          setState(() {
                            errorMessage = null;
                          });
                        }
                      },
                      decoration: inputStyle(hintText: 'Enter disease name'),
                    ),
                    const SizedBox(height: 18),

                    // Field 2: Disease Image
                    fieldLabel('Disease Image'),
                    InkWell(
                      onTap: pickDiseaseImage,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 48,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: primaryGreen,
                            width: 1.2,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate_outlined,
                              color: primaryGreen,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Choose Image from Gallery',
                              style: TextStyle(
                                color: primaryGreen,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (selectedImagePath != null) ...[
                      const SizedBox(height: 10),
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(selectedImagePath!),
                              height: 120,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 6,
                            right: 6,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedImagePath = null;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Field 3: Description
                    fieldLabel('Description'),
                    TextField(
                      controller: descriptionController,
                      minLines: 4,
                      maxLines: 6,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF111827),
                      ),
                      decoration: inputStyle(hintText: 'Enter disease description'),
                    ),

                    if (errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        errorMessage!,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Action Buttons: Cancel and Add Disease
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                side: const BorderSide(
                                  color: borderGrey,
                                  width: 1.2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  color: Color(0xFF1F2937),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed: isSaving ? null : saveDisease,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Add Disease',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
