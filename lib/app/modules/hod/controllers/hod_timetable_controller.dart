import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class HodTimetableController extends GetxController {
  // Selection state
  final selectedDay = 'mon'.obs;
  final selectedClassId = ''.obs;

  // Loading states
  final isLoading = true.obs;
  final isLoadingSlots = false.obs;
  final loadError = ''.obs;

  // Data
  final departmentId = ''.obs;
  final classes = <Map<String, dynamic>>[].obs;
  final teachers = <Map<String, dynamic>>[].obs;
  final slots = <Map<String, dynamic>>[].obs;

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _slotsSub;

  // Constants
  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const List<String> periods = ['P1', 'P2', 'P3', 'P4', 'P5'];
  static const List<String> subjects = ['CRM', 'OS', 'EVS', 'CN', 'DSA'];

  @override
  void onInit() {
    super.onInit();
    _init();

    // Re-listen when day or class changes
    ever<String>(selectedDay, (_) => _listenSlots());
    ever<String>(selectedClassId, (_) => _listenSlots());
  }

  void setDay(String day) {
    if (days.contains(day) && selectedDay.value != day) {
      isLoadingSlots.value = true;
      selectedDay.value = day;
    }
  }

  void setSelectedClass(String classId) {
    if (selectedClassId.value != classId) {
      isLoadingSlots.value = true;
      selectedClassId.value = classId;
    }
  }

  Future<void> _init() async {
    isLoading.value = true;
    loadError.value = '';

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('Not signed in');

      // Get HOD's department
      final hodDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!hodDoc.exists) throw StateError('User not found');

      final hodData = hodDoc.data()!;
      if (hodData['role'] != 'hod') throw StateError('Access denied');

      final depId = (hodData['departmentId'] ?? '').toString();
      if (depId.isEmpty) throw StateError('Department not assigned');

      departmentId.value = depId;

      // Load classes and teachers in parallel
      await Future.wait([
        _loadClasses(depId),
        _loadTeachers(depId),
      ]);

      // Start listening to slots if class is selected
      _listenSlots();
    } catch (e) {
      loadError.value = e.toString();
      print('Error in HOD init: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> _loadClasses(String depId) async {
    final snap = await FirebaseFirestore.instance
        .collection('classes')
        .where('departmentId', isEqualTo: depId)
        .get();

    classes.value = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'name': data['name']?.toString() ?? doc.id,
        'facultyAdvisorUid': data['facultyAdvisorUid']?.toString() ?? '',
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

    print('Loaded ${classes.length} classes for $depId');
  }

  Future<void> _loadTeachers(String depId) async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'teacher')
        .where('departmentId', isEqualTo: depId)
        .get();

    teachers.value = snap.docs.map((doc) {
      final data = doc.data();
      return {
        'uid': doc.id,
        'name': data['name']?.toString() ?? doc.id,
      };
    }).toList()
      ..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

    print('Loaded ${teachers.length} teachers for $depId');
  }

  // Listen to slots for selected class and day
  // Path: timetable/{departmentId}/{classId}/{day}/slots
  void _listenSlots() {
    _slotsSub?.cancel();

    final depId = departmentId.value;
    final clsId = selectedClassId.value;
    final day = selectedDay.value;

    if (depId.isEmpty || clsId.isEmpty) {
      slots.value = [];
      isLoadingSlots.value = false;
      return;
    }

    final slotsRef = FirebaseFirestore.instance
        .collection('timetable')
        .doc(depId)
        .collection(clsId)
        .doc(day)
        .collection('slots');

    _slotsSub = slotsRef.snapshots().listen((snapshot) {
      slots.value = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'period': doc.id,
          'subject': data['subject']?.toString() ?? '',
          'teacherUid': data['teacherUid']?.toString() ?? '',
          'overrideEnabled': data['overrideEnabled'] == true,
          'overrideTeacherUid': data['overrideTeacherUid']?.toString() ?? '',
        };
      }).toList()
        ..sort((a, b) => (a['period'] as String? ?? '').compareTo(b['period'] as String? ?? ''));

      isLoadingSlots.value = false;
    });
  }

  // Save a slot
  // Path: timetable/{departmentId}/{classId}/{day}/slots/{period}
  Future<void> upsertSlot({
    required String classId,
    required String period,
    required String teacherUid,
    required bool overrideEnabled,
    String? overrideTeacherUid,
    String? subject,
  }) async {
    final depId = departmentId.value;
    if (depId.isEmpty) throw StateError('No department');
    if (classId.isEmpty) throw ArgumentError('No class');
    if (!periods.contains(period)) throw ArgumentError('Invalid period');
    if (teacherUid.isEmpty) throw ArgumentError('No teacher');

    // Optimistic update
    final newSlot = {
      'period': period,
      'subject': subject ?? '',
      'teacherUid': teacherUid,
      'overrideEnabled': overrideEnabled,
      'overrideTeacherUid': overrideTeacherUid ?? '',
    };

    final current = List<Map<String, dynamic>>.from(slots.value);
    final idx = current.indexWhere((s) => s['period'] == period);
    if (idx >= 0) {
      current[idx] = newSlot;
    } else {
      current.add(newSlot);
    }
    current.sort((a, b) => a['period'].compareTo(b['period']));
    slots.value = current;

    // Save to Firestore
    await FirebaseFirestore.instance
        .collection('timetable')
        .doc(depId)
        .collection(classId)
        .doc(selectedDay.value)
        .collection('slots')
        .doc(period)
        .set({
      'subject': subject ?? '',
      'teacherUid': teacherUid,
      'overrideEnabled': overrideEnabled,
      'overrideTeacherUid': overrideTeacherUid ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    print('Saved: $classId/$selectedDay/$period → $subject');
  }

  // Delete a slot
  Future<void> deleteSlot({
    required String classId,
    required String period,
  }) async {
    final depId = departmentId.value;
    if (depId.isEmpty) return;

    // Optimistic update
    final current = List<Map<String, dynamic>>.from(slots.value);
    current.removeWhere((s) => s['period'] == period);
    slots.value = current;

    // Delete from Firestore
    await FirebaseFirestore.instance
        .collection('timetable')
        .doc(depId)
        .collection(classId)
        .doc(selectedDay.value)
        .collection('slots')
        .doc(period)
        .delete();

    print('Deleted: $classId/$selectedDay/$period');
  }

  // Helper methods
  String dayLabel(String day) {
    const labels = {
      'mon': 'Monday',
      'tue': 'Tuesday',
      'wed': 'Wednesday',
      'thu': 'Thursday',
      'fri': 'Friday',
    };
    return labels[day] ?? day;
  }

  String className(String classId) {
    final cls = classes.firstWhereOrNull((c) => c['id'] == classId);
    return cls?['name'] ?? classId;
  }

  String teacherName(String uid) {
    final teacher = teachers.firstWhereOrNull((t) => t['uid'] == uid);
    return teacher?['name'] ?? uid;
  }

  String? facultyAdvisorUidForClass(String classId) {
    final cls = classes.firstWhereOrNull((c) => c['id'] == classId);
    final uid = cls?['facultyAdvisorUid']?.toString() ?? '';
    return uid.isEmpty ? null : uid;
  }

  @override
  void onClose() {
    _slotsSub?.cancel();
    super.onClose();
  }
}
