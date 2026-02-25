import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:check_in_app/app/services/user_service.dart';
import 'package:check_in_app/app/routes/app_pages.dart';

class StudentView extends StatefulWidget {
  const StudentView({super.key});

  @override
  State<StudentView> createState() => _StudentViewState();
}

class _StudentViewState extends State<StudentView> {
  bool isMenuOpen = false;
  String studentName = '';
  String studentEmail = '';
  String classId = '';
  String className = '';
  String departmentId = '';
  String selectedDay = 'mon';
  List<Map<String, dynamic>> timetable = [];
  bool isLoadingTimetable = true;
  Map<String, String> teachersCache =
      {}; // Cache teachers to avoid repeated queries
  bool teachersCacheLoaded = false;

  // Attendance data
  List<Map<String, dynamic>> subjectAttendance = [];
  bool isLoadingAttendance = true;
  double overallAttendancePercentage = 0.0;

  // Day-based attendance tracking
  int totalWorkingDays = 0;
  int fullDayPresentCount = 0;
  int halfDayPresentCount = 0; // 1 period absent
  int fullDayAbsentCount = 0; // 2+ periods absent
  double totalDayCredits = 0.0;

  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri'];
  // Map periods to human-readable time ranges
  static const Map<String, String> periodTimes = {
    'P1': '8:30 to 9:25',
    'P2': '9:30 to 10:20',
    'P3': '10:40 to 11:35',
    'P4': '11:40 to 12:30',
    'P5': '12:35 to 1:35',
  };

