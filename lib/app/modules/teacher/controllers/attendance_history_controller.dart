import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendanceHistoryController extends GetxController {
  final history = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;
  final selectedClassId = ''.obs;
  final classList = <String>[].obs;

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
      loadHistory();
    }
  }

  void changeClass(String classId) {
    selectedClassId.value = classId;
    loadHistory();
  }

  Future<void> loadHistory() async {
    if (selectedClassId.value.isEmpty) return;

    isLoading.value = true;
    history.clear();

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // Check if current teacher is the faculty advisor for this class
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId.value)
          .get();

      final isFacultyAdvisor =
          classDoc.exists && classDoc.data()?['facultyAdvisorUid'] == uid;

      // Check the last 30 days for attendance records
      final now = DateTime.now();
      List<Map<String, dynamic>> foundDates = [];

      // Create a list of futures to execute in parallel
      List<Future<void>> queries = [];

      for (int i = 0; i < 30; i++) {
        final date = now.subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

        queries.add(
          FirebaseFirestore.instance
              .collection('attendance')
              .doc(selectedClassId.value)
              .collection(dateStr)
              .get()
              .then((dateSnapshot) async {
                if (dateSnapshot.docs.isNotEmpty) {
                  List<String> periods = [];

                  // If faculty advisor, show all periods
                  if (isFacultyAdvisor) {
                    periods = dateSnapshot.docs.map((doc) => doc.id).toList();
                  } else {
                    // For regular teachers, only show periods they marked
                    for (var doc in dateSnapshot.docs) {
                      final data = doc.data();
                      if (data['markedByUid'] == uid) {
                        periods.add(doc.id);
                      }
                    }
                  }

                  // Only add to history if there are periods to show
                  if (periods.isNotEmpty) {
                    foundDates.add({
                      'date': dateStr,
                      'periodCount': periods.length,
                      'periods': periods,
                    });
                  }
                }
              }),
        );
      }

      // Wait for all queries to complete
      await Future.wait(queries);

      // Sort by date descending (newest first)
      foundDates.sort((a, b) => b['date'].compareTo(a['date']));
      history.value = foundDates;
    } catch (e) {
      print('Error loading history: $e');
      Get.snackbar(
        'Error',
        'Failed to load attendance history',
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
