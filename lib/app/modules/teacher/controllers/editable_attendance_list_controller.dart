import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class EditableAttendanceListController extends GetxController {
  final attendanceRecords = <Map<String, dynamic>>[].obs;
  final isLoading = true.obs;

  final Map<String, String> periodTimes = const {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  void onInit() {
    super.onInit();
    loadTodayAttendance();
  }

  Future<void> loadTodayAttendance() async {
    isLoading.value = true;
    attendanceRecords.clear();

    final teacherUid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // Get teacher's classes
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .get();

      final data = teacherDoc.data() as Map<String, dynamic>;
      List<String> classIds = [];

      // Teachers use classIds field (array)
      if (data.containsKey('classIds')) {
        final classIdsValue = data['classIds'];
        if (classIdsValue is List) {
          classIds = List<String>.from(classIdsValue);
        }
      }

      // Load attendance records from all classes for today
      for (String classId in classIds) {
        final todaySnapshot = await FirebaseFirestore.instance
            .collection('attendance')
            .doc(classId)
            .collection(today)
            .get();

        for (var doc in todaySnapshot.docs) {
          final recordData = doc.data();

          // Check if this teacher marked this attendance
          if (recordData['markedByUid'] == teacherUid) {
            final timestamp = (recordData['timestamp'] as Timestamp).toDate();

            attendanceRecords.add({
              'classId': classId,
              'period': doc.id,
              'periodTime': periodTimes[doc.id] ?? '',
              'date': today,
              'timestamp': timestamp,
              'markedBy': recordData['markedBy'],
              'markedByUid': recordData['markedByUid'],
              'canEdit': _canEdit(timestamp),
            });
          }
        }
      }

      // Sort by timestamp descending (most recent first)
      attendanceRecords.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load attendance records: $e",
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

  bool _canEdit(DateTime timestamp) {
    final now = DateTime.now();
    final recordDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);

    // Can only edit if it's the same day and before midnight
    return recordDate.isAtSameMomentAs(today);
  }

  void navigateToEdit(Map<String, dynamic> record) {
    if (!record['canEdit']) {
      Get.snackbar(
        "Cannot Edit",
        "This attendance record can no longer be edited. Attendance can only be edited on the same day it was taken (until 11:59 PM).",
        backgroundColor: const Color(0xFFFF9800),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 4),
      );
      return;
    }

    Get.toNamed(
      '/edit-attendance',
      arguments: {
        'classId': record['classId'],
        'period': record['period'],
        'date': record['date'],
      },
    );
  }
}
