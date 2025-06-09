import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import 'client_list_page.dart';
import 'reminders_page.dart';
import 'reports_page.dart';
import 'add_client_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  int _totalClients = 0;
  int _pendingFiling = 0;
  int _completedFiling = 0;
  int _upcomingDeadlines = 0;
  List<Map<String, dynamic>> _recentActivities = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    _loadDashboardData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    final clients = await DatabaseHelper.instance.getAllClients();
    final recentFilingHistory =
        await DatabaseHelper.instance.getRecentFilingHistory();
    final now = DateTime.now();

    final List<Map<String, dynamic>> activitiesWithClientNames = [];
    for (var activity in recentFilingHistory) {
      final clientName =
          await DatabaseHelper.instance.getClientNameById(activity['clientId']);
      activitiesWithClientNames.add({
        ...activity,
        'clientName': clientName,
      });
    }

    setState(() {
      _totalClients = clients.length;
      _pendingFiling =
          clients.where((c) => c['filingStatus'] == 'Pending').length;
      _completedFiling =
          clients.where((c) => c['filingStatus'] == 'Completed').length;
      _upcomingDeadlines = clients.where((client) {
        if (client['filingDeadline'] == null) return false;
        final deadline = DateTime.parse(client['filingDeadline']);
        return deadline.isAfter(now) && client['filingStatus'] != 'Completed';
      }).length;
      _recentActivities = activitiesWithClientNames;
      _isLoading = false;
    });

    _animationController.forward();
  }

  Future<void> _navigateToAddClient() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddClientPage()),
    );
    if (result == true) {
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadDashboardData,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildSummaryCard(
                      'Total Clients',
                      _totalClients.toString(),
                      Icons.people,
                      Colors.blue,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClientListPage(),
                          ),
                        );
                      },
                    ),
                    _buildSummaryCard(
                      'Pending Filing',
                      _pendingFiling.toString(),
                      Icons.pending_actions,
                      Colors.orange,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ClientListPage(),
                          ),
                        );
                      },
                    ),
                    _buildSummaryCard(
                      'Completed Filing',
                      _completedFiling.toString(),
                      Icons.check_circle,
                      Colors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsPage(),
                          ),
                        );
                      },
                    ),
                    _buildSummaryCard(
                      'Upcoming Deadlines',
                      _upcomingDeadlines.toString(),
                      Icons.calendar_today,
                      Colors.red,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RemindersPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              const SizedBox(height: 20),
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: _buildActionButton(
                      'Add Client',
                      Icons.person_add,
                      _navigateToAddClient,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      'View Reports',
                      Icons.bar_chart,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ReportsPage(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      'Set Reminder',
                      Icons.notifications,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const RemindersPage(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildRecentActivitySection(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 2),
              Flexible(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String title,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(
            title,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Activity',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (_recentActivities.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No recent activity.'),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: _recentActivities.map((activity) {
                  final clientId = activity['clientId'];
                  final clientName = activity['clientName'] ??
                      'Unknown Client'; // You might need to fetch client name
                  final filingType = activity['filingType'];
                  final filingDate = DateTime.parse(activity['filingDate']);
                  final status = activity['status'];
                  final timeAgo = _getTimeAgo(filingDate);

                  IconData icon;
                  Color iconColor;

                  if (status == 'Completed') {
                    icon = Icons.check_circle;
                    iconColor = Colors.green;
                  } else if (status == 'Pending') {
                    icon = Icons.pending_actions;
                    iconColor = Colors.orange;
                  } else {
                    icon = Icons.info;
                    iconColor = Colors.blue;
                  }

                  return Column(
                    children: [
                      _buildActivityItem(
                        icon,
                        '$filingType Filing',
                        '$clientName - Status: $status',
                        timeAgo,
                      ),
                      const Divider(),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildActivityItem(
    IconData icon,
    String title,
    String subtitle,
    String time,
  ) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Text(
        time,
        style: const TextStyle(color: Colors.grey),
      ),
    );
  }

  String _getTimeAgo(DateTime date) {
    final Duration diff = DateTime.now().difference(date);
    if (diff.inDays > 365) {
      return '${(diff.inDays / 365).floor()} years ago';
    } else if (diff.inDays > 30) {
      return '${(diff.inDays / 30).floor()} months ago';
    } else if (diff.inDays > 7) {
      return '${(diff.inDays / 7).floor()} weeks ago';
    } else if (diff.inDays > 0) {
      return '${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hours ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}
