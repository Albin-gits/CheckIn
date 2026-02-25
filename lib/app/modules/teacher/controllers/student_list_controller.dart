import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StudentListController extends GetxController {
  final students = <Map<String, dynamic>>[].obs;
  final selectedClassId = ''.obs;
  final classList = <String>[].obs;
  final isFacultyAdvisor = false.obs;
  final isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    loadClasses();
  }

  Future<void> loadClasses() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final teacher = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    final data = teacher.data() as Map<String, dynamic>;
    List<String> classIds = [];

    // Teachers use classIds field (array)
    if (data.containsKey('classIds')) {
      final classIdsValue = data['classIds'];
      if (classIdsValue is List) {
        classIds = List<String>.from(classIdsValue);
      }
    }

    classList.value = classIds;

    if (classIds.isNotEmpty) {
      selectedClassId.value = classIds[0];
      loadStudents();
    }
  }

  void changeClass(String classId) {
    selectedClassId.value = classId;
    loadStudents();
  }

  Future<void> loadStudents() async {
    if (selectedClassId.value.isEmpty) return;

    isLoading.value = true;
    students.clear();
    isFacultyAdvisor.value = false;

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Check if current teacher is the faculty advisor for this class
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId.value)
          .get();

      isFacultyAdvisor.value =
          classDoc.exists && classDoc.data()?['facultyAdvisorUid'] == uid;

      // Only load students if teacher is the faculty advisor
      if (isFacultyAdvisor.value) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('classId', isEqualTo: selectedClassId.value)
            .get();

        students.value = snapshot.docs
            .map((e) => {'name': e['name'], 'email': e['email']})
            .toList();
      }
    } catch (e) {
      print('Error loading students: $e');
      Get.snackbar(
        'Error',
        'Failed to load students',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isLoading.value = false;
    }
  }
}
