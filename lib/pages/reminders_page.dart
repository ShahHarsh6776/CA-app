import 'package:flutter/material.dart';
import '../database/database_helper.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<Map<String, dynamic>> _upcomingDeadlines = [];
  List<Map<String, dynamic>> _overdueDeadlines = [];

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    final clients = await DatabaseHelper.instance.getAllClients();
    final now = DateTime.now();

    setState(() {
      _upcomingDeadlines = clients.where((client) {
        if (client['filingDeadline'] == null) return false;
        final deadline = DateTime.parse(client['filingDeadline']);
        return deadline.isAfter(now) && client['filingStatus'] != 'Completed';
      }).toList();

      _overdueDeadlines = clients.where((client) {
        if (client['filingDeadline'] == null) return false;
        final deadline = DateTime.parse(client['filingDeadline']);
        return deadline.isBefore(now) && client['filingStatus'] != 'Completed';
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_overdueDeadlines.isNotEmpty) ...[
              const Text(
                'Overdue Deadlines',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              _buildDeadlineList(_overdueDeadlines, true),
              const SizedBox(height: 24),
            ],
            const Text(
              'Upcoming Deadlines',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildDeadlineList(_upcomingDeadlines, false),
          ],
        ),
      ),
    );
  }

  Widget _buildDeadlineList(
    List<Map<String, dynamic>> deadlines,
    bool isOverdue,
  ) {
    if (deadlines.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            isOverdue ? 'No overdue deadlines' : 'No upcoming deadlines',
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: deadlines.length,
      itemBuilder: (context, index) {
        final client = deadlines[index];
        final deadline = DateTime.parse(client['filingDeadline']);
        final daysLeft = deadline.difference(DateTime.now()).inDays;

        return Card(
          color: isOverdue ? Colors.red.shade50 : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isOverdue ? Colors.red : Colors.orange,
              child: Text(
                client['name'][0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Text(client['name']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('PAN: ${client['panNumber']}'),
                Text(
                  isOverdue
                      ? 'Overdue by ${-daysLeft} days'
                      : 'Due in $daysLeft days',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                // TODO: Implement reminder notification
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reminder set for this deadline'),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
