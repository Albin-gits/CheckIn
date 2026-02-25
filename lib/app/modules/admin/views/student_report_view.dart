import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StudentReportView extends StatefulWidget {
  const StudentReportView({super.key});

  @override
  State<StudentReportView> createState() => _StudentReportViewState();
}

class _StudentReportViewState extends State<StudentReportView> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> departments = [];

  String? selectedDepartmentId;
  String? selectedClassId;
  String? selectedStudentId;

  bool isLoadingStudents = false;
  bool isLoadingReport = false;
  bool reportGenerated = false;

  // Report data
  Map<String, dynamic>? studentData;
  List<Map<String, dynamic>> attendanceReport = [];
  double overallPercentage = 0.0;
  int totalWorkingDays = 0;
  int fullDayPresent = 0;
  int halfDayPresent = 0;
  int fullDayAbsent = 0;
  double dayCredits = 0.0;

  static const List<String> days = ['mon', 'tue', 'wed', 'thu', 'fri'];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('departments')
          .orderBy('name')
          .get();

      if (mounted) {
        setState(() {
          departments = snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'name': doc.data()['name'] ?? 'Unknown',
                },
              )
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error loading departments: $e');
    }
  }

  Future<void> _loadClasses(String departmentId) async {
    try {
      setState(() {
        classes = [];
        students = [];
        selectedClassId = null;
        selectedStudentId = null;
        attendanceReport = [];
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('departmentId', isEqualTo: departmentId)
          .get();

      if (mounted) {
        final classList = snapshot.docs
            .map(
              (doc) => {'id': doc.id, 'name': doc.data()['name'] ?? 'Unknown'},
            )
            .toList();
        classList.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );

        setState(() {
          classes = classList;
        });
      }
    } catch (e) {
      debugPrint('Error loading classes: $e');
    }
  }

  Future<void> _loadStudents(String classId) async {
    try {
      setState(() {
        isLoadingStudents = true;
        students = [];
        selectedStudentId = null;
        attendanceReport = [];
      });

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .get();

      if (mounted) {
        final studentList = snapshot.docs
            .map(
              (doc) => {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unknown',
                'rollNo': doc.data()['rollNo'] ?? '',
                'email': doc.data()['email'] ?? '',
              },
            )
            .toList();
        studentList.sort(
          (a, b) => (a['name'] as String).compareTo(b['name'] as String),
        );

        setState(() {
          students = studentList;
          isLoadingStudents = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading students: $e');
      if (mounted) {
        setState(() {
          isLoadingStudents = false;
        });
      }
    }
  }

  Future<void> _generateReport() async {
    if (selectedStudentId == null ||
        selectedClassId == null ||
        selectedDepartmentId == null) {
      return;
    }

    setState(() {
      isLoadingReport = true;
      attendanceReport = [];
      reportGenerated = false;
    });

    try {
      // Get student data
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(selectedStudentId)
          .get();

      studentData = studentDoc.data();

      // Load timetable to get subjects
      final Map<String, String> periodToSubject = {};
      for (final day in days) {
        try {
          final slotsSnap = await FirebaseFirestore.instance
              .collection('timetable')
              .doc(selectedDepartmentId)
              .collection(selectedClassId!)
              .doc(day)
              .collection('slots')
              .get();

          for (var doc in slotsSnap.docs) {
            final period = doc.id;
            final subject = doc.data()['subject']?.toString() ?? 'Unknown';
            periodToSubject['$day-$period'] = subject;
          }
        } catch (e) {
          debugPrint('Error loading timetable for $day: $e');
        }
      }

      // Calculate date range (last 90 days)
      final now = DateTime.now();
      final List<String> dateStrings = [];
      final Map<String, String> dateToDay = {};

      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dayOfWeek = date.weekday;

        if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
          continue;
        }

        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dateStrings.add(dateString);
        dateToDay[dateString] = _getDayKeyFromDate(date);
      }

      // Track subject-wise and date-wise attendance
      final Map<String, Map<String, int>> subjectData = {};
      final Map<String, Map<String, int>> dateWiseAttendance = {};

      // Initialize subjects
      final Set<String> allSubjects = periodToSubject.values.toSet();
      for (final subject in allSubjects) {
        subjectData[subject] = {'total': 0, 'present': 0};
      }

      // Fetch attendance records
      for (final dateString in dateStrings) {
        try {
          final periodDocs = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(selectedClassId)
              .collection(dateString)
              .get();

          if (periodDocs.docs.isEmpty) continue;

          dateWiseAttendance[dateString] = {'total': 0, 'present': 0};

          for (var periodDoc in periodDocs.docs) {
            final data = periodDoc.data();
            final period = periodDoc.id;

            if (data.containsKey('students') && data['students'] is Map) {
              final studentsMap = data['students'] as Map<String, dynamic>;

              if (studentsMap.containsKey(selectedStudentId)) {
                final isPresent = studentsMap[selectedStudentId] == true;

                final dayKey = dateToDay[dateString] ?? 'mon';
                final lookupKey = '$dayKey-$period';
                final subject = periodToSubject[lookupKey] ?? 'Unknown Subject';

                if (subjectData.containsKey(subject)) {
                  subjectData[subject]!['total'] =
                      (subjectData[subject]!['total'] ?? 0) + 1;
                  if (isPresent) {
                    subjectData[subject]!['present'] =
                        (subjectData[subject]!['present'] ?? 0) + 1;
                  }
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
          debugPrint('Error fetching attendance for $dateString: $e');
        }
      }

      // Calculate day credits (half-day/full-day logic)
      int workingDays = 0;
      int fullPresent = 0;
      int halfPresent = 0;
      int fullAbsent = 0;
      double credits = 0.0;

      dateWiseAttendance.forEach((dateString, data) {
        final totalPeriods = data['total'] ?? 0;
        final presentPeriods = data['present'] ?? 0;
        final absentPeriods = totalPeriods - presentPeriods;

        if (totalPeriods > 0) {
          workingDays++;

          if (absentPeriods == 0) {
            fullPresent++;
            credits += 1.0;
          } else if (absentPeriods == 1) {
            halfPresent++;
            credits += 0.5;
          } else {
            fullAbsent++;
          }
        }
      });

      // Build report summary
      final List<Map<String, dynamic>> summary = [];
      subjectData.forEach((subject, data) {
        final total = data['total'] ?? 0;
        final present = data['present'] ?? 0;
        summary.add({
          'subject': subject,
          'totalHours': total,
          'attendedHours': present,
          'percentage': total > 0 ? (present / total) * 100 : 0.0,
        });
      });
      summary.sort((a, b) => a['subject'].compareTo(b['subject']));

      final percentage = workingDays > 0 ? (credits / workingDays) * 100 : 0.0;

      if (mounted) {
        setState(() {
          attendanceReport = summary;
          overallPercentage = percentage;
          totalWorkingDays = workingDays;
          fullDayPresent = fullPresent;
          halfDayPresent = halfPresent;
          fullDayAbsent = fullAbsent;
          dayCredits = credits;
          isLoadingReport = false;
          reportGenerated = true;
        });
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(() {
          isLoadingReport = false;
          reportGenerated = true;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Student Report',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSelectionSection(),
            const SizedBox(height: 20),
            if (isLoadingReport)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
                ),
              )
            else if (reportGenerated)
              _buildReportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Student',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Department Dropdown
          _buildDropdown(
            label: 'Department',
            value: selectedDepartmentId,
            items: departments
                .map(
                  (d) => DropdownMenuItem(
                    value: d['id'] as String,
                    child: Text(d['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedDepartmentId = value;
              });
              if (value != null) _loadClasses(value);
            },
          ),
          const SizedBox(height: 12),

          // Class Dropdown
          _buildDropdown(
            label: 'Class',
            value: selectedClassId,
            items: classes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['id'] as String,
                    child: Text(c['name'] as String),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedClassId = value;
              });
              if (value != null) _loadStudents(value);
            },
          ),
          const SizedBox(height: 12),

          // Student Dropdown
          if (isLoadingStudents)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          else
            _buildDropdown(
              label: 'Student',
              value: selectedStudentId,
              items: students
                  .map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as String,
                      child: Text(
                        '${s['name']} ${s['rollNo'] != '' ? '(${s['rollNo']})' : ''}',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedStudentId = value;
                });
              },
            ),
          const SizedBox(height: 20),

          // Generate Report Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedStudentId != null ? _generateReport : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: const Color(0xFF0F0C29),
                padding: const EdgeInsets.symmetric(vertical: 14),
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              hint: Text(
                'Select $label',
                style: const TextStyle(color: Colors.white54),
              ),
              isExpanded: true,
              dropdownColor: const Color(0xFF16213E),
              style: const TextStyle(color: Colors.white),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
              items: items,
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Info Card
        if (studentData != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F4C75), Color(0xFF3282B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  child: Text(
                    (studentData!['name'] ?? 'S')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentData!['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Roll No: ${studentData!['rollNo'] ?? 'N/A'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        studentData!['email'] ?? '',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Overall Percentage Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: overallPercentage >= 75
                  ? [const Color(0xFF2E7D32), const Color(0xFF66BB6A)]
                  : overallPercentage >= 65
                  ? [const Color(0xFFF57C00), const Color(0xFFFFB74D)]
                  : [const Color(0xFFC62828), const Color(0xFFEF5350)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Text(
                'Overall Attendance',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '${overallPercentage.toStringAsFixed(2)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${dayCredits.toStringAsFixed(1)} / $totalWorkingDays days',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Day Summary Cards
        Row(
          children: [
            Expanded(
              child: _buildDayCard(
                'Full Days',
                fullDayPresent,
                const Color(0xFF4CAF50),
                Icons.check_circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDayCard(
                'Half Days',
                halfDayPresent,
                const Color(0xFFFF9800),
                Icons.timelapse,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildDayCard(
                'Absent',
                fullDayAbsent,
                const Color(0xFFF44336),
                Icons.cancel,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Subject-wise breakdown
        const Text(
          'Subject-wise Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (attendanceReport.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF16213E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.info_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 12),
                  Text(
                    'No attendance records found',
                    style: TextStyle(color: Colors.white54, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Attendance data will appear here once recorded',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
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
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F4C75),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Subject',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Total',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Present',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          '%',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Rows
                ...attendanceReport.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast = entry.key == attendanceReport.length - 1;
                  final percentage = item['percentage'] as double;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['subject'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${item['totalHours']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${item['attendedHours']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: percentage >= 75
                                  ? Colors.green.withOpacity(0.2)
                                  : percentage >= 65
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(0)}%',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: percentage >= 75
                                    ? Colors.green
                                    : percentage >= 65
                                    ? Colors.orange
                                    : Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDayCard(String label, int value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
