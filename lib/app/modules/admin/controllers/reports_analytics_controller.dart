import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../views/report_preview_view.dart';

class ReportsAnalyticsController extends GetxController {
  final isExporting = false.obs;
  final isLoading = false.obs;

  // Expose firestore for dialog access
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // Analytics data
  final weeklyAverage = 0.0.obs;
  final monthlyAverage = 0.0.obs;
  final belowThreshold = 0.obs;
  final perfectAttendance = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadAnalytics();
  }

  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  bool get _shouldAbort => isClosed || !_isSignedIn;

  Future<void> loadAnalytics() async {
    try {
      isLoading.value = true;

      // If user is already logged out (or controller disposed), do not fetch.
      if (_shouldAbort) return;

      // Calculate weekly average
      final weekAgo = DateTime.now().subtract(const Duration(days: 7));
      final weeklyAttendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: weekAgo)
          .get();

      if (_shouldAbort) return;

      if (weeklyAttendance.docs.isNotEmpty) {
        final present = weeklyAttendance.docs
            .where((doc) => doc.data()['status'] == 'present')
            .length;
        weeklyAverage.value = (present / weeklyAttendance.docs.length) * 100;
      }

      // Calculate monthly average
      final monthAgo = DateTime.now().subtract(const Duration(days: 30));
      final monthlyAttendance = await FirebaseFirestore.instance
          .collection('attendance')
          .where('date', isGreaterThanOrEqualTo: monthAgo)
          .get();

      if (_shouldAbort) return;

      if (monthlyAttendance.docs.isNotEmpty) {
        final present = monthlyAttendance.docs
            .where((doc) => doc.data()['status'] == 'present')
            .length;
        monthlyAverage.value = (present / monthlyAttendance.docs.length) * 100;
      }

      // Calculate students below threshold (< 75%)
      final students = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      if (_shouldAbort) return;

      int belowThresholdCount = 0;
      int perfectAttendanceCount = 0;

      for (var student in students.docs) {
        if (_shouldAbort) return;
        final studentId = student.id;
        final records = await FirebaseFirestore.instance
            .collection('attendance')
            .where('studentId', isEqualTo: studentId)
            .get();

        if (_shouldAbort) return;

        if (records.docs.isEmpty) continue;

        final present = records.docs
            .where((doc) => doc.data()['status'] == 'present')
            .length;
        final percentage = (present / records.docs.length) * 100;

        if (percentage < 75) {
          belowThresholdCount++;
        }
        if (percentage == 100) {
          perfectAttendanceCount++;
        }
      }

      belowThreshold.value = belowThresholdCount;
      perfectAttendance.value = perfectAttendanceCount;
    } catch (e) {
      // Logging out while this is running can cause permission-denied.
      // In that case, silently ignore.
      if (isClosed || !_isSignedIn) {
        return;
      }
      Get.snackbar(
        'Error',
        'Failed to load analytics: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      if (!isClosed) {
        isLoading.value = false;
      }
    }
  }

  Future<void> generateStudentReport(String studentId) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      // Fetch student data
      final studentDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        Get.back();
        Get.snackbar(
          'Error',
          'Student not found',
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      final studentData = studentDoc.data()!;
      final attendanceRecords = await FirebaseFirestore.instance
          .collection('attendance')
          .where('studentId', isEqualTo: studentId)
          .get();

      Get.back(); // Close loading
      Get.snackbar(
        'Success',
        'Student report generated',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back();
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

  Future<void> generateDepartmentReport(String departmentId) async {
    try {
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(color: Color(0xFF00D9FF)),
        ),
        barrierDismissible: false,
      );

      // Fetch department data
      final deptDoc = await FirebaseFirestore.instance
          .collection('departments')
          .doc(departmentId)
          .get();

      if (!deptDoc.exists) {
        Get.back();
        Get.snackbar(
          'Error',
          'Department not found',
          backgroundColor: const Color(0xFFD32F2F),
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP,
          margin: const EdgeInsets.all(16),
          borderRadius: 12,
        );
        return;
      }

      Get.back(); // Close loading
      Get.snackbar(
        'Success',
        'Department report generated',
        backgroundColor: const Color(0xFF4CAF50),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      Get.back();
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

  Future<void> exportReport({
    required String reportType,
    required String format,
    required String entityId,
    required String entityName,
  }) async {
    try {
      isExporting.value = true;

      // Show loading dialog
      Get.dialog(
        Center(
          child: Card(
            color: const Color(0xFF16213E),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF00D9FF)),
                  const SizedBox(height: 16),
                  Text(
                    'Generating ${format.toUpperCase()} Report...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );

      // Fetch report data based on type
      final reportData = await _fetchReportData(reportType, entityId);

      // Generate file based on format
      File outputFile;
      if (format == 'pdf') {
        outputFile = await _generatePdfFile(reportType, entityName, reportData);
      } else {
        outputFile = await _generateExcelFile(
          reportType,
          entityName,
          reportData,
        );
      }

      Get.back(); // Close loading dialog

      // Show View/Share dialog
      _showFileActionDialog(
        outputFile,
        reportType,
        entityName,
        format,
        reportData,
      );
    } catch (e) {
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Error',
        'Failed to export report: $e',
        backgroundColor: const Color(0xFFD32F2F),
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } finally {
      isExporting.value = false;
    }
  }

  void _showFileActionDialog(
    File file,
    String reportType,
    String entityName,
    String format,
    Map<String, dynamic> reportData,
  ) {
    Get.dialog(
      Dialog(
        backgroundColor: const Color(0xFF16213E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xFF4CAF50),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Report Generated!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${reportType.capitalizeFirst} Report - $entityName',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              Text(
                format.toUpperCase(),
                style: TextStyle(
                  color: format == 'pdf'
                      ? const Color(0xFFF44336)
                      : const Color(0xFF4CAF50),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              // Preview Button (Full Width)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Get.back();
                    Get.to(
                      () => ReportPreviewView(
                        reportType: reportType,
                        entityName: entityName,
                        format: format,
                        reportData: reportData,
                        file: file,
                      ),
                    );
                  },
                  icon: const Icon(Icons.preview),
                  label: const Text('Preview Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9C27B0),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  // Open in External Viewer
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await OpenFilex.open(file.path);
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Open'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2196F3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Share Button
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Get.back();
                        await Share.shareXFiles(
                          [XFile(file.path)],
                          subject:
                              '${reportType.capitalizeFirst} Report - $entityName',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00D9FF),
                        foregroundColor: const Color(0xFF0F0C29),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white54),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _fetchReportData(
    String reportType,
    String entityId,
  ) async {
    final now = DateTime.now();
    final List<String> dateStrings = [];

    // Last 90 days
    for (int i = 0; i < 90; i++) {
      final date = now.subtract(Duration(days: i));
      if (date.weekday == DateTime.saturday || date.weekday == DateTime.sunday)
        continue;
      final dateString =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      dateStrings.add(dateString);
    }

    switch (reportType) {
      case 'student':
        return await _fetchStudentReportData(entityId, dateStrings);
      case 'class':
        return await _fetchClassReportData(entityId, dateStrings);
      case 'department':
        return await _fetchDepartmentReportData(entityId, dateStrings);
      default:
        return {};
    }
  }

  Future<Map<String, dynamic>> _fetchStudentReportData(
    String studentId,
    List<String> dateStrings,
  ) async {
    final studentDoc = await firestore.collection('users').doc(studentId).get();
    final studentData = studentDoc.data() ?? {};
    final classId = studentData['classId'];

    int workingDays = 0;
    double dayCredits = 0.0;
    List<Map<String, dynamic>> dailyRecords = [];

    if (classId != null) {
      for (final dateString in dateStrings) {
        try {
          final periodDocs = await firestore
              .collection('attendance')
              .doc(classId)
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
            double credit = absentPeriods == 0
                ? 1.0
                : (absentPeriods == 1 ? 0.5 : 0.0);
            dayCredits += credit;

            dailyRecords.add({
              'date': dateString,
              'totalPeriods': totalPeriods,
              'presentPeriods': presentPeriods,
              'status': absentPeriods == 0
                  ? 'Full Day'
                  : (absentPeriods == 1 ? 'Half Day' : 'Absent'),
            });
          }
        } catch (e) {
          debugPrint('Error fetching attendance for $dateString: $e');
        }
      }
    }

    final percentage = workingDays > 0 ? (dayCredits / workingDays) * 100 : 0.0;

    return {
      'name': studentData['name'] ?? 'Unknown',
      'rollNo': studentData['rollNo'] ?? '',
      'email': studentData['email'] ?? '',
      'workingDays': workingDays,
      'dayCredits': dayCredits,
      'percentage': percentage,
      'dailyRecords': dailyRecords,
    };
  }

  Future<Map<String, dynamic>> _fetchClassReportData(
    String classId,
    List<String> dateStrings,
  ) async {
    final classDoc = await firestore.collection('classes').doc(classId).get();
    final classData = classDoc.data() ?? {};

    final studentsSnapshot = await firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classId)
        .get();

    List<Map<String, dynamic>> studentReports = [];
    int above75 = 0;
    int below75 = 0;
    double totalPercentage = 0.0;

    for (var studentDoc in studentsSnapshot.docs) {
      final studentData = studentDoc.data();
      final studentId = studentDoc.id;

      int workingDays = 0;
      double dayCredits = 0.0;

      for (final dateString in dateStrings) {
        try {
          final periodDocs = await firestore
              .collection('attendance')
              .doc(classId)
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
      if (percentage >= 75)
        above75++;
      else
        below75++;
      totalPercentage += percentage;

      studentReports.add({
        'name': studentData['name'] ?? 'Unknown',
        'rollNo': studentData['rollNo'] ?? '',
        'workingDays': workingDays,
        'dayCredits': dayCredits,
        'percentage': percentage,
      });
    }

    studentReports.sort(
      (a, b) => a['rollNo'].toString().compareTo(b['rollNo'].toString()),
    );

    return {
      'className': classData['name'] ?? 'Unknown',
      'totalStudents': studentsSnapshot.docs.length,
      'above75': above75,
      'below75': below75,
      'avgPercentage': studentsSnapshot.docs.isNotEmpty
          ? totalPercentage / studentsSnapshot.docs.length
          : 0.0,
      'students': studentReports,
    };
  }

  Future<Map<String, dynamic>> _fetchDepartmentReportData(
    String departmentId,
    List<String> dateStrings,
  ) async {
    final deptDoc = await firestore
        .collection('departments')
        .doc(departmentId)
        .get();
    final deptData = deptDoc.data() ?? {};

    final classesSnapshot = await firestore
        .collection('classes')
        .where('departmentId', isEqualTo: departmentId)
        .get();

    List<Map<String, dynamic>> classReports = [];
    int totalStudents = 0;
    int allAbove75 = 0;
    int allBelow75 = 0;
    double totalClassPercentage = 0.0;

    for (var classDoc in classesSnapshot.docs) {
      final classData = await _fetchClassReportData(classDoc.id, dateStrings);
      totalStudents += classData['totalStudents'] as int;
      allAbove75 += classData['above75'] as int;
      allBelow75 += classData['below75'] as int;
      totalClassPercentage += classData['avgPercentage'] as double;

      classReports.add({
        'className': classData['className'],
        'studentCount': classData['totalStudents'],
        'above75': classData['above75'],
        'below75': classData['below75'],
        'avgPercentage': classData['avgPercentage'],
      });
    }

    classReports.sort(
      (a, b) => a['className'].toString().compareTo(b['className'].toString()),
    );

    return {
      'departmentName': deptData['name'] ?? 'Unknown',
      'totalClasses': classesSnapshot.docs.length,
      'totalStudents': totalStudents,
      'studentsAbove75': allAbove75,
      'studentsBelow75': allBelow75,
      'avgPercentage': classesSnapshot.docs.isNotEmpty
          ? totalClassPercentage / classesSnapshot.docs.length
          : 0.0,
      'classes': classReports,
    };
  }

  Future<File> _generatePdfFile(
    String reportType,
    String entityName,
    Map<String, dynamic> data,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Text(
                '${reportType.capitalizeFirst} Attendance Report',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.Text(
              'Entity: $entityName',
              style: const pw.TextStyle(fontSize: 14),
            ),
            pw.Text(
              'Generated: ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
            pw.SizedBox(height: 20),
            ..._buildPdfContent(reportType, data),
          ];
        },
      ),
    );

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${reportType}_report_$timestamp.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  List<pw.Widget> _buildPdfContent(
    String reportType,
    Map<String, dynamic> data,
  ) {
    switch (reportType) {
      case 'student':
        return [
          pw.Table.fromTextArray(
            headers: ['Field', 'Value'],
            data: [
              ['Name', data['name']],
              ['Roll No', data['rollNo']],
              ['Working Days', '${data['workingDays']}'],
              ['Day Credits', '${data['dayCredits']}'],
              [
                'Attendance %',
                '${(data['percentage'] as double).toStringAsFixed(1)}%',
              ],
            ],
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ];
      case 'class':
        final students = data['students'] as List<Map<String, dynamic>>;
        return [
          pw.Text(
            'Class: ${data['className']}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Total Students: ${data['totalStudents']} | Above 75%: ${data['above75']} | Below 75%: ${data['below75']}',
          ),
          pw.Text(
            'Class Average: ${(data['avgPercentage'] as double).toStringAsFixed(1)}%',
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Roll No', 'Name', 'Days', 'Credits', '%'],
            data: students
                .map(
                  (s) => [
                    s['rollNo'],
                    s['name'],
                    '${s['workingDays']}',
                    '${(s['dayCredits'] as double).toStringAsFixed(1)}',
                    '${(s['percentage'] as double).toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ];
      case 'department':
        final classes = data['classes'] as List<Map<String, dynamic>>;
        return [
          pw.Text(
            'Department: ${data['departmentName']}',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            'Total Classes: ${data['totalClasses']} | Total Students: ${data['totalStudents']}',
          ),
          pw.Text(
            'Above 75%: ${data['studentsAbove75']} | Below 75%: ${data['studentsBelow75']}',
          ),
          pw.Text(
            'Department Average: ${(data['avgPercentage'] as double).toStringAsFixed(1)}%',
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Class', 'Students', 'Above 75%', 'Below 75%', 'Avg %'],
            data: classes
                .map(
                  (c) => [
                    c['className'],
                    '${c['studentCount']}',
                    '${c['above75']}',
                    '${c['below75']}',
                    '${(c['avgPercentage'] as double).toStringAsFixed(1)}%',
                  ],
                )
                .toList(),
            border: pw.TableBorder.all(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ];
      default:
        return [];
    }
  }

  Future<File> _generateExcelFile(
    String reportType,
    String entityName,
    Map<String, dynamic> data,
  ) async {
    final excel = Excel.createExcel();
    final sheet = excel['Report'];

    // Header
    sheet.appendRow([
      TextCellValue('${reportType.capitalizeFirst} Attendance Report'),
    ]);
    sheet.appendRow([TextCellValue('Entity: $entityName')]);
    sheet.appendRow([
      TextCellValue('Generated: ${DateTime.now().toString().split('.')[0]}'),
    ]);
    sheet.appendRow([TextCellValue('')]);

    switch (reportType) {
      case 'student':
        sheet.appendRow([TextCellValue('Field'), TextCellValue('Value')]);
        sheet.appendRow([TextCellValue('Name'), TextCellValue(data['name'])]);
        sheet.appendRow([
          TextCellValue('Roll No'),
          TextCellValue(data['rollNo']),
        ]);
        sheet.appendRow([
          TextCellValue('Working Days'),
          IntCellValue(data['workingDays']),
        ]);
        sheet.appendRow([
          TextCellValue('Day Credits'),
          DoubleCellValue(data['dayCredits']),
        ]);
        sheet.appendRow([
          TextCellValue('Attendance %'),
          TextCellValue(
            '${(data['percentage'] as double).toStringAsFixed(1)}%',
          ),
        ]);
        break;
      case 'class':
        final students = data['students'] as List<Map<String, dynamic>>;
        sheet.appendRow([TextCellValue('Class: ${data['className']}')]);
        sheet.appendRow([
          TextCellValue(
            'Total: ${data['totalStudents']} | Above 75%: ${data['above75']} | Below 75%: ${data['below75']} | Avg: ${(data['avgPercentage'] as double).toStringAsFixed(1)}%',
          ),
        ]);
        sheet.appendRow([TextCellValue('')]);
        sheet.appendRow([
          TextCellValue('Roll No'),
          TextCellValue('Name'),
          TextCellValue('Working Days'),
          TextCellValue('Credits'),
          TextCellValue('Percentage'),
        ]);
        for (var s in students) {
          sheet.appendRow([
            TextCellValue(s['rollNo']),
            TextCellValue(s['name']),
            IntCellValue(s['workingDays']),
            DoubleCellValue(s['dayCredits']),
            TextCellValue('${(s['percentage'] as double).toStringAsFixed(1)}%'),
          ]);
        }
        break;
      case 'department':
        final classes = data['classes'] as List<Map<String, dynamic>>;
        sheet.appendRow([
          TextCellValue('Department: ${data['departmentName']}'),
        ]);
        sheet.appendRow([
          TextCellValue(
            'Classes: ${data['totalClasses']} | Students: ${data['totalStudents']} | Above 75%: ${data['studentsAbove75']} | Below 75%: ${data['studentsBelow75']}',
          ),
        ]);
        sheet.appendRow([TextCellValue('')]);
        sheet.appendRow([
          TextCellValue('Class'),
          TextCellValue('Students'),
          TextCellValue('Above 75%'),
          TextCellValue('Below 75%'),
          TextCellValue('Avg %'),
        ]);
        for (var c in classes) {
          sheet.appendRow([
            TextCellValue(c['className']),
            IntCellValue(c['studentCount']),
            IntCellValue(c['above75']),
            IntCellValue(c['below75']),
            TextCellValue(
              '${(c['avgPercentage'] as double).toStringAsFixed(1)}%',
            ),
          ]);
        }
        break;
    }

    // Remove default Sheet1
    excel.delete('Sheet1');

    final directory = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${directory.path}/${reportType}_report_$timestamp.xlsx');
    await file.writeAsBytes(excel.encode()!);
    return file;
  }
}
