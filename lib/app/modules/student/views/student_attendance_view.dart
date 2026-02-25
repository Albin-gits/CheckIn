import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class StudentAttendanceView extends StatefulWidget {
  const StudentAttendanceView({super.key});

  @override
  State<StudentAttendanceView> createState() => _StudentAttendanceViewState();
}

class _StudentAttendanceViewState extends State<StudentAttendanceView> {
  bool isLoading = true;
  String classId = '';
  String className = '';
  String studentId = '';
  List<Map<String, dynamic>> attendanceRecords = [];

  int totalClasses = 0;
  int presentCount = 0;
  double attendancePercentage = 0.0;

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
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      studentId = user.uid;

      // Get student's class
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists || userDoc.data() == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      final userData = userDoc.data()!;
      classId = userData['classId']?.toString() ?? '';

      // Get class name
      String? clsName = userData['className']?.toString();
      if ((clsName == null || clsName.isEmpty) && classId.isNotEmpty) {
        try {
          final classDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(classId)
              .get();
          if (classDoc.exists) {
            clsName = classDoc.data()?['name'] ?? classId;
          }
        } catch (e) {
          clsName = classId;
        }
      }
      className = clsName ?? '';

      if (classId.isEmpty) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }
        return;
      }

      // Load attendance records (last 30 days)
      final records = <Map<String, dynamic>>[];
      int present = 0;
      int total = 0;

      for (int i = 0; i < 30; i++) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateString = DateFormat('yyyy-MM-dd').format(date);
        final dayOfWeek = date.weekday;

        // Skip weekends
        if (dayOfWeek == DateTime.saturday || dayOfWeek == DateTime.sunday) {
          continue;
        }

        try {
          final periodDocs = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(classId)
              .collection(dateString)
              .get();

          for (var periodDoc in periodDocs.docs) {
            final data = periodDoc.data();
            final period = periodDoc.id;

            if (data.containsKey('students') && data['students'] is Map) {
              final studentsMap = data['students'] as Map<String, dynamic>;

              if (studentsMap.containsKey(studentId)) {
                final isPresent = studentsMap[studentId] == true;
                final markedBy = data['markedBy']?.toString() ?? 'Unknown';
                final markedByUid = data['markedByUid']?.toString() ?? '';

                // Get subject from timetable if available
                String subject = 'N/A';
                try {
                  final deptId = userData['departmentId']?.toString() ?? '';
                  if (deptId.isNotEmpty && classId.isNotEmpty) {
                    final dayKey = _getDayKey(date);
                    final slotDoc = await FirebaseFirestore.instance
                        .collection('timetable')
                        .doc(deptId)
                        .collection(classId)
                        .doc(dayKey)
                        .collection('slots')
                        .doc(period)
                        .get();

                    if (slotDoc.exists && slotDoc.data() != null) {
                      subject = slotDoc.data()?['subject']?.toString() ?? 'N/A';
                    }
                  }
                } catch (e) {
                  // Ignore timetable errors
                }

                records.add({
                  'date': dateString,
                  'displayDate': DateFormat('MMM dd, yyyy').format(date),
                  'day': _getDayName(date),
                  'period': period,
                  'time': periodTimes[period] ?? 'N/A',
                  'subject': subject,
                  'status': isPresent ? 'Present' : 'Absent',
                  'isPresent': isPresent,
                  'markedBy': markedBy,
                  'markedByUid': markedByUid,
                });

                total++;
                if (isPresent) present++;
              }
            }
          }
        } catch (e) {
          // Skip this date if error
          continue;
        }
      }

      // Sort by date descending (newest first)
      records.sort((a, b) => b['date'].compareTo(a['date']));

      final percentage = total > 0 ? (present / total) * 100 : 0.0;

      if (mounted) {
        setState(() {
          attendanceRecords = records;
          totalClasses = total;
          presentCount = present;
          attendancePercentage = percentage;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _getDayKey(DateTime date) {
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
        return '';
    }
  }

  String _getDayName(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'My Attendance',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: attendancePercentage >= 75
                            ? [const Color(0xFF4CAF50), const Color(0xFF81C784)]
                            : [
                                const Color(0xFFF44336),
                                const Color(0xFFEF5350),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (attendancePercentage >= 75
                                      ? Colors.green
                                      : Colors.red)
                                  .withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Overall Attendance',
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${attendancePercentage.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text(
                                  'Total Classes',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  totalClasses.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Present',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  presentCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                const Text(
                                  'Absent',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  (totalClasses - presentCount).toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (attendancePercentage < 75) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '⚠️ Attendance below 75%',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Class Info
                  Text(
                    'Class: $className',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Last 30 days (excluding weekends)',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Attendance Records
                  if (attendanceRecords.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16213E),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text(
                          'No attendance records found',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    ...attendanceRecords.map(
                      (record) => _buildAttendanceCard(record),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> record) {
    final isPresent = record['isPresent'] as bool;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPresent
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isPresent
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  isPresent ? Icons.check_circle : Icons.cancel,
                  color: isPresent ? Colors.green : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record['displayDate'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      record['day'],
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isPresent
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  record['status'],
                  style: TextStyle(
                    color: isPresent ? Colors.green : Colors.red,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.schedule, 'Period', record['period']),
          _buildInfoRow(Icons.access_time, 'Time', record['time']),
          _buildInfoRow(Icons.book, 'Subject', record['subject']),
          _buildInfoRow(Icons.person, 'Marked By', record['markedBy']),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
