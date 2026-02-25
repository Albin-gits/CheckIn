import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EditAttendanceController extends GetxController {
  final students = <Map<String, dynamic>>[].obs;
  final attendance = <String, bool>{};
  final isLoading = true.obs;
  final canEdit = true.obs;

  late String classId;
  late String period;
  late String date;
  String markedByUid = '';

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

    // Get arguments
    final args = Get.arguments as Map<String, dynamic>;
    classId = args['classId'];
    period = args['period'];
    date = args['date'];

    loadAttendanceData();
  }

  Future<void> loadAttendanceData() async {
    isLoading.value = true;

    try {
      final teacherUid = FirebaseAuth.instance.currentUser!.uid;

      // Load existing attendance record
      final attendanceDoc = await FirebaseFirestore.instance
          .collection('attendance')
          .doc(classId)
          .collection(date)
          .doc(period)
          .get();

      if (!attendanceDoc.exists) {
        Get.back();
        Get.snackbar(
          "Error",
          "Attendance record not found",
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      final recordData = attendanceDoc.data() as Map<String, dynamic>;
      markedByUid = recordData['markedByUid'];

      // Verify permissions
      if (markedByUid != teacherUid) {
        canEdit.value = false;
        Get.back();
        Get.snackbar(
          "Access Denied",
          "You can only edit attendance that you marked yourself",
          backgroundColor: const Color(0xFFFF9800),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 3),
        );
        return;
      }

      // Verify it's still editable (same day)
      final timestamp = (recordData['timestamp'] as Timestamp).toDate();
      if (!_canEditToday(timestamp)) {
        canEdit.value = false;
        Get.back();
        Get.snackbar(
          "Cannot Edit",
          "This attendance can no longer be edited. Attendance can only be edited on the same day it was taken (until 11:59 PM).",
          backgroundColor: const Color(0xFFFF9800),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
        return;
      }

      // Extract students map
      Map<String, bool> savedAttendance = {};
      if (recordData.containsKey('students') && recordData['students'] is Map) {
        final studentsMap = recordData['students'] as Map<String, dynamic>;
        studentsMap.forEach((uid, present) {
          if (present is bool) {
            savedAttendance[uid] = present;
          }
        });
      }

      // Load students and their attendance
      final studentSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .get();

      students.value = studentSnapshot.docs.map((doc) {
        // Get saved attendance status
        attendance[doc.id] = savedAttendance[doc.id] ?? true;

        return {'uid': doc.id, 'name': doc['name']};
      }).toList();

      // Sort students by name
      students.sort(
        (a, b) => (a['name'] as String).compareTo(b['name'] as String),
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        "Error",
        "Failed to load attendance: $e",
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

  bool _canEditToday(DateTime timestamp) {
    final now = DateTime.now();
    final recordDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final today = DateTime(now.year, now.month, now.day);

    // Can only edit if it's the same day
    return recordDate.isAtSameMomentAs(today);
  }

  void toggleAttendance(String uid, bool value) {
    attendance[uid] = value;
    update();
  }

  Future<void> saveAttendance() async {
    if (!canEdit.value) {
      Get.snackbar(
        "Error",
        "You cannot edit this attendance record",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
      return;
    }

    try {
      final teacherUid = FirebaseAuth.instance.currentUser!.uid;
      final teacherDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .get();

      final teacherName = teacherDoc['name'];

      // Prepare attendance document with exact structure
      final attendanceData = {
        'students': Map<String, bool>.from(attendance),
        'period': period,
        'date': date,
        'markedBy': teacherName,
        'markedByUid': teacherUid,
        'timestamp': FieldValue.serverTimestamp(),
      };

      // Write using set() with merge: false
      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(classId)
          .collection(date)
          .doc(period)
          .set(attendanceData, SetOptions(merge: false));

      Get.back();
      Get.snackbar(
        "Success",
        "Attendance updated successfully",
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 2),
      );
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to update attendance: $e",
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }
}