  @override
  void initState() {
    super.initState();
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

          if (mounted) {
            setState(() {
              studentName = data['name']?.toString() ?? '';
              studentEmail = data['email']?.toString() ?? '';
              classId = clsId;
              className = clsName ?? '';
              departmentId = deptId;
            });
          }

          print('Student: $studentName, Class: $classId, Dept: $departmentId');

          // Load attendance after getting student info
          if (classId.isNotEmpty && departmentId.isNotEmpty) {
            await loadAttendanceSummary();
          } else {
            print('Missing classId or departmentId');
            if (mounted) {
              setState(() {
                isLoadingAttendance = false;
              });
            }
          }
        } else {
          if (mounted) {
            setState(() {
              isLoadingAttendance = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            isLoadingAttendance = false;
          });
        }
      }
    } catch (e) {
      print('Error in loadStudentInfo: $e');
      if (mounted) {
        setState(() {
          isLoadingAttendance = false;
        });
      }
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
    if (classId.isEmpty || departmentId.isEmpty) {
      print(
        '❌ Cannot load attendance: classId=$classId, departmentId=$departmentId',
      );
      if (mounted) {
        setState(() {
          isLoadingAttendance = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingAttendance = true;
      });
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final studentId = user.uid;
      print(
        '📊 Loading attendance for student: $studentId, class: $classId, dept: $departmentId',
      );

      // Pre-load entire timetable for this class to avoid repeated queries
      final Map<String, String> periodToSubject = {};

      for (final day in days) {
        try {
          final slotsSnap = await FirebaseFirestore.instance
              .collection('timetable')
              .doc(departmentId)
              .collection(classId)
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
                .doc(classId)
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

      if (mounted) {
        setState(() {
          subjectAttendance = summary;
          overallAttendancePercentage = overallPercentage;
          totalWorkingDays = workingDays;
          fullDayPresentCount = fullPresent;
          halfDayPresentCount = halfPresent;
          fullDayAbsentCount = fullAbsent;
          totalDayCredits = dayCredits;
          isLoadingAttendance = false;
        });
      }
    } catch (e) {
      print('❌ Error loading attendance summary: $e');
      if (mounted) {
        setState(() {
          isLoadingAttendance = false;
        });
      }
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
    if (departmentId.isEmpty || classId.isEmpty) {
      if (mounted) {
        setState(() {
          isLoadingTimetable = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoadingTimetable = true;
      });
    }

    try {
      // Structure: timetable/{departmentId}/{classId}/{day}/slots
      final slotsQuery = await FirebaseFirestore.instance
          .collection('timetable')
          .doc(departmentId)
          .collection(classId)
          .doc(selectedDay)
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
      if (!teachersCacheLoaded ||
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

      if (mounted) {
        setState(() {
          timetable = schedule;
          isLoadingTimetable = false;
        });
      }
    } catch (e) {
      print('Error in loadTimetable: $e');
      if (mounted) {
        setState(() {
          isLoadingTimetable = false;
        });
      }
    }
  }

  Future<void> _loadTeachersCache(Set<String> requiredUids) async {
    try {
      if (requiredUids.isEmpty) {
        // If no specific UIDs needed, load all department teachers (first time only)
        final teachersQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'teacher')
            .where('departmentId', isEqualTo: departmentId)
            .get();

        print(
          'Loading ${teachersQuery.docs.length} teachers for department: $departmentId',
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
      teachersCacheLoaded = true;
      print('Teachers cache loaded. Total cached: ${teachersCache.length}');
    } catch (e) {
      print('Error loading teachers cache: $e');
    }
  }

  void onDayChanged(String day) {
    setState(() {
      selectedDay = day;
    });
    loadTimetable();
  }

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }

  void _showLogoutConfirmation(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (isMenuOpen) {
          setState(() {
            isMenuOpen = false;
          });
          return false;
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A2E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF16213E),
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isMenuOpen ? Icons.close_rounded : Icons.menu_rounded,
              color: Colors.white,
            ),
            onPressed: toggleMenu,
          ),
          title: const Text(
            "Student Dashboard",
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded, color: Colors.redAccent),
              onPressed: () => _showLogoutConfirmation(context),
            ),
          ],
        ),
        body: SizedBox.expand(
          child: Stack(
            children: [
              // MAIN CONTENT
              SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Welcome Card
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Welcome Back!",
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                studentName.isEmpty ? "Student" : studentName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Class: ${className.isNotEmpty ? className : (classId.isNotEmpty ? classId : 'N/A')}",
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Attendance Summary Section
                        _buildAttendanceSummary(),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),

              // GLASS SIDEBAR (MUST be after main content)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                top: 0,
                bottom: 0,
                left: isMenuOpen
                    ? 0
                    : -MediaQuery.of(context).size.width * 0.75,
                width: MediaQuery.of(context).size.width * 0.75,
                child: _buildGlassSidebar(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Section Title Widget
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  // Glass Morphism Sidebar
  Widget _buildGlassSidebar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            border: Border(
              right: BorderSide(color: Colors.white.withOpacity(0.15)),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 60),
              // Profile Section
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.blue[700],
                      child: Text(
                        studentName.isNotEmpty
                            ? studentName[0].toUpperCase()
                            : 'S',
                        style: const TextStyle(
                          fontSize: 32,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      studentName.isEmpty ? "Student" : studentName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      studentEmail,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _sidebarItem(Icons.home, "Dashboard", null),
                    _sidebarItem(
                      Icons.assignment,
                      "My Attendance",
                      Routes.STUDENT_ATTENDANCE,
                    ),
                    _sidebarItem(
                      Icons.calendar_today,
                      "My Timetable",
                      Routes.STUDENT_TIMETABLE,
                    ),
                    _sidebarItem(
                      Icons.request_page,
                      "Leave Request",
                      Routes.LEAVE_REQUEST,
                    ),
                    const Divider(color: Colors.white24),
                    _sidebarItem(
                      Icons.person,
                      "Profile",
                      Routes.STUDENT_PROFILE,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Sidebar Item
  Widget _sidebarItem(
    IconData icon,
    String title,
    String? route, {
    bool comingSoon = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(
        title,
        style: const TextStyle(color: Colors.white, fontSize: 15),
      ),
      onTap: () {
        setState(() {
          isMenuOpen = false;
        });
        if (comingSoon) {
          Get.snackbar(
            'Info',
            '$title - Coming Soon',
            backgroundColor: const Color(0xFF16213E),
            colorText: Colors.white,
            snackPosition: SnackPosition.TOP,
          );
        } else if (route != null) {
          Get.toNamed(route);
        }
      },
    );
  }

  // Day Selector
  Widget _buildDaySelector() {
    final dayLabels = [
      {'key': 'mon', 'label': 'Monday'},
      {'key': 'tue', 'label': 'Tuesday'},
      {'key': 'wed', 'label': 'Wednesday'},
      {'key': 'thu', 'label': 'Thursday'},
      {'key': 'fri', 'label': 'Friday'},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today, color: Colors.white70, size: 20),
          const SizedBox(width: 12),
          const Text(
            'Day:',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDay,
                dropdownColor: const Color(0xFF16213E),
                style: const TextStyle(color: Colors.white),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                items: dayLabels.map((day) {
                  return DropdownMenuItem<String>(
                    value: day['key'],
                    child: Text(
                      day['label']!,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onDayChanged(value);
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Timetable Widget
  Widget _buildTimetable() {
    if (isLoadingTimetable) {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: List.generate(5, (index) => _buildSkeletonPeriod()),
        ),
      );
    }

    if (timetable.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.event_busy, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                classId.isEmpty || departmentId.isEmpty
                    ? 'Student class/department not configured'
                    : 'No timetable found for ${dayLabel(selectedDay)}',
                style: const TextStyle(color: Colors.white54, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              if (classId.isNotEmpty && departmentId.isNotEmpty) ...[
                Text(
                  'Class: $className ($classId)',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Department: $departmentId',
                  style: const TextStyle(color: Colors.white30, fontSize: 11),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'HOD needs to create the timetable for this class',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.7),
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: timetable.asMap().entries.map((entry) {
          final index = entry.key;
          final period = entry.value;
          final isLast = index == timetable.length - 1;
          final hasClass = period['hasClass'] == true;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: isLast
                    ? BorderSide.none
                    : BorderSide(color: Colors.white.withOpacity(0.1)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: hasClass
                        ? const Color(0xFF2196F3).withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: hasClass
                          ? const Color(0xFF2196F3).withOpacity(0.3)
                          : Colors.grey.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    period['period']?.toString() ?? '',
                    style: TextStyle(
                      color: hasClass ? const Color(0xFF2196F3) : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasClass
                            ? (period['subject']?.toString() ?? 'No Subject')
                            : 'Free Period',
                        style: TextStyle(
                          color: hasClass ? Colors.white : Colors.white54,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (hasClass) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Time: ${periodTimes[period['period']?.toString() ?? ''] ?? 'Unknown'}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  // Day Summary Card Widget
  Widget _buildDaySummaryCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white54, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  // Skeleton loading for periods
  Widget _buildSkeletonPeriod() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Attendance Summary Widget
  Widget _buildAttendanceSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Overall Attendance Percentage Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: overallAttendancePercentage >= 75
                  ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
                  : overallAttendancePercentage >= 65
                  ? [const Color(0xFFF57C00), const Color(0xFFFFB74D)]
                  : [const Color(0xFFC62828), const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (overallAttendancePercentage >= 75
                            ? Colors.green
                            : Colors.orange)
                        .withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Consolidated Attendance Percentage',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${overallAttendancePercentage.toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalDayCredits.toStringAsFixed(1)} / $totalWorkingDays days',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Day-wise Attendance Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.check_circle,
                label: 'Full Days',
                value: '$fullDayPresentCount',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.timelapse,
                label: 'Half Days',
                value: '$halfDayPresentCount',
                color: const Color(0xFFFF9800),
                subtitle: '1 period absent',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDaySummaryCard(
                icon: Icons.cancel,
                label: 'Absent',
                value: '$fullDayAbsentCount',
                color: const Color(0xFFF44336),
                subtitle: '2+ periods',
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Attendance Table
        if (isLoadingAttendance)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            ),
          )
        else if (subjectAttendance.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: Text(
                'No attendance records found',
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F4C75),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: const [
                      SizedBox(
                        width: 40,
                        child: Text(
                          '#',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Course',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Actual Hrs',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
                        child: Text(
                          'Att. by Me',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Rows
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: subjectAttendance.length,
                  itemBuilder: (context, index) {
                    final item = subjectAttendance[index];
                    final isLast = index == subjectAttendance.length - 1;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: isLast
                              ? BorderSide.none
                              : BorderSide(
                                  color: Colors.white.withOpacity(0.1),
                                ),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 40,
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              item['subject'] ?? 'N/A',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['totalHours'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 70,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item['attendedHours'] ?? 0}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.blue,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
