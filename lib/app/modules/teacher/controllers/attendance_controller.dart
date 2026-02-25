import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AttendanceController extends GetxController {
  final students = <Map<String, dynamic>>[].obs;
  final attendance = <String, bool>{};

  final selectedPeriod = 'P1'.obs;
  final selectedClassId = ''.obs;
  final classList = <String>[].obs;
  final classNames = <String, String>{}.obs; // Map of classId -> className
  final availablePeriods = <String>[].obs;
  final isAttendanceSaved = false.obs;
  final isAuthorized = false.obs;
  final isCheckingAuth = false.obs;
  final assignedSlotInfo =
      ''.obs; // Info about which slot the teacher is assigned to

  String _teacherDepartmentId = '';

  String _todayDayKey() {
    switch (DateTime.now().weekday) {
      case DateTime.monday:
        return 'mon';
      case DateTime.tuesday:
        return 'tue';
      case DateTime.wednesday:
        return 'wed';
      case DateTime.thursday:
        return 'thu';
      case DateTime.friday:
        return 'fri';
      default:
        return '';
    }
  }

  // Period time definitions
  final Map<String, Map<String, int>> periodTimes = {
    'P1': {'startHour': 8, 'startMinute': 30, 'endHour': 9, 'endMinute': 25},
    'P2': {'startHour': 9, 'startMinute': 30, 'endHour': 10, 'endMinute': 20},
    'P3': {'startHour': 10, 'startMinute': 40, 'endHour': 11, 'endMinute': 35},
    'P4': {'startHour': 11, 'startMinute': 40, 'endHour': 12, 'endMinute': 30},
    'P5': {'startHour': 12, 'startMinute': 35, 'endHour': 13, 'endMinute': 35},
  };

  @override
  void onInit() {
    super.onInit();
    updateAvailablePeriods();
    loadClasses();
  }

  Future<bool> _isAssignedForTodaySlot({
    required String classId,
    required String period,
  }) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    debugPrint('=== Authorization Check ===');
    debugPrint('Teacher UID: $uid');
    debugPrint('Class ID: $classId');
    debugPrint('Period: $period');
    debugPrint('Department ID: $_teacherDepartmentId');

    // Only check timetable assignment - faculty advisor does NOT grant automatic access
    final dayKey = _todayDayKey();
    debugPrint('Day Key: $dayKey');
    if (dayKey.isEmpty) {
      debugPrint(' Not a weekday');
      assignedSlotInfo.value =
          'Timetable only available for weekdays (Mon-Fri)';
      return false;
    }
    if (_teacherDepartmentId.isEmpty) {
      await _loadTeacherDepartmentId();
      debugPrint('Loaded Department ID: $_teacherDepartmentId');
      if (_teacherDepartmentId.isEmpty) {
        debugPrint(' No department ID');
        assignedSlotInfo.value = 'No department assigned to your account';
        return false;
      }
    }

    try {
      // Correct path: timetable/{departmentId}/{classId}/{day}/slots/{period}
      final slotRef = FirebaseFirestore.instance
          .collection('timetable')
          .doc(_teacherDepartmentId)
          .collection(classId)
          .doc(dayKey)
          .collection('slots')
          .doc(period);

      debugPrint(
        'Checking timetable path: timetable/$_teacherDepartmentId/$classId/$dayKey/slots/$period',
      );
      final slotDoc = await slotRef.get();

      if (!slotDoc.exists) {
        debugPrint('❌ Slot document does not exist in timetable');
        assignedSlotInfo.value =
            'No timetable entry found for this class/period';
        return false;
      }

      final data = slotDoc.data() as Map<String, dynamic>;
      final teacherUid = data['teacherUid'];
      final overrideTeacherUid = data['overrideTeacherUid'];
      final overrideEnabled = data['overrideEnabled'] == true;

      debugPrint(
        'Slot data: teacherUid=$teacherUid, overrideTeacherUid=$overrideTeacherUid, overrideEnabled=$overrideEnabled',
      );

      final isPrimary = teacherUid == uid;
      final isSubstitute = overrideEnabled && overrideTeacherUid == uid;

      if (isPrimary) {
        debugPrint('✓ Authorized as Primary Teacher');
        return true;
      }
      if (isSubstitute) {
        debugPrint('✓ Authorized as Substitute Teacher');
        return true;
      }

      debugPrint('❌ Not authorized - UID does not match');
      return false;
    } catch (e, stackTrace) {
      debugPrint('❌ Error checking timetable assignment: $e');
      debugPrint('Stack trace: $stackTrace');
      assignedSlotInfo.value = 'Error: $e';
      // If timetable is not accessible, deny access (unless faculty advisor checked above)
      return false;
    }
  }

  Future<void> _loadTeacherDepartmentId() async {
    final teacherUid = FirebaseAuth.instance.currentUser!.uid;
    final teacherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid)
        .get();
    final data = teacherDoc.data() as Map<String, dynamic>?;
    _teacherDepartmentId = (data?['departmentId'] ?? '').toString();
  }

  Future<void> _loadAssignedSlotInfo() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final dayKey = _todayDayKey();

    debugPrint('=== Loading Assigned Slot Info ===');
    debugPrint('Teacher UID: $uid');
    debugPrint('Day Key: $dayKey');
    debugPrint('Department ID: $_teacherDepartmentId');

    if (dayKey.isEmpty || _teacherDepartmentId.isEmpty) {
      assignedSlotInfo.value = 'No timetable available for today.';
      return;
    }

    try {
      // Correct path: timetable/{departmentId}/{classId}/{day}/slots/{period}
      // Need to iterate over each class to find teacher's assignments
      List<String> assignments = [];

      debugPrint(
        'Searching for assignments across ${classList.length} classes',
      );

      for (final classId in classList) {
        final slotsCol = FirebaseFirestore.instance
            .collection('timetable')
            .doc(_teacherDepartmentId)
            .collection(classId)
            .doc(dayKey)
            .collection('slots');

        debugPrint(
          'Checking class: $classId at path: timetable/$_teacherDepartmentId/$classId/$dayKey/slots',
        );

        // Get assigned slots (primary teacher)
        final primarySlots = await slotsCol
            .where('teacherUid', isEqualTo: uid)
            .get();

        // Get override slots (substitute)
        final overrideSlots = await slotsCol
            .where('overrideTeacherUid', isEqualTo: uid)
            .where('overrideEnabled', isEqualTo: true)
            .get();

        for (final doc in primarySlots.docs) {
          final data = doc.data();
          final period = doc.id; // Document ID is the period
          final className = classNames[classId] ?? classId;
          debugPrint('Found primary slot: $period - $className');
          if (className.isNotEmpty && period.isNotEmpty) {
            assignments.add('$period: $className');
          }
        }

        for (final doc in overrideSlots.docs) {
          final data = doc.data();
          final period = doc.id; // Document ID is the period
          final className = classNames[classId] ?? classId;
          debugPrint('Found substitute slot: $period - $className');
          if (className.isNotEmpty && period.isNotEmpty) {
            assignments.add('$period: $className (Substitute)');
          }
        }
      }

      debugPrint(
        'Total primary/substitute assignments found: ${assignments.length}',
      );

      if (assignments.isEmpty) {
        debugPrint('❌ No assignments found');
        assignedSlotInfo.value =
            'You have no teaching assignments for today.\n\nIf you should have assignments, check that:\n- Timetable is created by HOD\n- Your UID matches the teacherUid in timetable';
      } else {
        assignments.sort();
        assignedSlotInfo.value = assignments.join('\n');
        debugPrint('✓ Assignments loaded: ${assignments.length} total');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading assigned slots: $e');
      debugPrint('Stack trace: $stackTrace');
      assignedSlotInfo.value = 'Error loading assignments: $e';
    }
  }

  void updateAvailablePeriods() {
    // Show all periods
    availablePeriods.value = periodTimes.keys.toList();

    // Set first period as default
    if (availablePeriods.isNotEmpty) {
      selectedPeriod.value = availablePeriods[0];
    }
  }

  // Check if current time is within the period's time range
  bool isPeriodActive(String period) {
    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    final startHour = periodTimes[period]!['startHour']!;
    final startMinute = periodTimes[period]!['startMinute']!;
    final endHour = periodTimes[period]!['endHour']!;
    final endMinute = periodTimes[period]!['endMinute']!;

    final periodStartTime = startHour * 60 + startMinute;
    final periodEndTime = endHour * 60 + endMinute;

    return currentTime >= periodStartTime && currentTime <= periodEndTime;
  }

  // Get message for inactive periods
  String getPeriodMessage(String period) {
    final now = DateTime.now();
    final currentTime = now.hour * 60 + now.minute;

    final startHour = periodTimes[period]!['startHour']!;
    final startMinute = periodTimes[period]!['startMinute']!;
    final endHour = periodTimes[period]!['endHour']!;
    final endMinute = periodTimes[period]!['endMinute']!;

    final periodStartTime = startHour * 60 + startMinute;
    final periodEndTime = endHour * 60 + endMinute;

    if (currentTime < periodStartTime) {
      final startTimeStr =
          '${startHour.toString().padLeft(2, '0')}:${startMinute.toString().padLeft(2, '0')}';
      return 'This period has not started yet.\nCome back at $startTimeStr to mark attendance.';
    } else {
      return 'This period has ended.\nUse "Edit Today\'s Attendance" to make changes.';
    }
  }

  Future<void> loadClasses() async {
    await _loadTeacherDepartmentId();

    // Load ALL classes in the teacher's department
    if (_teacherDepartmentId.isEmpty) {
      classList.value = [];
      classNames.clear();
      return;
    }

    try {
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('departmentId', isEqualTo: _teacherDepartmentId)
          .get();

      final Map<String, String> nameMap = {};
      final List<String> classIds = [];

      for (final doc in classesSnapshot.docs) {
        final data = doc.data();
        final className = data['name']?.toString() ?? doc.id;
        nameMap[doc.id] = className;
        classIds.add(doc.id);
      }

      // Sort by class name
      classIds.sort((a, b) => (nameMap[a] ?? '').compareTo(nameMap[b] ?? ''));

      classNames.value = nameMap;
      classList.value = classIds;

      if (classList.isNotEmpty) {
        selectedClassId.value = classList[0];
        loadStudents();
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
      classList.value = [];
      classNames.clear();
    }
  }

  void changeClass(String classId) {
    selectedClassId.value = classId;
    loadStudents();
  }

  void changePeriod(String period) {
    selectedPeriod.value = period;
    loadStudents();
  }

  Future<void> loadStudents() async {
    if (selectedClassId.value.isEmpty) return;

    // Check authorization first
    isCheckingAuth.value = true;
    isAuthorized.value = await _isAssignedForTodaySlot(
      classId: selectedClassId.value,
      period: selectedPeriod.value,
    );

    // Load assigned slot info for displaying to teacher
    await _loadAssignedSlotInfo();
    isCheckingAuth.value = false;

    // If not authorized, don't load students but still show assignment info
    if (!isAuthorized.value) {
      students.clear();
      attendance.clear();
      isAttendanceSaved.value = false;
      return;
    }

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    // Read attendance document
    final attendanceDoc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(selectedClassId.value)
        .collection(today)
        .doc(selectedPeriod.value)
        .get();

    Map<String, bool> savedAttendance = {};
    isAttendanceSaved.value = false;

    if (attendanceDoc.exists) {
      final data = attendanceDoc.data()!;

      // Check if attendance has been saved (has timestamp field)
      if (data.containsKey('timestamp')) {
        isAttendanceSaved.value = true;
      }

      // Extract students map
      if (data.containsKey('students') && data['students'] is Map) {
        final studentsMap = data['students'] as Map<String, dynamic>;
        studentsMap.forEach((uid, present) {
          if (present is bool) {
            savedAttendance[uid] = present;
          }
        });
      }
    }

    // Load all students in this class
    final studentSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: selectedClassId.value)
        .get();

    students.value = studentSnapshot.docs.map((doc) {
      attendance[doc.id] = savedAttendance[doc.id] ?? true;
      return {'uid': doc.id, 'name': doc['name']};
    }).toList();
  }

  void toggleAttendance(String uid, bool value) {
    attendance[uid] = value;
    update();
  }

  Future<void> saveAttendance() async {
    final teacherUid = FirebaseAuth.instance.currentUser!.uid;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final dayKey = _todayDayKey();

    // Check if user is authorized to mark attendance (assigned teacher or faculty advisor)
    final allowed = await _isAssignedForTodaySlot(
      classId: selectedClassId.value,
      period: selectedPeriod.value,
    );
    if (!allowed) {
      Get.snackbar(
        "Access Denied",
        "You are not assigned to mark attendance for this class/period.",
        backgroundColor: const Color(0xFFFF9800),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
        duration: const Duration(seconds: 3),
      );
      return;
    }

    // Check if attendance already exists
    final existingDoc = await FirebaseFirestore.instance
        .collection('attendance')
        .doc(selectedClassId.value)
        .collection(today)
        .doc(selectedPeriod.value)
        .get();

    if (existingDoc.exists) {
      final existingData = existingDoc.data()!;
      final markedByUid = existingData['markedByUid'] ?? '';

      // If already marked, only the person who marked it can edit
      if (markedByUid.isNotEmpty && markedByUid != teacherUid) {
        final markedBy = existingData['markedBy'] ?? 'another teacher';
        Get.snackbar(
          "Access Denied",
          "Attendance already marked by $markedBy.\nOnly they can edit it.",
          backgroundColor: const Color(0xFFFF9800),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
          duration: const Duration(seconds: 4),
        );
        return;
      }
    }

    final teacherDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(teacherUid)
        .get();

    final teacherName = teacherDoc['name'];

    // Prepare attendance document with exact structure
    final attendanceData = {
      'students': Map<String, bool>.from(attendance),
      'period': selectedPeriod.value,
      'date': today,
      'timetableDay': dayKey,
      'markedBy': teacherName,
      'markedByUid': teacherUid,
      'timestamp': FieldValue.serverTimestamp(),
    };

    // Write using set() with merge: false
    await FirebaseFirestore.instance
        .collection('attendance')
        .doc(selectedClassId.value)
        .collection(today)
        .doc(selectedPeriod.value)
        .set(attendanceData, SetOptions(merge: false));

    isAttendanceSaved.value = true;
    Get.snackbar(
      "Success",
      "Attendance saved by $teacherName",
      backgroundColor: const Color(0xFF4CAF50),
      colorText: Colors.white,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.all(16),
      borderRadius: 12,
    );
  }
}
