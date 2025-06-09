import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'client_detail_page.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class ClientListPage extends StatefulWidget {
  const ClientListPage({super.key});

  @override
  State<ClientListPage> createState() => _ClientListPageState();
}

class _ClientListPageState extends State<ClientListPage> {
  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _filteredClients = [];
  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadClients();
  }

  Future<void> _loadClients() async {
    final clients = await DatabaseHelper.instance.getAllClients();
    setState(() {
      _clients = clients;
      _applyFilters();
    });
  }

  void _applyFilters() {
    setState(() {
      _filteredClients = _clients.where((client) {
        final matchesSearch = client['name'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ) ||
            client['panNumber'].toString().toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                );

        final matchesFilter = _selectedFilter == 'All' ||
            client['filingStatus'] == _selectedFilter;

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clients'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search Clients',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                      _applyFilters();
                    });
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filter by Status',
                    border: OutlineInputBorder(),
                  ),
                  items: ['All', 'Pending', 'In Progress', 'Completed']
                      .map(
                        (status) => DropdownMenuItem(
                            value: status, child: Text(status)),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFilter = value!;
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filteredClients.length,
              itemBuilder: (context, index) {
                final client = _filteredClients[index];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(client['name'][0].toUpperCase()),
                    ),
                    title: Text(client['name']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PAN: ${client['panNumber']}'),
                        Text('Status: ${client['filingStatus']}'),
                        if (client['filingDeadline'] != null &&
                            client['filingDeadline'].isNotEmpty)
                          Text('Deadline: ${client['filingDeadline']}'),
                        Text(
                            'Fees Charged: ${client['feesCharged']?.toStringAsFixed(2) ?? '0.00'}'),
                        Text(
                            'Fees Paid: ${client['feesPaid']?.toStringAsFixed(2) ?? '0.00'}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8.0,
                          runSpacing: 4.0,
                          children: [
                            if (client['filingStatus'] != 'Completed')
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _showCompleteFilingDialog(
                                      context, client);
                                },
                                icon: const Icon(Icons.check_circle_outline,
                                    size: 18),
                                label: const Text('Complete Filing'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green.shade100,
                                  foregroundColor: Colors.green.shade800,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            if ((client['feesCharged'] ?? 0.0) >
                                (client['feesPaid'] ?? 0.0))
                              ElevatedButton.icon(
                                onPressed: () async {
                                  await _showPayFeesDialog(context, client);
                                },
                                icon: const Icon(Icons.payment, size: 18),
                                label: const Text('Pay Fees'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade100,
                                  foregroundColor: Colors.blue.shade800,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(value: 'edit', child: Text('Edit')),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Text('Delete'),
                        ),
                        const PopupMenuItem(
                          value: 'generate_report',
                          child: Text('Generate Report'),
                        ),
                      ],
                      onSelected: (value) async {
                        if (value == 'edit') {
                          // TODO: Navigate to edit page
                        } else if (value == 'delete') {
                          await DatabaseHelper.instance.deleteClient(
                            client['id'],
                          );
                          _loadClients();
                        } else if (value == 'generate_report') {
                          await _generateClientReportPdf(client);
                        }
                      },
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ClientDetailPage(client: client),
                        ),
                      ).then((_) => _loadClients());
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCompleteFilingDialog(
      BuildContext context, Map<String, dynamic> client) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Complete Filing?'),
          content: Text(
              'Are you sure you want to mark ${client['name']}\'s filing as completed?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Complete'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final updatedClient = Map<String, dynamic>.from(client);
      updatedClient['filingStatus'] = 'Completed';
      await DatabaseHelper.instance.updateClient(updatedClient);
      _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${client['name']}\'s filing status updated to Completed.')),
        );
      }
    }
  }

  Future<void> _showPayFeesDialog(
      BuildContext context, Map<String, dynamic> client) async {
    final TextEditingController amountController = TextEditingController();
    final double feesCharged = client['feesCharged'] ?? 0.0;
    final double feesPaid = client['feesPaid'] ?? 0.0;
    final double remainingFees = feesCharged - feesPaid;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Pay Fees'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Client: ${client['name']}'),
              Text('Fees Charged: ${feesCharged.toStringAsFixed(2)}'),
              Text('Fees Paid: ${feesPaid.toStringAsFixed(2)}'),
              Text('Remaining: ${remainingFees.toStringAsFixed(2)}'),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount to Pay',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final double? enteredAmount =
                    double.tryParse(amountController.text);
                if (enteredAmount != null &&
                    enteredAmount > 0 &&
                    enteredAmount <= remainingFees) {
                  Navigator.of(dialogContext).pop(true);
                } else {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please enter a valid amount less than or equal to remaining fees.')),
                  );
                }
              },
              child: const Text('Pay'),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      final double amountToPay = double.parse(amountController.text);
      final double newFeesPaid = feesPaid + amountToPay;
      await DatabaseHelper.instance
          .updateClientFeesPaid(client['id'], newFeesPaid);
      _loadClients();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${amountToPay.toStringAsFixed(2)} paid for ${client['name']}.')),
        );
      }
    }
  }

  Future<void> _generateClientReportPdf(Map<String, dynamic> client) async {
    try {
      final String caName =
          (await SharedPreferences.getInstance()).getString('caName') ?? 'N/A';
      final String caMobile =
          (await SharedPreferences.getInstance()).getString('caMobileNumber') ??
              'N/A';

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Client Report',
                  style: pw.TextStyle(
                      fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 20),
              pw.Text('Basic Details',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              _buildPdfText('Name', client['name']),
              _buildPdfText('PAN Number', client['panNumber']),
              _buildPdfText('Phone', client['phone']),
              _buildPdfText('Email', client['email']),
              _buildPdfText('Filing Status', client['filingStatus']),
              _buildPdfText(
                  'Filing Deadline', client['filingDeadline'] ?? 'N/A'),
              _buildPdfText('Notes', client['notes'] ?? 'N/A'),
              pw.SizedBox(height: 20),
              pw.Text('Financial Details',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Divider(),
              _buildPdfText('Fees Charged',
                  '${client['feesCharged']?.toStringAsFixed(2) ?? '0.00'}'),
              _buildPdfText('Fees Paid',
                  '${client['feesPaid']?.toStringAsFixed(2) ?? '0.00'}'),
              pw.SizedBox(height: 40),
              pw.Text('CA DETAILS',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
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
        ),
      );

      final String dir = (await getTemporaryDirectory()).path;
      final String fileName =
          '${client['name']}_report.pdf'.replaceAll(' ', '_');
      final File file = File('$dir/$fileName');
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generating report for ${client['name']}')),
        );
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
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
            width: 120,
            child: pw.Text(label,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }
}
