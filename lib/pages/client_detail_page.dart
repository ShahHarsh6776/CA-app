import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class ClientDetailPage extends StatefulWidget {
  final Map<String, dynamic> client;

  const ClientDetailPage({super.key, required this.client});

  @override
  State<ClientDetailPage> createState() => _ClientDetailPageState();
}

class _ClientDetailPageState extends State<ClientDetailPage> {
  late TextEditingController _nameController;
  late TextEditingController _panController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _deadlineController;
  late TextEditingController _notesController;
  late TextEditingController _feesChargedController;
  late TextEditingController _feesPaidController;
  late TextEditingController _assessmentYearController;
  late String _selectedStatus;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.client['name']);
    _panController = TextEditingController(text: widget.client['panNumber']);
    _phoneController = TextEditingController(text: widget.client['phone']);
    _emailController = TextEditingController(text: widget.client['email']);
    _deadlineController = TextEditingController(
      text: widget.client['filingDeadline'],
    );
    _notesController = TextEditingController(text: widget.client['notes']);
    _feesChargedController = TextEditingController(
        text: widget.client['feesCharged']?.toString() ?? '0.0');
    _feesPaidController = TextEditingController(
        text: widget.client['feesPaid']?.toString() ?? '0.0');
    _assessmentYearController = TextEditingController(
        text: widget.client['assessmentYear']?.toString() ??
            '${DateTime.now().year}-${DateTime.now().year + 1}');
    _selectedStatus = widget.client['filingStatus'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _panController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _deadlineController.dispose();
    _notesController.dispose();
    _feesChargedController.dispose();
    _feesPaidController.dispose();
    _assessmentYearController.dispose();
    super.dispose();
  }

  Future<void> _updateClient() async {
    final updatedClient = {
      'id': widget.client['id'],
      'name': _nameController.text,
      'panNumber': _panController.text,
      'phone': _phoneController.text,
      'email': _emailController.text,
      'filingDeadline': _deadlineController.text,
      'filingStatus': _selectedStatus,
      'notes': _notesController.text,
      'feesCharged': double.tryParse(_feesChargedController.text) ?? 0.0,
      'feesPaid': double.tryParse(_feesPaidController.text) ?? 0.0,
      'assessmentYear': _assessmentYearController.text,
    };

    await DatabaseHelper.instance.updateClient(updatedClient);
    setState(() {
      _isEditing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.client['name']),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _updateClient();
              } else {
                setState(() {
                  _isEditing = true;
                });
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard('Basic Information', [
              _buildInfoField('Name', _nameController, _isEditing),
              _buildInfoField('PAN Number', _panController, _isEditing),
              _buildInfoField('Phone', _phoneController, _isEditing),
              _buildInfoField('Email', _emailController, _isEditing),
            ]),
            const SizedBox(height: 16),
            _buildInfoCard('Filing Information', [
              _buildInfoField(
                'Filing Deadline',
                _deadlineController,
                _isEditing,
              ),
              _buildStatusDropdown(),
              _buildInfoField(
                'Notes',
                _notesController,
                _isEditing,
                maxLines: 3,
              ),
              _buildInfoField(
                'Assessment Year',
                _assessmentYearController,
                _isEditing,
              ),
            ]),
            const SizedBox(height: 16),
            _buildInfoCard('Financial Information', [
              _buildInfoField(
                'Fees Charged',
                _feesChargedController,
                _isEditing,
                keyboardType: TextInputType.number,
              ),
              _buildInfoField(
                'Fees Paid',
                _feesPaidController,
                _isEditing,
                keyboardType: TextInputType.number,
              ),
            ]),
            const SizedBox(height: 16),
            _buildInfoCard('Filing History', [
              ListTile(
                title: const Text('Last Filing Date'),
                subtitle: Text(
                  widget.client['lastFilingDate'] ?? 'No previous filing',
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoField(
    String label,
    TextEditingController controller,
    bool isEditing, {
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: isEditing
          ? TextFormField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                border: const OutlineInputBorder(),
              ),
              keyboardType: keyboardType,
              maxLines: maxLines,
            )
          : ListTile(
              title: Text(label),
              subtitle: Text(
                controller.text.isEmpty ? 'Not specified' : controller.text,
              ),
            ),
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _isEditing
          ? DropdownButtonFormField<String>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filing Status',
                border: OutlineInputBorder(),
              ),
              items: ['Pending', 'In Progress', 'Completed']
                  .map(
                    (status) =>
                        DropdownMenuItem(value: status, child: Text(status)),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value!;
                });
              },
            )
          : ListTile(
              title: const Text('Filing Status'),
              subtitle: Text(_selectedStatus),
            ),
    );
  }
}
