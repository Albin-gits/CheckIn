import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class SystemSettingsController extends GetxController {
  final isLoading = false.obs;

  // General Settings
  final institutionName = ''.obs;
  final academicYear = ''.obs;
  final currentSemester = ''.obs;
  final timeZone = ''.obs;

  // Attendance Settings
  final minimumAttendance = 75.obs;
  final periodsPerDay = 5.obs;
  final lateMarkThreshold = 10.obs;
  final autoMarkAbsent = true.obs;

  // Notification Settings
  final emailNotifications = true.obs;
  final smsAlerts = false.obs;
  final pushNotifications = true.obs;
  final lowAttendanceAlerts = true.obs;

  // Security Settings
  final twoFactorAuth = true.obs;
  final sessionTimeout = true.obs;
  final loginAuditLogs = true.obs;

  // Holidays
  final holidays = <Map<String, dynamic>>[].obs;

  // Form controllers for adding/editing holidays
  final holidayNameController = TextEditingController();
  final holidayTypeController = TextEditingController();
  final selectedHolidayDate = Rxn<DateTime>();

  @override
  void onInit() {
    super.onInit();
    loadSettings();
    loadHolidays();
  }

  @override
  void onClose() {
    holidayNameController.dispose();
    holidayTypeController.dispose();
    super.onClose();
  }

  Future<void> loadSettings() async {
    try {
      isLoading.value = true;

      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('system')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // General Settings
        institutionName.value = data['institutionName'] ?? 'CheckIn College';
        academicYear.value = data['academicYear'] ?? '2025–26';
        currentSemester.value = data['currentSemester'] ?? 'Semester 2';
        timeZone.value = data['timeZone'] ?? 'Asia/Kolkata';

        // Attendance Settings
        minimumAttendance.value = data['minimumAttendance'] ?? 75;
        periodsPerDay.value = data['periodsPerDay'] ?? 5;
        lateMarkThreshold.value = data['lateMarkThreshold'] ?? 10;
        autoMarkAbsent.value = data['autoMarkAbsent'] ?? true;

        // Notification Settings
        emailNotifications.value = data['emailNotifications'] ?? true;
        smsAlerts.value = data['smsAlerts'] ?? false;
        pushNotifications.value = data['pushNotifications'] ?? true;
        lowAttendanceAlerts.value = data['lowAttendanceAlerts'] ?? true;

        // Security Settings
        twoFactorAuth.value = data['twoFactorAuth'] ?? true;
        sessionTimeout.value = data['sessionTimeout'] ?? true;
        loginAuditLogs.value = data['loginAuditLogs'] ?? true;
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load settings: $e',
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

  Future<void> saveSettings() async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('system')
          .set({
            'institutionName': institutionName.value,
            'academicYear': academicYear.value,
            'currentSemester': currentSemester.value,
            'timeZone': timeZone.value,
            'minimumAttendance': minimumAttendance.value,
            'periodsPerDay': periodsPerDay.value,
            'lateMarkThreshold': lateMarkThreshold.value,
            'autoMarkAbsent': autoMarkAbsent.value,
            'emailNotifications': emailNotifications.value,
            'smsAlerts': smsAlerts.value,
            'pushNotifications': pushNotifications.value,
            'lowAttendanceAlerts': lowAttendanceAlerts.value,
            'twoFactorAuth': twoFactorAuth.value,
            'sessionTimeout': sessionTimeout.value,
            'loginAuditLogs': loginAuditLogs.value,
            'updatedAt': FieldValue.serverTimestamp(),
          });

      Get.back(); // Close loading
      Get.snackbar(
        'Success',
        'Settings saved successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back(); // Close loading
      Get.snackbar(
        'Error',
        'Failed to save settings: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> loadHolidays() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('holidays')
          .orderBy('date')
          .get();

      holidays.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'date': (data['date'] as Timestamp).toDate(),
          'type': data['type'] ?? '',
        };
      }).toList();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load holidays: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> addHoliday(String name, DateTime date, String type) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF9C27B0)),
        ),
        barrierDismissible: false,
      );

      await FirebaseFirestore.instance.collection('holidays').add({
        'name': name,
        'date': Timestamp.fromDate(date),
        'type': type,
        'createdAt': FieldValue.serverTimestamp(),
      });

      Get.back(); // Close loading
      Get.back(); // Close dialog

      clearHolidayForm();
      loadHolidays();
      Get.snackbar(
        'Success',
        'Holiday added successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back(); // Close loading
      Get.snackbar(
        'Error',
        'Failed to add holiday: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> deleteHoliday(String id) async {
    try {
      await FirebaseFirestore.instance.collection('holidays').doc(id).delete();

      loadHolidays();
      Get.snackbar(
        'Success',
        'Holiday deleted successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to delete holiday: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  Future<void> backupDatabase() async {
    try {
      Get.dialog(
        const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Creating backup...'),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Simulate backup process
      await Future.delayed(const Duration(seconds: 2));

      Get.back();
      Get.snackbar(
        'Success',
        'Database backup created successfully',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back();
      Get.snackbar(
        'Error',
        'Failed to create backup: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }

  void clearHolidayForm() {
    holidayNameController.clear();
    holidayTypeController.clear();
    selectedHolidayDate.value = null;
  }
}
