import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'dart:io';
import '../database/database_helper.dart';
import '../pages/personal_details_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _enableNotifications = true;
  bool _darkMode = false;
  String _selectedLanguage = 'English';
  int _reminderDays = 7;
  bool _autoBackup = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _enableNotifications = prefs.getBool('enableNotifications') ?? true;
      _darkMode = prefs.getBool('darkMode') ?? false;
      _selectedLanguage = prefs.getString('language') ?? 'English';
      _reminderDays = prefs.getInt('reminderDays') ?? 7;
      _autoBackup = prefs.getBool('autoBackup') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableNotifications', _enableNotifications);
    await prefs.setBool('darkMode', _darkMode);
    await prefs.setString('language', _selectedLanguage);
    await prefs.setInt('reminderDays', _reminderDays);
    await prefs.setBool('autoBackup', _autoBackup);
  }

  Future<void> _exportDataToCsv() async {
    setState(() {
      // _isLoading = true; // If you want to show a loading indicator
    });
    try {
      final clients = await DatabaseHelper.instance.getAllClients();
      List<List<dynamic>> csvData = [];

      // Add headers
      if (clients.isNotEmpty) {
        csvData.add(clients.first.keys.toList());
      }

      // Add client data
      for (var client in clients) {
        csvData.add(client.values.toList());
      }

      String csv = const ListToCsvConverter().convert(csvData);

      final directory = await getApplicationDocumentsDirectory();
      final String timestamp =
          DateTime.now().toIso8601String().substring(0, 10);
      final path = '${directory.path}/clients_export_$timestamp.csv';
      final File file = File(path);
      await file.writeAsString(csv);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Data exported to: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export data: $e')),
        );
      }
    } finally {
      setState(() {
        // _isLoading = false; // If you used a loading indicator
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          _buildSection('Notifications', [
            SwitchListTile(
              title: const Text('Enable Notifications'),
              subtitle: const Text('Get reminders for upcoming deadlines'),
              value: _enableNotifications,
              onChanged: (value) {
                setState(() {
                  _enableNotifications = value;
                  _saveSettings();
                });
              },
            ),
            ListTile(
              title: const Text('Reminder Days'),
              subtitle: Text('Notify $_reminderDays days before deadline'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: () {
                      if (_reminderDays > 1) {
                        setState(() {
                          _reminderDays--;
                          _saveSettings();
                        });
                      }
                    },
                  ),
                  Text('$_reminderDays'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_reminderDays < 30) {
                        setState(() {
                          _reminderDays++;
                          _saveSettings();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),
          ]),
          _buildSection('Appearance', [
            SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: _darkMode,
              onChanged: (value) {
                setState(() {
                  _darkMode = value;
                  _saveSettings();
                });
              },
            ),
            ListTile(
              title: const Text('Language'),
              subtitle: Text(_selectedLanguage),
              trailing: DropdownButton<String>(
                value: _selectedLanguage,
                items: ['English', 'Hindi', 'Gujarati']
                    .map(
                      (lang) =>
                          DropdownMenuItem(value: lang, child: Text(lang)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedLanguage = value;
                      _saveSettings();
                    });
                  }
                },
              ),
            ),
          ]),
          _buildSection('Data Management', [
            SwitchListTile(
              title: const Text('Auto Backup'),
              subtitle: const Text('Automatically backup client data'),
              value: _autoBackup,
              onChanged: (value) {
                setState(() {
                  _autoBackup = value;
                  _saveSettings();
                });
              },
            ),
            ListTile(
              title: const Text('Export Data'),
              subtitle: const Text('Export client data to CSV'),
              trailing: const Icon(Icons.download),
              onTap: _exportDataToCsv,
            ),
            ListTile(
              title: const Text('Import Data'),
              subtitle: const Text('Import client data from CSV'),
              trailing: const Icon(Icons.upload),
              onTap: () {
                // TODO: Implement data import
              },
            ),
            ListTile(
              title: const Text('Clear All Data'),
              subtitle: const Text('Delete all client records'),
              trailing: const Icon(Icons.delete_forever, color: Colors.red),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear All Data'),
                    content: const Text(
                      'Are you sure you want to delete all client records? This action cannot be undone.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement data clearing
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Delete',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          _buildSection('About', [
            const ListTile(title: Text('Version'), subtitle: Text('1.0.0')),
            ListTile(
              title: const Text('Privacy Policy'),
              onTap: () {
                // TODO: Show privacy policy
              },
            ),
            ListTile(
              title: const Text('Terms of Service'),
              onTap: () {
                // TODO: Show terms of service
              },
            ),
            ListTile(
              title: const Text('Personal Details'),
              subtitle: const Text('Update your CA information'),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const PersonalDetailsPage(),
                  ),
                );
              },
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ),
        ...children,
        const Divider(),
      ],
    );
  }
}
