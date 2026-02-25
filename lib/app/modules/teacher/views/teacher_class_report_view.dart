import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../controllers/teacher_reports_controller.dart';

class TeacherClassReportView extends StatefulWidget {
  const TeacherClassReportView({super.key});

  @override
  State<TeacherClassReportView> createState() => _TeacherClassReportViewState();
}

class _TeacherClassReportViewState extends State<TeacherClassReportView> {
  List<Map<String, dynamic>> advisorClasses = [];
  String? selectedClassId;

  bool isLoadingReport = false;
  bool reportGenerated = false;

  // Report data
  String className = '';
  int totalStudents = 0;
  int above75 = 0;
  int below75 = 0;
  double avgPercentage = 0.0;
  List<Map<String, dynamic>> studentReports = [];

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
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading advisor classes: $e');
    }
  }

  Future<void> _generateReport() async {
    if (selectedClassId == null) return;

    setState(() {
      isLoadingReport = true;
      reportGenerated = false;
      studentReports = [];
    });

    try {
      // Get class data
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(selectedClassId)
          .get();
      final classData = classDoc.data() ?? {};

      // Get all students in this class
      final studentsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: selectedClassId)
          .get();

      // Calculate date range (last 90 days)
      final now = DateTime.now();
      final List<String> dateStrings = [];

      for (int i = 0; i < 90; i++) {
        final date = now.subtract(Duration(days: i));
        if (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          continue;
        }
        final dateString =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        dateStrings.add(dateString);
      }

      List<Map<String, dynamic>> reports = [];
      int countAbove75 = 0;
      int countBelow75 = 0;
      double totalPercentage = 0.0;

      for (var studentDoc in studentsSnapshot.docs) {
        final studentData = studentDoc.data();
        final studentId = studentDoc.id;

        int workingDays = 0;
        double dayCredits = 0.0;

        for (final dateString in dateStrings) {
          try {
            final periodDocs = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(selectedClassId)
                .collection(dateString)
                .get();

            if (periodDocs.docs.isEmpty) continue;

            int totalPeriods = 0;
            int presentPeriods = 0;

            for (var periodDoc in periodDocs.docs) {
              final data = periodDoc.data();
              if (data.containsKey('students') && data['students'] is Map) {
                final studentsMap = data['students'] as Map<String, dynamic>;
                if (studentsMap.containsKey(studentId)) {
                  totalPeriods++;
                  if (studentsMap[studentId] == true) presentPeriods++;
                }
              }
            }

            if (totalPeriods > 0) {
              workingDays++;
              final absentPeriods = totalPeriods - presentPeriods;
              dayCredits += absentPeriods == 0
                  ? 1.0
                  : (absentPeriods == 1 ? 0.5 : 0.0);
            }
          } catch (e) {
            debugPrint('Error: $e');
          }
        }

        final percentage = workingDays > 0
            ? (dayCredits / workingDays) * 100
            : 0.0;

        if (percentage >= 75) {
          countAbove75++;
        } else {
          countBelow75++;
        }
        totalPercentage += percentage;

        reports.add({
          'id': studentId,
          'name': studentData['name'] ?? 'Unknown',
          'rollNo': studentData['rollNo'] ?? '',
          'workingDays': workingDays,
          'dayCredits': dayCredits,
          'percentage': percentage,
        });
      }

      // Sort by roll number
      reports.sort(
        (a, b) => (a['rollNo'] as String).compareTo(b['rollNo'] as String),
      );

      if (mounted) {
        setState(() {
          className = classData['name'] ?? 'Unknown';
          totalStudents = studentsSnapshot.docs.length;
          above75 = countAbove75;
          below75 = countBelow75;
          avgPercentage = studentsSnapshot.docs.isNotEmpty
              ? totalPercentage / studentsSnapshot.docs.length
              : 0.0;
          studentReports = reports;
          isLoadingReport = false;
          reportGenerated = true;
        });
      }
    } catch (e) {
      debugPrint('Error generating class report: $e');
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
          'Class Reports',
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
              _buildClassHeader(),
              const SizedBox(height: 16),
              _buildClassStats(),
              const SizedBox(height: 16),
              _buildStudentTable(),
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
            'Select Class',
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
                reportGenerated = false;
              });
            },
          ),
          const SizedBox(height: 16),

          // Generate Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedClassId != null && !isLoadingReport
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

  Widget _buildClassHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF4CAF50).withOpacity(0.2),
            const Color(0xFF2E7D32).withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF4CAF50).withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.class_, color: Color(0xFF4CAF50), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$totalStudents Students',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassStats() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Students',
                '$totalStudents',
                Icons.people,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Class Average',
                '${avgPercentage.toStringAsFixed(1)}%',
                Icons.analytics,
                avgPercentage >= 75
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFFF9800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Above 75%',
                '$above75',
                Icons.thumb_up,
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Below 75%',
                '$below75',
                Icons.warning,
                const Color(0xFFF44336),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
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
      ),
    );
  }

  Widget _buildStudentTable() {
    if (studentReports.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: const Color(0xFF16213E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: const Center(
          child: Text(
            'No students found in this class',
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
              'Student Attendance',
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
                  child: Text(
                    'Roll',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Name',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Days',
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
                    'Credits',
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
          ...studentReports.asMap().entries.map((entry) {
            final report = entry.value;
            final isLast = entry.key == studentReports.length - 1;
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
                    child: Text(
                      report['rollNo'],
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      report['name'],
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      '${report['workingDays']}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      (report['dayCredits'] as double).toStringAsFixed(1),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
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
                        fontSize: 12,
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
                  reportType: 'class',
                  format: 'pdf',
                  entityId: selectedClassId!,
                  entityName: className,
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
                  reportType: 'class',
                  format: 'excel',
                  entityId: selectedClassId!,
                  entityName: className,
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
