import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List<Map<String, dynamic>> _clients = [];
  Map<String, int> _statusCounts = {};
  Map<String, int> _monthlyFilingCounts = {};

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    final clients = await DatabaseHelper.instance.getAllClients();
    setState(() {
      _clients = clients;
      _calculateStatusCounts();
      _calculateMonthlyFilingCounts();
    });
  }

  void _calculateStatusCounts() {
    _statusCounts = {'Pending': 0, 'In Progress': 0, 'Completed': 0};

    for (var client in _clients) {
      final status = client['filingStatus'] as String;
      _statusCounts[status] = (_statusCounts[status] ?? 0) + 1;
    }
  }

  void _calculateMonthlyFilingCounts() {
    _monthlyFilingCounts = {};
    final now = DateTime.now();
    final months = List.generate(6, (index) {
      final date = DateTime(now.year, now.month - index, 1);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}';
    }).reversed.toList();

    for (var month in months) {
      _monthlyFilingCounts[month] = 0;
    }

    for (var client in _clients) {
      if (client['lastFilingDate'] != null) {
        final filingDate = DateTime.parse(client['lastFilingDate']);
        final monthKey =
            '${filingDate.year}-${filingDate.month.toString().padLeft(2, '0')}';
        if (_monthlyFilingCounts.containsKey(monthKey)) {
          _monthlyFilingCounts[monthKey] =
              (_monthlyFilingCounts[monthKey] ?? 0) + 1;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reports & Analytics',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildStatusDistributionCard(),
            const SizedBox(height: 20),
            _buildMonthlyFilingCard(),
            const SizedBox(height: 20),
            _buildClientSummaryCard(),
            const SizedBox(height: 20),
            Center(
              child: ElevatedButton.icon(
                onPressed: _generateOverallReportPdf,
                icon: const Icon(Icons.download),
                label: const Text('Generate Overall CA Report'),
                style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistributionCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filing Status Distribution',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ..._statusCounts.entries.map((entry) {
              final percentage = _clients.isEmpty
                  ? 0.0
                  : (entry.value / _clients.length * 100).toStringAsFixed(1);
              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [Text(entry.key), Text('$percentage%')],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: _clients.isEmpty ? 0 : entry.value / _clients.length,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      entry.key == 'Completed'
                          ? Colors.green
                          : entry.key == 'In Progress'
                              ? Colors.orange
                              : Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthlyFilingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Monthly Filing Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _monthlyFilingCounts.entries.map((entry) {
                  final maxCount = _monthlyFilingCounts.values.reduce(
                    (a, b) => a > b ? a : b,
                  );
                  final height =
                      maxCount == 0 ? 0.0 : entry.value / maxCount * 150;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        entry.value.toString(),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 30,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        entry.key.substring(5),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientSummaryCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Client Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildSummaryRow('Total Clients', _clients.length.toString()),
            _buildSummaryRow(
              'Pending Filings',
              _statusCounts['Pending'].toString(),
            ),
            _buildSummaryRow(
              'Completed This Month',
              _monthlyFilingCounts.values.last.toString(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _generateOverallReportPdf() async {
    try {
      final String caName =
          (await SharedPreferences.getInstance()).getString('caName') ?? 'N/A';
      final String caMobile =
          (await SharedPreferences.getInstance()).getString('caMobileNumber') ??
              'N/A';

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          build: (pw.Context context) => [
            pw.Center(
              child: pw.Text(
                'Overall CA Report',
                style:
                    pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 30),
            pw.Text(
              'Client Details',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            for (var client in _clients) ...[
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text('Name: ${client['name']}',
                              style: pw.TextStyle(
                                  fontWeight: pw.FontWeight.bold))),
                      pw.Expanded(
                          child: pw.Text('PAN: ${client['panNumber']}')),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(child: pw.Text('Phone: ${client['phone']}')),
                      pw.Expanded(child: pw.Text('Email: ${client['email']}')),
                    ],
                  ),
                  pw.Row(
                    children: [
                      pw.Expanded(
                          child: pw.Text(
                        'Fees Charged: ${client['feesCharged']?.toStringAsFixed(2) ?? '0.00'}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue),
                      )),
                      pw.Expanded(
                          child: pw.Text(
                        'Fees Paid: ${client['feesPaid']?.toStringAsFixed(2) ?? '0.00'}',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green),
                      )),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                ],
              ),
              if (client != _clients.last) pw.Divider(),
            ],
            pw.SizedBox(height: 40),
            pw.Text(
              'CA DETAILS',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Name: $caName'),
                pw.Text('Number: $caMobile'),
              ],
            ),
          ],
        ),
      );

      final String dir = (await getTemporaryDirectory()).path;
      final String fileName = 'overall_ca_report.pdf';
      final File file = File('$dir/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generating overall report...')),
        );
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate overall report: $e')),
        );
      }
    }
  }

  pw.Widget _buildPdfText(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 150,
            child: pw.Text(label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
