import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'reports_analytics_controller.dart';

class AdminDashboardController extends GetxController {
  // DASHBOARD METRICS
  final totalDepartments = 0.obs;
  final totalTeachers = 0.obs;
  final totalStudents = 0.obs;
  final attendanceCompliance = 0.0.obs;
  final totalDefaulters = 0.obs;

  // RECENT ACTIVITIES
  final RxList<Map<String, dynamic>> recentActivities =
      <Map<String, dynamic>>[].obs;

  // UI STATE
  final selectedTab = 0.obs;
  final isMenuOpen = false.obs;
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadDashboardData();
  }

  // TAB CHANGE + AUTO CLOSE MENU
  void changeTab(int index) {
    selectedTab.value = index;
    isMenuOpen.value = false;
  }

  void toggleMenu() {
    isMenuOpen.value = !isMenuOpen.value;
  }

  // LOAD DASHBOARD DATA
  Future<void> loadDashboardData() async {
    try {
      isLoading.value = true;

      final deptSnapshot = await FirebaseFirestore.instance
          .collection('departments')
          .get();
      totalDepartments.value = deptSnapshot.docs.length;

      final teachersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'teacher')
          .get();
      totalTeachers.value = teachersSnapshot.docs.length;

      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();
      totalStudents.value = studentsSnapshot.docs.length;

      await calculateAttendanceMetrics();
      await loadRecentActivities();
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to load dashboard data",
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

  // TEMP METRICS
  Future<void> calculateAttendanceMetrics() async {
    attendanceCompliance.value = 78.5;
    totalDefaulters.value = 23;
  }

  // LOAD RECENT ACTIVITIES
  Future<void> loadRecentActivities() async {
    try {
      final List<Map<String, dynamic>> activities = [];

      // Get recent users (last 10)
      final recentUsers = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in recentUsers.docs) {
        final data = doc.data();
        final role = data['role'] ?? 'user';
        final name = data['name'] ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          activities.add({
            'icon': role == 'teacher' ? Icons.person_add : Icons.person_add_alt,
            'title': 'New ${role} added',
            'subtitle': '$name joined the system',
            'time': _getTimeAgo(createdAt),
            'timestamp': createdAt,
            'color': role == 'teacher'
                ? const Color(0xFF4CAF50)
                : const Color(0xFF2196F3),
          });
        }
      }

      // Get recent departments (last 5)
      final recentDepts = await FirebaseFirestore.instance
          .collection('departments')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      for (var doc in recentDepts.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          activities.add({
            'icon': Icons.business,
            'title': 'Department created',
            'subtitle': '$name department added',
            'time': _getTimeAgo(createdAt),
            'timestamp': createdAt,
            'color': const Color(0xFFFF9800),
          });
        }
      }

      // Get recent classes (last 5)
      final recentClasses = await FirebaseFirestore.instance
          .collection('classes')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      for (var doc in recentClasses.docs) {
        final data = doc.data();
        final name = data['name'] ?? 'Unknown';
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        if (createdAt != null) {
          activities.add({
            'icon': Icons.class_,
            'title': 'Class created',
            'subtitle': '$name class added',
            'time': _getTimeAgo(createdAt),
            'timestamp': createdAt,
            'color': const Color(0xFF9C27B0),
          });
        }
      }

      // Sort all activities by timestamp
      activities.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      // Keep only the 10 most recent
      recentActivities.value = activities.take(10).toList();
    } catch (e) {
      print('Error loading recent activities: $e');
      recentActivities.value = [];
    }
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays > 0) {
      return difference.inDays == 1
          ? 'Yesterday'
          : '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> logout() async {
    if (Get.isRegistered<ReportsAnalyticsController>()) {
      Get.delete<ReportsAnalyticsController>(force: true);
    }
    await FirebaseAuth.instance.signOut();
    Get.offAllNamed('/auth');
  }
}
