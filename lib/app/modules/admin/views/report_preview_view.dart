import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class ReportPreviewView extends StatelessWidget {
  final String reportType;
  final String entityName;
  final String format;
  final Map<String, dynamic> reportData;
  final File file;

  const ReportPreviewView({
    super.key,
    required this.reportType,
    required this.entityName,
    required this.format,
    required this.reportData,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF16213E),
        title: Text(
          '${_capitalizeFirst(reportType)} Report',
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in viewer',
            onPressed: () => OpenFilex.open(file.path),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: () => Share.shareXFiles([
              XFile(file.path),
            ], subject: '${_capitalizeFirst(reportType)} Report - $entityName'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),
            _buildReportContent(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getGradientColors(),
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
            child: Icon(_getIcon(), color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entityName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        format.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Generated: ${DateTime.now().toString().split('.')[0]}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (reportType) {
      case 'student':
        return _buildStudentReport();
      case 'class':
        return _buildClassReport();
      case 'department':
        return _buildDepartmentReport();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStudentReport() {
    final percentage = (reportData['percentage'] as double?) ?? 0.0;
    final dailyRecords =
        reportData['dailyRecords'] as List<Map<String, dynamic>>? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Student Info
        _buildInfoCard([
          _infoRow('Name', reportData['name'] ?? 'Unknown'),
          _infoRow('Roll No', reportData['rollNo'] ?? '-'),
          _infoRow('Email', reportData['email'] ?? '-'),
        ]),
        const SizedBox(height: 16),

        // Attendance Summary
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Working Days',
                '${reportData['workingDays'] ?? 0}',
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Day Credits',
                '${(reportData['dayCredits'] as double?)?.toStringAsFixed(1) ?? '0'}',
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Attendance',
                '${percentage.toStringAsFixed(1)}%',
                percentage >= 75
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFFF44336),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Daily Records
        if (dailyRecords.isNotEmpty) ...[
          _sectionTitle('Daily Records'),
          const SizedBox(height: 12),
          _buildDataTable(
            headers: ['Date', 'Periods', 'Present', 'Status'],
            rows: dailyRecords
                .take(20)
                .map<List<String>>(
                  (r) => <String>[
                    r['date']?.toString() ?? '',
                    '${r['totalPeriods'] ?? 0}',
                    '${r['presentPeriods'] ?? 0}',
                    r['status']?.toString() ?? '',
                  ],
                )
                .toList(),
          ),
          if (dailyRecords.length > 20)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '... and ${dailyRecords.length - 20} more records',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ),
        ] else
          _buildEmptyState('No attendance records found'),
      ],
    );
  }

  Widget _buildClassReport() {
    final students =
        reportData['students'] as List<Map<String, dynamic>>? ?? [];
    final avgPercentage = (reportData['avgPercentage'] as double?) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Class Stats
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Students',
                '${reportData['totalStudents'] ?? 0}',
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Above 75%',
                '${reportData['above75'] ?? 0}',
                const Color(0xFF4CAF50),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Below 75%',
                '${reportData['below75'] ?? 0}',
                const Color(0xFFF44336),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Class Average',
          '${avgPercentage.toStringAsFixed(1)}%',
          avgPercentage >= 75
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF9800),
        ),
        const SizedBox(height: 20),

        // Student List
        if (students.isNotEmpty) ...[
          _sectionTitle('Student Attendance'),
          const SizedBox(height: 12),
          _buildDataTable(
            headers: ['Roll', 'Name', 'Days', 'Credits', '%'],
            rows: students
                .map<List<String>>(
                  (s) => <String>[
                    s['rollNo']?.toString() ?? '-',
                    s['name']?.toString() ?? 'Unknown',
                    '${s['workingDays'] ?? 0}',
                    '${(s['dayCredits'] as double?)?.toStringAsFixed(1) ?? '0'}',
                    '${(s['percentage'] as double?)?.toStringAsFixed(1) ?? '0'}%',
                  ],
                )
                .toList(),
            highlightLowPercentage: true,
            percentageColumn: 4,
          ),
        ] else
          _buildEmptyState('No students found'),
      ],
    );
  }

  Widget _buildDepartmentReport() {
    final classes = reportData['classes'] as List<Map<String, dynamic>>? ?? [];
    final avgPercentage = (reportData['avgPercentage'] as double?) ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Department Stats
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _buildStatCard(
              'Classes',
              '${reportData['totalClasses'] ?? 0}',
              const Color(0xFF9C27B0),
            ),
            _buildStatCard(
              'Students',
              '${reportData['totalStudents'] ?? 0}',
              const Color(0xFF2196F3),
            ),
            _buildStatCard(
              'Above 75%',
              '${reportData['studentsAbove75'] ?? 0}',
              const Color(0xFF4CAF50),
            ),
            _buildStatCard(
              'Below 75%',
              '${reportData['studentsBelow75'] ?? 0}',
              const Color(0xFFF44336),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatCard(
          'Department Average',
          '${avgPercentage.toStringAsFixed(1)}%',
          avgPercentage >= 75
              ? const Color(0xFF4CAF50)
              : const Color(0xFFFF9800),
        ),
        const SizedBox(height: 20),

        // Class List
        if (classes.isNotEmpty) ...[
          _sectionTitle('Class-wise Breakdown'),
          const SizedBox(height: 12),
          _buildDataTable(
            headers: ['Class', 'Students', '75+', '<75', 'Avg'],
            rows: classes
                .map<List<String>>(
                  (c) => <String>[
                    c['className']?.toString() ?? 'Unknown',
                    '${c['studentCount'] ?? 0}',
                    '${c['above75'] ?? 0}',
                    '${c['below75'] ?? 0}',
                    '${(c['avgPercentage'] as double?)?.toStringAsFixed(1) ?? '0'}%',
                  ],
                )
                .toList(),
            highlightLowPercentage: true,
            percentageColumn: 4,
          ),
        ] else
          _buildEmptyState('No classes found'),
      ],
    );
  }

  Widget _buildInfoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDataTable({
    required List<String> headers,
    required List<List<String>> rows,
    bool highlightLowPercentage = false,
    int? percentageColumn,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF0F4C75),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: headers.asMap().entries.map((e) {
                return Expanded(
                  flex: e.key == 1 ? 2 : 1,
                  child: Text(
                    e.value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    textAlign: e.key == 0 || e.key == 1
                        ? TextAlign.left
                        : TextAlign.center,
                  ),
                );
              }).toList(),
            ),
          ),
          // Rows
          ...rows.asMap().entries.map((entry) {
            final row = entry.value;
            final isLast = entry.key == rows.length - 1;

            bool isLowPercentage = false;
            if (highlightLowPercentage &&
                percentageColumn != null &&
                percentageColumn < row.length) {
              final percentStr = row[percentageColumn].replaceAll('%', '');
              final percent = double.tryParse(percentStr) ?? 100;
              isLowPercentage = percent < 75;
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: isLowPercentage ? Colors.red.withOpacity(0.1) : null,
                border: Border(
                  bottom: isLast
                      ? BorderSide.none
                      : BorderSide(color: Colors.white.withOpacity(0.05)),
                ),
              ),
              child: Row(
                children: row.asMap().entries.map((e) {
                  return Expanded(
                    flex: e.key == 1 ? 2 : 1,
                    child: Text(
                      e.value,
                      style: TextStyle(
                        color: isLowPercentage && e.key == percentageColumn
                            ? const Color(0xFFF44336)
                            : Colors.white70,
                        fontSize: 12,
                      ),
                      textAlign: e.key == 0 || e.key == 1
                          ? TextAlign.left
                          : TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
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
            const Icon(Icons.info_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => OpenFilex.open(file.path),
              icon: Icon(
                format == 'pdf' ? Icons.picture_as_pdf : Icons.table_chart,
              ),
              label: Text('Open ${format.toUpperCase()}'),
              style: ElevatedButton.styleFrom(
                backgroundColor: format == 'pdf'
                    ? const Color(0xFFF44336)
                    : const Color(0xFF4CAF50),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Share.shareXFiles(
                [XFile(file.path)],
                subject: '${_capitalizeFirst(reportType)} Report - $entityName',
              ),
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D9FF),
                foregroundColor: const Color(0xFF0F0C29),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    switch (reportType) {
      case 'student':
        return [const Color(0xFF00D9FF), const Color(0xFF0097A7)];
      case 'class':
        return [const Color(0xFF4CAF50), const Color(0xFF2E7D32)];
      case 'department':
        return [const Color(0xFF2196F3), const Color(0xFF1565C0)];
      default:
        return [const Color(0xFF00D9FF), const Color(0xFF0097A7)];
    }
  }

  IconData _getIcon() {
    switch (reportType) {
      case 'student':
        return Icons.person;
      case 'class':
        return Icons.class_;
      case 'department':
        return Icons.business;
      default:
        return Icons.description;
    }
  }

  String _capitalizeFirst(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
