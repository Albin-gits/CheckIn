import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DepartmentReportView extends StatefulWidget {
  const DepartmentReportView({super.key});

  @override
  State<DepartmentReportView> createState() => _DepartmentReportViewState();
}

class _DepartmentReportViewState extends State<DepartmentReportView> {
  List<Map<String, dynamic>> departments = [];

  String? selectedDepartmentId;

  bool isLoadingReport = false;

  // Report data
  Map<String, dynamic>? departmentData;
  List<Map<String, dynamic>> classAttendanceReport = [];
  double departmentOverallPercentage = 0.0;
  int totalClasses = 0;
  int totalStudents = 0;
  int studentsAboveThreshold = 0;
  int studentsBelowThreshold = 0;
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

  Future<void> _generateReport() async {
    if (selectedDepartmentId == null) {
      return;
    }

    setState(() {
      isLoadingReport = true;
      classAttendanceReport = [];
      reportGenerated = false;
    });

    try {
      // Get department data
      final deptDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(selectedDepartmentId)
          .get();

      departmentData = deptDoc.data();

      // Get all classes in this department
      final classesSnapshot = await FirebaseFirestore.instance
          .collection('classes')
          .where('departmentId', isEqualTo: selectedDepartmentId)
          .get();

      final classesData = classesSnapshot.docs;

      // Calculate date range (last 90 days)
      final now = DateTime.now();
      final List<String> dateStrings = [];

      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        final dayOfWeek = date.weekday;

        if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
          continue;
        }

        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dateStrings.add(dateString);
      }

      // Process each class
      final List<Map<String, dynamic>> report = [];
      int allStudents = 0;
      int allAbove75 = 0;
      int allBelow75 = 0;
      double totalClassPercentage = 0.0;

      for (var classDoc in classesData) {
        final classId = classDoc.id;
        final className = classDoc.data()['name'] ?? 'Unknown';

        // Get all students in this class
        final studentsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .where('classId', isEqualTo: classId)
            .get();

        final students = studentsSnapshot.docs;
        allStudents += students.length;

        // Track student date-wise attendance
        final Map<String, Map<String, Map<String, int>>> studentDateAttendance =
            {};

        for (var student in students) {
          studentDateAttendance[student.id] = {};
        }

        // Fetch attendance records for this class
        for (final dateString in dateStrings) {
          try {
            final periodDocs = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(classId)
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

        // Calculate each student's attendance
        int classAbove75 = 0;
        int classBelow75 = 0;
        double totalStudentPercentage = 0.0;

        for (var student in students) {
          final studentId = student.id;
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
            classAbove75++;
            allAbove75++;
          } else {
            classBelow75++;
            allBelow75++;
          }
          totalStudentPercentage += percentage;
        }

        final classAverage = students.isNotEmpty
            ? totalStudentPercentage / students.length
            : 0.0;
        totalClassPercentage += classAverage;

        report.add({
          'className': className,
          'studentCount': students.length,
          'above75': classAbove75,
          'below75': classBelow75,
          'avgPercentage': classAverage,
        });
      }

      // Sort by class name
      report.sort(
        (a, b) =>
            a['className'].toString().compareTo(b['className'].toString()),
      );

      final deptAverage = classesData.isNotEmpty
          ? totalClassPercentage / classesData.length
          : 0.0;

      if (mounted) {
        setState(() {
          classAttendanceReport = report;
          departmentOverallPercentage = deptAverage;
          totalClasses = classesData.length;
          totalStudents = allStudents;
          studentsAboveThreshold = allAbove75;
          studentsBelowThreshold = allBelow75;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: const Text(
          'Department Report',
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
            'Select Department',
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
                classAttendanceReport = [];
              });
            },
          ),
          const SizedBox(height: 20),

          // Generate Report Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedDepartmentId != null ? _generateReport : null,
              icon: const Icon(Icons.analytics),
              label: const Text('Generate Report'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2196F3),
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
        // Department Info Card
        if (departmentData != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
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
                    Icons.business,
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
                        departmentData!['name'] ?? 'Unknown Department',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$totalClasses Classes | $totalStudents Students',
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

        // Stats Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _buildStatCard(
              icon: Icons.percent,
              label: 'Department Average',
              value: '${departmentOverallPercentage.toStringAsFixed(1)}%',
              color: departmentOverallPercentage >= 75
                  ? const Color(0xFF4CAF50)
                  : const Color(0xFFFF9800),
            ),
            _buildStatCard(
              icon: Icons.people,
              label: 'Total Students',
              value: '$totalStudents',
              color: const Color(0xFF2196F3),
            ),
            _buildStatCard(
              icon: Icons.check_circle,
              label: 'Above 75%',
              value: '$studentsAboveThreshold',
              color: const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              icon: Icons.warning,
              label: 'Below 75%',
              value: '$studentsBelowThreshold',
              color: const Color(0xFFF44336),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Class-wise breakdown
        const Text(
          'Class-wise Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),

        if (classAttendanceReport.isEmpty)
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
                          'Class',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Text(
                          'Std',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '75+',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          '<75',
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
                          'Avg',
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
                ...classAttendanceReport.asMap().entries.map((entry) {
                  final item = entry.value;
                  final isLast = entry.key == classAttendanceReport.length - 1;
                  final percentage = item['avgPercentage'] as double;

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
                        Expanded(
                          flex: 3,
                          child: Text(
                            item['className'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(
                          width: 50,
                          child: Text(
                            '${item['studentCount']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${item['above75']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF4CAF50),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${item['below75']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFF44336),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
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
                                fontSize: 11,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
