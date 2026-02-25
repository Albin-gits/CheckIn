import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClassReportView extends StatefulWidget {
  const ClassReportView({super.key});

  @override
  State<ClassReportView> createState() => _ClassReportViewState();
}

class _ClassReportViewState extends State<ClassReportView> {
  List<Map<String, dynamic>> classes = [];
  List<Map<String, dynamic>> departments = [];

  String? selectedDepartmentId;
  String? selectedClassId;

  bool isLoadingReport = false;

  // Report data
  Map<String, dynamic>? classData;
  List<Map<String, dynamic>> studentAttendanceReport = [];
  double classOverallPercentage = 0.0;
  int totalStudents = 0;
  int aboveThreshold = 0;
  int belowThreshold = 0;
  bool reportGenerated = false;

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
        selectedClassId = null;
        studentAttendanceReport = [];
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

  Future<void> _generateReport() async {
    if (selectedClassId == null || selectedDepartmentId == null) {
      return;
    }

    setState(() {
      isLoadingReport = true;
      studentAttendanceReport = [];
      reportGenerated = false;
    });

    try {
      // Get class data
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId)
          .get();

      classData = classDoc.data();

      // Get all students in this class
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: selectedClassId)
          .get();

      final students = studentsSnapshot.docs;

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

      // Fetch all attendance records for this class
      final Map<String, Map<String, Map<String, int>>> studentDateAttendance =
          {};

      for (var student in students) {
        studentDateAttendance[student.id] = {};
      }

      for (final dateString in dateStrings) {
        try {
          final periodDocs = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(selectedClassId)
              .collection(dateString)
              .get();

          if (periodDocs.docs.isEmpty) continue;

          for (var periodDoc in periodDocs.docs) {
            final data = periodDoc.data();

            if (data.containsKey('students') && data['students'] is Map) {
              final studentsMap = data['students'] as Map<String, dynamic>;

              for (var student in students) {
                final studentId = student.id;
                if (studentsMap.containsKey(studentId)) {
                  final isPresent = studentsMap[studentId] == true;

                  if (!studentDateAttendance[studentId]!.containsKey(
                    dateString,
                  )) {
                    studentDateAttendance[studentId]![dateString] = {
                      'total': 0,
                      'present': 0,
                    };
                  }

                  studentDateAttendance[studentId]![dateString]!['total'] =
                      (studentDateAttendance[studentId]![dateString]!['total'] ??
                          0) +
                      1;
                  if (isPresent) {
                    studentDateAttendance[studentId]![dateString]!['present'] =
                        (studentDateAttendance[studentId]![dateString]!['present'] ??
                            0) +
                        1;
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Error fetching attendance for $dateString: $e');
        }
      }

      // Calculate each student's attendance using half-day/full-day logic
      final List<Map<String, dynamic>> report = [];
      int above75 = 0;
      int below75 = 0;
      double totalPercentage = 0.0;

      for (var student in students) {
        final studentId = student.id;
        final studentData = student.data();
        final dateAttendance = studentDateAttendance[studentId] ?? {};

        int workingDays = 0;
        double dayCredits = 0.0;

        dateAttendance.forEach((dateString, data) {
          final totalPeriods = data['total'] ?? 0;
          final presentPeriods = data['present'] ?? 0;
          final absentPeriods = totalPeriods - presentPeriods;

          if (totalPeriods > 0) {
            workingDays++;

            if (absentPeriods == 0) {
              dayCredits += 1.0;
            } else if (absentPeriods == 1) {
              dayCredits += 0.5;
            }
          }
        });

        final percentage = workingDays > 0
            ? (dayCredits / workingDays) * 100
            : 0.0;

        if (percentage >= 75) {
          above75++;
        } else {
          below75++;
        }
        totalPercentage += percentage;

        report.add({
          'name': studentData['name'] ?? 'Unknown',
          'rollNo': studentData['rollNo'] ?? '',
          'workingDays': workingDays,
          'dayCredits': dayCredits,
          'percentage': percentage,
        });
      }

      // Sort by roll number or name
      report.sort((a, b) {
        final rollA = a['rollNo'].toString();
        final rollB = b['rollNo'].toString();
        if (rollA.isNotEmpty && rollB.isNotEmpty) {
          return rollA.compareTo(rollB);
        }
        return a['name'].toString().compareTo(b['name'].toString());
      });

      final avgPercentage = students.isNotEmpty
          ? totalPercentage / students.length
          : 0.0;

      if (mounted) {
        setState(() {
          studentAttendanceReport = report;
          classOverallPercentage = avgPercentage;
          totalStudents = students.length;
          aboveThreshold = above75;
          belowThreshold = below75;
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
          'Class Report',
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
            'Select Class',
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
            },
          ),
          const SizedBox(height: 20),

          // Generate Report Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedClassId != null ? _generateReport : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
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
        // Class Info Card
        if (classData != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.class_,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        classData!['name'] ?? 'Unknown Class',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Total Students: $totalStudents',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Stats Row
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.percent,
                label: 'Class Average',
                value: '${classOverallPercentage.toStringAsFixed(1)}%',
                color: classOverallPercentage >= 75
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                icon: Icons.check_circle,
                label: 'Above 75%',
                value: '$aboveThreshold',
                color: const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                icon: Icons.warning,
                label: 'Below 75%',
                value: '$belowThreshold',
                color: const Color(0xFFF44336),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Student-wise breakdown
        const Text(
          'Student-wise Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (studentAttendanceReport.isEmpty)
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
                      SizedBox(
                        width: 40,
                        child: Text(
                          '#',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 60,
                        child: Text(
                          'Days',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 70,
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
                ...studentAttendanceReport.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast =
                      entry.key == studentAttendanceReport.length - 1;
                  final percentage = item['percentage'] as double;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: percentage < 75
                          ? Colors.red.withOpacity(0.05)
                          : null,
                      border: Border(
                        bottom: isLast
                            ? BorderSide.none
                            : BorderSide(color: Colors.white.withOpacity(0.1)),
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: Text(
                            item['rollNo'] != ''
                                ? item['rollNo']
                                : '${entry.key + 1}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            '${item['dayCredits'].toStringAsFixed(1)}/${item['workingDays']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
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
                              color: percentage >= 75
                                  ? Colors.green.withOpacity(0.2)
                                  : percentage >= 65
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.red.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${percentage.toStringAsFixed(1)}%',
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

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
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
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
        ],
      ),
    );
  }
}
