import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AttendanceMonitoringController extends GetxController {
  final overallAttendance = 0.0.obs;
  final classesMarked = 0.obs;
  final totalClasses = 0.obs;
  final totalDefaulters = 0.obs;
  final selectedDate = DateTime.now().obs;
  final isLoading = false.obs;

  final departmentAttendance = <Map<String, dynamic>>[].obs;
  final todaysClassAttendance = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadAttendanceData();
  }

  Future<void> loadAttendanceData() async {
    try {
      isLoading.value = true;

      await Future.wait([
        loadOverallStats(),
        loadDepartmentAttendance(),
        loadTodaysClassAttendance(),
      ]);
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load attendance data: $e",
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

  Future<void> loadOverallStats() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      // Get total classes for today
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .get();
      totalClasses.value = classesSnapshot.docs.length;

      // Get marked attendance for today
      final attendanceSnapshot = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: startOfDay)
          .where('date', isLessThan: startOfDay.add(const Duration(days: 1)))
          .get();

      // Count unique classes marked
      final markedClasses = <String>{};
      int totalPresent = 0;
      int totalStudents = 0;

      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data();
        markedClasses.add(data['classId'] ?? '');

        if (data['status'] == 'present') {
          totalPresent++;
        }
        totalStudents++;
      }

      classesMarked.value = markedClasses.length;

      // Calculate overall attendance percentage
      if (totalStudents > 0) {
        overallAttendance.value = (totalPresent / totalStudents) * 100;
      }

      // Calculate defaulters (students with attendance < 75%)
      await calculateDefaulters();
    } catch (e) {
      print('Error loading overall stats: $e');
    }
  }

  Future<void> calculateDefaulters() async {
    try {
      final students = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      int defaulterCount = 0;

      for (var student in students.docs) {
        final studentId = student.id;

        // Get student's attendance records
        final attendanceRecords = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .get();

        if (attendanceRecords.docs.isEmpty) continue;

        int presentCount = attendanceRecords.docs
            .where((doc) => doc.data()['status'] == 'present')
            .length;

        double percentage =
            (presentCount / attendanceRecords.docs.length) * 100;

        if (percentage < 75) {
          defaulterCount++;
        }
      }

      totalDefaulters.value = defaulterCount;
    } catch (e) {
      print('Error calculating defaulters: $e');
    }
  }

  Future<void> loadDepartmentAttendance() async {
    try {
      final departments = await FirebaseFirestore.instance
          .collection('departments')
          .get();

      final List<Map<String, dynamic>> deptData = [];

      for (var dept in departments.docs) {
        final deptId = dept.id;
        final deptName = dept.data()['name'] ?? 'Unknown';

        // Get classes in this department
        final classesInDept = await FirebaseFirestore.instance
            .collection('classes')
            .where('departmentId', isEqualTo: deptId)
            .get();

        int totalPresent = 0;
        int totalRecords = 0;

        // Get attendance for all classes in department
        for (var classDoc in classesInDept.docs) {
          final attendanceRecords = await FirebaseFirestore.instance
              .collection('attendance')
              .where('classId', isEqualTo: classDoc.id)
              .get();

          for (var record in attendanceRecords.docs) {
            if (record.data()['status'] == 'present') {
              totalPresent++;
            }
            totalRecords++;
          }
        }

        if (totalRecords > 0) {
          final percentage = (totalPresent / totalRecords) * 100;
          deptData.add({
            'id': deptId,
            'name': deptName,
            'percentage': percentage.toStringAsFixed(1),
          });
        }
      }

      departmentAttendance.value = deptData;
    } catch (e) {
      print('Error loading department attendance: $e');
    }
  }

  Future<void> loadTodaysClassAttendance() async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final classes = await FirebaseFirestore.instance
          .collection('classes')
          .get();

      final List<Map<String, dynamic>> classData = [];

      for (var classDoc in classes.docs) {
        final classId = classDoc.id;
        final className = classDoc.data()['name'] ?? 'Unknown';

        // Get today's attendance for this class
        final attendanceRecords = await FirebaseFirestore.instance
            .collection('attendance')
            .where('classId', isEqualTo: classId)
            .where('date', isGreaterThanOrEqualTo: startOfDay)
            .where('date', isLessThan: startOfDay.add(const Duration(days: 1)))
            .get();

        if (attendanceRecords.docs.isEmpty) continue;

        int present = 0;
        int absent = 0;

        for (var record in attendanceRecords.docs) {
          if (record.data()['status'] == 'present') {
            present++;
          } else {
            absent++;
          }
        }

        classData.add({
          'id': classId,
          'name': className,
          'present': present,
          'absent': absent,
        });
      }

      todaysClassAttendance.value = classData;
    } catch (e) {
      print('Error loading today\'s class attendance: $e');
    }
  }

  String getFormattedDate() {
    return DateFormat('MMM dd, yyyy').format(selectedDate.value);
  }

  Future<void> changeDate(DateTime newDate) async {
    selectedDate.value = newDate;
    await loadAttendanceData();
  }

  Future<void> refreshData() async {
    await loadAttendanceData();
  }
}
