import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../controllers/teacher_reports_controller.dart';

class TeacherStudentReportView extends StatefulWidget {
  const TeacherStudentReportView({super.key});

  @override
  State<TeacherStudentReportView> createState() =>
      _TeacherStudentReportViewState();
}

class _TeacherStudentReportViewState extends State<TeacherStudentReportView> {
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> advisorClasses = [];

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
    _loadAdvisorClasses();
  }

  Future<void> _loadAdvisorClasses() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final snapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('facultyAdvisorUid', isEqualTo: uid)
          .get();

      if (mounted) {
        setState(() {
          advisorClasses = snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  'name': doc.data()['name'] ?? 'Unknown',
                  'departmentId': doc.data()['departmentId'],
                },
              )
              .toList();

          // Auto-select if only one class
          if (advisorClasses.length == 1) {
            selectedClassId = advisorClasses.first['id'];
            _loadStudents(selectedClassId!);
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading advisor classes: $e');
    }
  }

  Future<void> _loadStudents(String classId) async {
    try {
      setState(() {
        isLoadingStudents = true;
        students = [];
        selectedStudentId = null;
        attendanceReport = [];
        reportGenerated = false;
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
          (a, b) => (a['rollNo'] as String).compareTo(b['rollNo'] as String),
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

  Future<void> _generateReport() async {
    if (selectedStudentId == null || selectedClassId == null) {
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

      // Get class departmentId
      final classData = advisorClasses.firstWhere(
        (c) => c['id'] == selectedClassId,
        orElse: () => {},
      );
      final departmentId = classData['departmentId'];

      // Load timetable to get subjects
      final Map<String, String> periodToSubject = {};
      if (departmentId != null) {
        for (final day in days) {
          try {
            final slotsSnap = await FirebaseFirestore.instance
                .collection('timetable')
                .doc(departmentId)
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

      // Calculate day credits
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
          'total': total,
          'present': present,
          'percentage': total > 0 ? (present / total) * 100 : 0.0,
        });
      });

      summary.sort(
        (a, b) => (a['subject'] as String).compareTo(b['subject'] as String),
      );

      if (mounted) {
        setState(() {
          attendanceReport = summary;
          totalWorkingDays = workingDays;
          fullDayPresent = fullPresent;
          halfDayPresent = halfPresent;
          fullDayAbsent = fullAbsent;
          dayCredits = credits;
          overallPercentage = workingDays > 0
              ? (credits / workingDays) * 100
              : 0.0;
          isLoadingReport = false;
          reportGenerated = true;
        });
      }
    } catch (e) {
      debugPrint('Error generating report: $e');
      if (mounted) {
        setState(() {
          isLoadingReport = false;
        });
        Get.snackbar(
          'Error',
          'Failed to generate report: $e',
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Student Reports',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (reportGenerated)
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _showExportOptions,
              tooltip: 'Export',
            ),
        ],
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
              ),
            if (reportGenerated) ...[
              _buildStudentInfoCard(),
              const SizedBox(height: 16),
              _buildOverallStats(),
              const SizedBox(height: 16),
              _buildDayBreakdown(),
              const SizedBox(height: 16),
              _buildSubjectWiseTable(),
            ],
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),

          // Class Dropdown
          _buildDropdown(
            label: 'Class',
            value: selectedClassId,
            items: advisorClasses
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
                selectedStudentId = null;
                reportGenerated = false;
              });
              if (value != null) _loadStudents(value);
            },
          ),
          const SizedBox(height: 12),

          // Student Dropdown
          _buildDropdown(
            label: 'Student',
            value: selectedStudentId,
            items: students
                .map(
                  (s) => DropdownMenuItem(
                    value: s['id'] as String,
                    child: Text('${s['rollNo']} - ${s['name']}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedStudentId = value;
                reportGenerated = false;
              });
            },
            isLoading: isLoadingStudents,
          ),
          const SizedBox(height: 16),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedStudentId != null && !isLoadingReport
                  ? _generateReport
                  : null,
              icon: const Icon(Icons.analytics),
              label: Text(
                isLoadingReport ? 'Generating...' : 'Generate Report',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: const Color(0xFF0F0C29),
                padding: const EdgeInsets.symmetric(vertical: 12),
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
    bool isLoading = false,
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
          child: isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF00D9FF),
                      ),
                    ),
                  ),
                )
              : DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    hint: Text(
                      'Select $label',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    isExpanded: true,
                    dropdownColor: const Color(0xFF16213E),
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(
                      Icons.arrow_drop_down,
                      color: Colors.white54,
                    ),
                    items: items,
                    onChanged: onChanged,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildStudentInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF00D9FF).withOpacity(0.2),
            const Color(0xFF0097A7).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9FF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF00D9FF),
            child: Text(
              (studentData?['name'] ?? 'U')[0].toUpperCase(),
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
                  studentData?['name'] ?? 'Unknown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Roll No: ${studentData?['rollNo'] ?? '-'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                Text(
                  studentData?['email'] ?? '',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: overallPercentage >= 75
            ? const Color(0xFF4CAF50).withOpacity(0.15)
            : const Color(0xFFF44336).withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: overallPercentage >= 75
              ? const Color(0xFF4CAF50).withOpacity(0.3)
              : const Color(0xFFF44336).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            'Overall',
            '${overallPercentage.toStringAsFixed(1)}%',
            overallPercentage >= 75
                ? const Color(0xFF4CAF50)
                : const Color(0xFFF44336),
          ),
          _buildStatItem(
            'Working Days',
            '$totalWorkingDays',
            const Color(0xFF2196F3),
          ),
          _buildStatItem(
            'Day Credits',
            dayCredits.toStringAsFixed(1),
            const Color(0xFF9C27B0),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildDayBreakdown() {
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
            'Day Breakdown',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBreakdownItem(
                  'Full Day',
                  '$fullDayPresent',
                  const Color(0xFF4CAF50),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownItem(
                  'Half Day',
                  '$halfDayPresent',
                  const Color(0xFFFF9800),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBreakdownItem(
                  'Absent',
                  '$fullDayAbsent',
                  const Color(0xFFF44336),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectWiseTable() {
    if (attendanceReport.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No subject-wise data available',
            style: TextStyle(color: Colors.white54),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Subject-wise Attendance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(color: Color(0xFF0F4C75)),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Subject',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Present',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    'Total',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Text(
                    '%',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          // Rows
          ...attendanceReport.asMap().entries.map((entry) {
            final report = entry.value;
            final isLast = entry.key == attendanceReport.length - 1;
            final percentage = report['percentage'] as double;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: percentage < 75 ? Colors.red.withOpacity(0.1) : null,
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      report['subject'],
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${report['present']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${report['total']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${percentage.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: percentage >= 75
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showExportOptions() {
    final controller = Get.find<TeacherReportsController>();
    final studentName = studentData?['name'] ?? 'Unknown';

    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color(0xFF16213E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Export Report',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Icons.picture_as_pdf,
                color: Color(0xFFF44336),
              ),
              title: const Text(
                'Export as PDF',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                controller.exportReport(
                  reportType: 'student',
                  format: 'pdf',
                  entityId: selectedStudentId!,
                  entityName: studentName,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart, color: Color(0xFF4CAF50)),
              title: const Text(
                'Export as Excel',
                style: TextStyle(color: Colors.white),
              ),
              onTap: () {
                Get.back();
                controller.exportReport(
                  reportType: 'student',
                  format: 'excel',
                  entityId: selectedStudentId!,
                  entityName: studentName,
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
