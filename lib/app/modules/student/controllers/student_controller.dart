import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:check_in_app/app/services/user_service.dart';
import 'package:check_in_app/app/routes/app_pages.dart';
import 'package:flutter/material.dart';

class StudentController extends GetxController {
  // Observable state variables
  final isMenuOpen = false.obs;
  final studentName = ''.obs;
  final studentEmail = ''.obs;
  final classId = ''.obs;
  final className = ''.obs;
  final departmentId = ''.obs;
  final selectedDay = 'mon'.obs;
  final timetable = <Map<String, dynamic>>[].obs;
  final isLoadingTimetable = true.obs;
  final teachersCache = <String, String>{}.obs;
  final teachersCacheLoaded = false.obs;

  // Attendance data
  final subjectAttendance = <Map<String, dynamic>>[].obs;
  final isLoadingAttendance = true.obs;
  final overallAttendancePercentage = 0.0.obs;

  // Day-based attendance tracking
  final totalWorkingDays = 0.obs;
  final fullDayPresentCount = 0.obs;
  final halfDayPresentCount = 0.obs;
  final fullDayAbsentCount = 0.obs;
  final totalDayCredits = 0.0.obs;

  // Constants
  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri'];
  static const Map<String, String> periodTimes = {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  void onInit() {
    super.onInit();
    loadStudentInfo();
  }

  Future<void> loadStudentInfo() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          final clsId = data['classId']?.toString() ?? '';
          var deptId = data['departmentId']?.toString() ?? '';
          final clsFromUser = data['className']?.toString()?.trim();

          String? clsName;

          // Resolve class info and get departmentId if missing
          if (clsId.isNotEmpty) {
            try {
              final classDoc = await FirebaseFirestore.instance
                  .collection('classes')
                  .doc(clsId)
                  .get();
              if (classDoc.exists && classDoc.data() != null) {
                final classData = classDoc.data()!;
                clsName = clsFromUser ?? classData['name']?.toString() ?? clsId;

                // Get departmentId from class if not in user profile
                if (deptId.isEmpty) {
                  deptId = classData['departmentId']?.toString() ?? '';
                  print('Got departmentId from class: $deptId');
                }
              } else {
                clsName = clsFromUser ?? clsId;
              }
            } catch (e) {
              clsName = clsFromUser ?? clsId;
            }
          } else {
            clsName = clsFromUser;
          }

          studentName.value = data['name']?.toString() ?? '';
          studentEmail.value = data['email']?.toString() ?? '';
          classId.value = clsId;
          className.value = clsName ?? '';
          departmentId.value = deptId;

          print(
            'Student: ${studentName.value}, Class: ${classId.value}, Dept: ${departmentId.value}',
          );

          // Load attendance after getting student info
          if (classId.value.isNotEmpty && departmentId.value.isNotEmpty) {
            await loadAttendanceSummary();
          } else {
            print('Missing classId or departmentId');
            isLoadingAttendance.value = false;
          }
        } else {
          isLoadingAttendance.value = false;
        }
      } else {
        isLoadingAttendance.value = false;
      }
    } catch (e) {
      print('Error in loadStudentInfo: $e');
      isLoadingAttendance.value = false;
    }
  }

  String dayLabel(String dayKey) {
    switch (dayKey) {
      case 'mon':
        return 'Monday';
      case 'tue':
        return 'Tuesday';
      case 'wed':
        return 'Wednesday';
      case 'thu':
        return 'Thursday';
      case 'fri':
        return 'Friday';
      default:
        return dayKey;
    }
  }

  Future<void> loadAttendanceSummary() async {
    if (classId.value.isEmpty || departmentId.value.isEmpty) {
      print(
        '❌ Cannot load attendance: classId=${classId.value}, departmentId=${departmentId.value}',
      );
      isLoadingAttendance.value = false;
      return;
    }

    isLoadingAttendance.value = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final studentId = user.uid;
      print(
        '📊 Loading attendance for student: $studentId, class: ${classId.value}, dept: ${departmentId.value}',
      );

      // Pre-load entire timetable for this class to avoid repeated queries
      final Map<String, String> periodToSubject = {};

      for (final day in days) {
        try {
          final slotsSnap = await FirebaseFirestore.instance
              .collection('timetable')
              .doc(departmentId.value)
              .collection(classId.value)
              .doc(day)
              .collection('slots')
              .get();

          print('📅 Timetable for $day: ${slotsSnap.docs.length} slots found');
          for (var doc in slotsSnap.docs) {
            final period = doc.id;
            final subject = doc.data()['subject']?.toString() ?? 'Unknown';
            // Key format: day-period (e.g., "mon-P1")
            periodToSubject['$day-$period'] = subject;
            print('   - $period: $subject');
          }
        } catch (e) {
          print('❌ Error loading timetable for $day: $e');
        }
      }
      print('📚 Total timetable entries loaded: ${periodToSubject.length}');

      // Map to store subject-wise attendance: subject -> {total, present}
      final Map<String, Map<String, int>> subjectData = {};

      // Initialize all subjects from timetable with 0 attendance
      final Set<String> allSubjects = periodToSubject.values.toSet();
      for (final subject in allSubjects) {
        subjectData[subject] = {'total': 0, 'present': 0};
      }
      print('📚 Initialized ${allSubjects.length} subjects from timetable');

      // Calculate date range (last 90 days)
      final now = DateTime.now();
      final List<String> dateStrings = [];
      final Map<String, String> dateToDay = {}; // dateString -> dayKey mapping

      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dayOfWeek = date.weekday;

        // Skip weekends
        if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
          continue;
        }

        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dateStrings.add(dateString);
        dateToDay[dateString] = _getDayKeyFromDate(date);
      }

      // Track per-date attendance for half-day/full-day calculation
      // Key: dateString, Value: {totalPeriods, presentPeriods}
      final Map<String, Map<String, int>> dateWiseAttendance = {};

      // Fetch all attendance records in parallel batches
      final List<Future<void>> fetchFutures = [];
      int totalAttendanceRecords = 0;
      int studentAttendanceRecords = 0;

      for (final dateString in dateStrings) {
        fetchFutures.add(() async {
          try {
            final periodDocs = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(classId.value)
                .collection(dateString)
                .get();

            if (periodDocs.docs.isNotEmpty) {
              totalAttendanceRecords += periodDocs.docs.length;
              print(
                '📋 Date $dateString: ${periodDocs.docs.length} period(s) found',
              );

              // Initialize date entry if not exists
              if (!dateWiseAttendance.containsKey(dateString)) {
                dateWiseAttendance[dateString] = {'total': 0, 'present': 0};
              }
            }

            for (var periodDoc in periodDocs.docs) {
              final data = periodDoc.data();
              final period = periodDoc.id;

              if (data.containsKey('students') && data['students'] is Map) {
                final studentsMap = data['students'] as Map<String, dynamic>;

                if (studentsMap.containsKey(studentId)) {
                  studentAttendanceRecords++;
                  final isPresent = studentsMap[studentId] == true;

                  // Get subject from pre-loaded timetable
                  final dayKey = dateToDay[dateString] ?? 'mon';
                  final lookupKey = '$dayKey-$period';
                  final subject =
                      periodToSubject[lookupKey] ?? 'Unknown Subject';

                  print(
                    '✅ Found attendance: $dateString $period ($subject) - Present: $isPresent',
                  );

                  // Update counts for this subject (already initialized)
                  if (subjectData.containsKey(subject)) {
                    subjectData[subject]!['total'] =
                        (subjectData[subject]!['total'] ?? 0) + 1;
                    if (isPresent) {
                      subjectData[subject]!['present'] =
                          (subjectData[subject]!['present'] ?? 0) + 1;
                    }
                  }

                  // Update date-wise attendance tracking
                  if (!dateWiseAttendance.containsKey(dateString)) {
                    dateWiseAttendance[dateString] = {'total': 0, 'present': 0};
                  }
                  dateWiseAttendance[dateString]!['total'] =
                      (dateWiseAttendance[dateString]!['total'] ?? 0) + 1;
                  if (isPresent) {
                    dateWiseAttendance[dateString]!['present'] =
                        (dateWiseAttendance[dateString]!['present'] ?? 0) + 1;
                  }
                }
              }
            }
          } catch (e) {
            print('❌ Error fetching attendance for $dateString: $e');
          }
        }());
      }

      // Wait for all fetches to complete (process in batches of 10 to avoid overwhelming)
      for (int i = 0; i < fetchFutures.length; i += 10) {
        final batch = fetchFutures.skip(i).take(10);
        await Future.wait(batch);
      }

      print(
        '📊 Summary: Total attendance records found: $totalAttendanceRecords',
      );
      print(
        '📊 Summary: Student attendance records: $studentAttendanceRecords',
      );
      print('📊 Summary: Subjects with attendance: ${subjectData.keys.length}');

      // Calculate half-day/full-day attendance
      // Rules:
      // - 0 periods absent = Full day present (1.0 credit)
      // - 1 period absent = Half day present (0.5 credit)
      // - 2+ periods absent = Full day absent (0.0 credit)
      int workingDays = 0;
      int fullPresent = 0;
      int halfPresent = 0;
      int fullAbsent = 0;
      double dayCredits = 0.0;

      dateWiseAttendance.forEach((dateString, data) {
        final totalPeriods = data['total'] ?? 0;
        final presentPeriods = data['present'] ?? 0;
        final absentPeriods = totalPeriods - presentPeriods;

        if (totalPeriods > 0) {
          workingDays++;

          if (absentPeriods == 0) {
            // Full day present
            fullPresent++;
            dayCredits += 1.0;
            print(
              '📅 $dateString: Full day present ($presentPeriods/$totalPeriods) - Credit: 1.0',
            );
          } else if (absentPeriods == 1) {
            // Half day present (1 period absent)
            halfPresent++;
            dayCredits += 0.5;
            print(
              '📅 $dateString: Half day present ($presentPeriods/$totalPeriods, 1 absent) - Credit: 0.5',
            );
          } else {
            // Full day absent (2+ periods absent)
            fullAbsent++;
            dayCredits += 0.0;
            print(
              '📅 $dateString: Full day absent ($presentPeriods/$totalPeriods, $absentPeriods absent) - Credit: 0.0',
            );
          }
        }
      });

      // Convert to list and sort by subject name
      final List<Map<String, dynamic>> summary = [];
      int totalAllClasses = 0;
      int totalAllPresent = 0;

      subjectData.forEach((subject, data) {
        final total = data['total'] ?? 0;
        final present = data['present'] ?? 0;

        totalAllClasses += total;
        totalAllPresent += present;

        summary.add({
          'subject': subject,
          'totalHours': total,
          'attendedHours': present,
          'percentage': total > 0 ? (present / total) * 100 : 0.0,
        });
      });

      // Sort by subject name
      summary.sort((a, b) => a['subject'].compareTo(b['subject']));

      // Calculate overall percentage based on day credits
      final overallPercentage = workingDays > 0
          ? (dayCredits / workingDays) * 100
          : 0.0;

      print('📈 Final Results (Day-based):');
      print('   - Total Working Days: $workingDays');
      print('   - Full Day Present: $fullPresent');
      print('   - Half Day Present: $halfPresent');
      print('   - Full Day Absent: $fullAbsent');
      print('   - Day Credits: ${dayCredits.toStringAsFixed(1)}');
      print(
        '   - Overall Percentage: ${overallPercentage.toStringAsFixed(2)}%',
      );
      print('   - Subject Count: ${summary.length}');
      for (var subj in summary) {
        print(
          '   - ${subj['subject']}: ${subj['attendedHours']}/${subj['totalHours']} (${subj['percentage'].toStringAsFixed(1)}%)',
        );
      }

      subjectAttendance.value = summary;
      overallAttendancePercentage.value = overallPercentage;
      totalWorkingDays.value = workingDays;
      fullDayPresentCount.value = fullPresent;
      halfDayPresentCount.value = halfPresent;
      fullDayAbsentCount.value = fullAbsent;
      totalDayCredits.value = dayCredits;
      isLoadingAttendance.value = false;
    } catch (e) {
      print('❌ Error loading attendance summary: $e');
      isLoadingAttendance.value = false;
    }
  }

  String _getDayKeyFromDate(DateTime date) {
    switch (date.weekday) {
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
        return 'mon';
    }
  }

  Future<void> loadTimetable() async {
    if (departmentId.value.isEmpty || classId.value.isEmpty) {
      isLoadingTimetable.value = false;
      return;
    }

    isLoadingTimetable.value = true;

    try {
      // Structure: timetable/{departmentId}/{classId}/{day}/slots
      final slotsQuery = await FirebaseFirestore.instance
          .collection('timetable')
          .doc(departmentId.value)
          .collection(classId.value)
          .doc(selectedDay.value)
          .collection('slots')
          .get();

      // Extract unique teacher UIDs from slots (check both teacherUid and overrideTeacherUid)
      final teacherUids = <String>{};
      for (var doc in slotsQuery.docs) {
        // Try teacherUid first, then fall back to overrideTeacherUid
        var teacherUid = doc.data()['teacherUid']?.toString() ?? '';
        if (teacherUid.isEmpty) {
          teacherUid = doc.data()['overrideTeacherUid']?.toString() ?? '';
        }
        if (teacherUid.isNotEmpty) {
          teacherUids.add(teacherUid);
        }
      }

      // Load teachers if cache is empty or if we need new teachers
      if (!teachersCacheLoaded.value ||
          teacherUids.any((uid) => !teachersCache.containsKey(uid))) {
        await _loadTeachersCache(teacherUids);
      }

      // Build schedule quickly using cached data
      final schedule = <Map<String, dynamic>>[];
      final periods = ['P1', 'P2', 'P3', 'P4', 'P5'];

      for (final period in periods) {
        // Find slot for this period (document ID is the period name)
        final matchingSlots = slotsQuery.docs
            .where((doc) => doc.id == period)
            .toList();

        if (matchingSlots.isNotEmpty) {
          final data = matchingSlots.first.data();
          // Try teacherUid first, then fall back to overrideTeacherUid
          var teacherUid = data['teacherUid']?.toString() ?? '';
          if (teacherUid.isEmpty) {
            teacherUid = data['overrideTeacherUid']?.toString() ?? '';
          }
          final subject = data['subject']?.toString() ?? '';

          // Get teacher name from cache, or load it directly if not cached
          String teacherName = teachersCache[teacherUid] ?? '';
          if (teacherName.isEmpty && teacherUid.isNotEmpty) {
            // Try to load this specific teacher and prefer human-friendly fields
            try {
              final teacherDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(teacherUid)
                  .get();
              if (teacherDoc.exists) {
                final td = teacherDoc.data() ?? {};
                teacherName = (td['name']?.toString() ?? '').trim();
                if (teacherName.isEmpty) {
                  teacherName = (td['displayName']?.toString() ?? '').trim();
                }
                if (teacherName.isEmpty) {
                  teacherName = (td['email']?.toString() ?? '').trim();
                }
                if (teacherName.isEmpty) {
                  teacherName = teacherUid;
                }
                teachersCache[teacherUid] = teacherName;
              } else {
                teacherName = teacherUid;
                teachersCache[teacherUid] = teacherName;
              }
            } catch (e) {
              print('Error loading teacher $teacherUid: $e');
              teacherName = teacherUid;
              teachersCache[teacherUid] = teacherName;
            }
          } else if (teacherName.isEmpty) {
            teacherName = 'Not Assigned';
          }

          schedule.add({
            'period': period,
            'subject': subject,
            'teacher': teacherName,
            'hasClass': true,
          });
        } else {
          schedule.add({
            'period': period,
            'subject': '',
            'teacher': '',
            'hasClass': false,
          });
        }
      }

      timetable.value = schedule;
      isLoadingTimetable.value = false;
    } catch (e) {
      print('Error in loadTimetable: $e');
      isLoadingTimetable.value = false;
    }
  }

  Future<void> _loadTeachersCache(Set<String> requiredUids) async {
    try {
      if (requiredUids.isEmpty) {
        // If no specific UIDs needed, load all department teachers (first time only)
        final teachersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .where('departmentId', isEqualTo: departmentId.value)
            .get();

        print(
          'Loading ${teachersQuery.docs.length} teachers for department: ${departmentId.value}',
        );

        for (var doc in teachersQuery.docs) {
          final name = doc.data()['name']?.toString() ?? doc.id;
          teachersCache[doc.id] = name;
          print('Cached teacher: ${doc.id} -> $name');
        }
      } else {
        // Load only required teachers that are not in cache
        final missingUids = requiredUids
            .where((uid) => !teachersCache.containsKey(uid))
            .toList();

        print('Loading ${missingUids.length} missing teachers: $missingUids');

        if (missingUids.isNotEmpty) {
          // Batch get specific teachers (more efficient than individual queries)
          final futures = missingUids.map(
            (uid) =>
                FirebaseFirestore.instance.collection('users').doc(uid).get(),
          );

          final results = await Future.wait(futures);

          for (var doc in results) {
            if (doc.exists) {
              final name = doc.data()?['name']?.toString() ?? doc.id;
              teachersCache[doc.id] = name;
              print('Cached teacher: ${doc.id} -> $name');
            } else {
              print('Teacher not found: ${doc.id}');
              teachersCache[doc.id] = 'Unknown Teacher';
            }
          }
        }
      }
      teachersCacheLoaded.value = true;
      print('Teachers cache loaded. Total cached: ${teachersCache.length}');
    } catch (e) {
      print('Error loading teachers cache: $e');
    }
  }

  void onDayChanged(String day) {
    selectedDay.value = day;
    loadTimetable();
  }

  void toggleMenu() {
    isMenuOpen.value = !isMenuOpen.value;
  }

  void showLogoutConfirmation() {
    Get.dialog(
      AlertDialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        content: const Text(
          'Do you want to logout?',
          style: TextStyle(fontSize: 16, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'No',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await UserService.logout();
              Get.offAllNamed(Routes.AUTH);
            },
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      barrierDismissible: true,
    );
  }

  void navigateToRoute(String? route, {String title = ''}) {
    isMenuOpen.value = false;
    if (route != null) {
      Get.toNamed(route);
    }
  }
}
