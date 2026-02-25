import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceDetailController extends GetxController {
  final isLoading = true.obs;
  final periodData = <Map<String, dynamic>>[].obs;

  late String classId;
  late String date;

  @override
  void onInit() {
    super.onInit();
    classId = Get.parameters['classId'] ?? '';
    date = Get.parameters['date'] ?? '';
    loadAttendanceDetails();
  }

  Future<void> loadAttendanceDetails() async {
    isLoading.value = true;
    periodData.clear();

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Check if current teacher is the faculty advisor for this class
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();

      final isFacultyAdvisor =
          classDoc.exists && classDoc.data()?['facultyAdvisorUid'] == uid;

      final snapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(classId)
          .collection(date)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();

        // For regular teachers, only show periods they marked
        if (!isFacultyAdvisor && data['markedByUid'] != uid) {
          continue; // Skip this period
        }

        // Get student attendance from the students map
        Map<String, dynamic> studentAttendance = {};
        List<String> presentStudents = [];
        List<String> absentStudents = [];

        // Extract students map from the new structure
        if (data.containsKey('students') && data['students'] is Map) {
          final studentsMap = data['students'] as Map<String, dynamic>;

          for (var entry in studentsMap.entries) {
            final uid = entry.key;
            final isPresent = entry.value as bool;

            // Get student name and verify they belong to this class
            final studentDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get();

            if (studentDoc.exists) {
              final studentData = studentDoc.data() as Map<String, dynamic>;
              final studentName = studentData['name'] as String;
              final studentClassId = studentData['classId'];

              // Only include students who belong to this class
              if (studentClassId == classId) {
                studentAttendance[uid] = {
                  'name': studentName,
                  'present': isPresent,
                };

                if (isPresent) {
                  presentStudents.add(studentName);
                } else {
                  absentStudents.add(studentName);
                }
              }
            }
          }
        }

        periodData.add({
          'period': doc.id,
          'markedBy': data['markedBy'] ?? 'Unknown',
          'timestamp': data['timestamp'],
          'studentAttendance': studentAttendance,
          'presentStudents': presentStudents,
          'absentStudents': absentStudents,
          'presentCount': presentStudents.length,
          'absentCount': absentStudents.length,
        });
      }

      // Sort periods
      periodData.sort((a, b) => a['period'].compareTo(b['period']));
    } catch (e) {
      print('Error loading attendance details: $e');
      Get.snackbar(
        'Error',
        'Failed to load attendance details',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }

    isLoading.value = false;
  }
}
