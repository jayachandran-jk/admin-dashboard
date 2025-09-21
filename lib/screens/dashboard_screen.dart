import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../data_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final dataService = Provider.of<DataService>(context, listen: false);
      dataService.fetchData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          Consumer<AuthService>(
            builder: (context, authService, child) {
              return IconButton(
                onPressed: () async => await authService.signOut(),
                icon: const Icon(Icons.logout),
                tooltip: 'Sign Out',
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 300,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: const Border(right: BorderSide(color: Colors.grey, width: 1)),
            ),
            child: Consumer<DataService>(
              builder: (context, dataService, child) {
                // Count issues by urgency
                final urgencyCounts = <String, int>{};
                for (var issue in dataService.data) {
                  final urgency = (issue['urgency'] ?? 'Medium').toString();
                  urgencyCounts[urgency] =
                      (urgencyCounts[urgency] ?? 0) + ((issue['count'] ?? 0) as num).toInt();
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Total Reports : ${dataService.data.fold<int>(0, (sum, i) => sum + ((i['count'] ?? 0) as num).toInt())}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildSidebarSection('Issues', Icons.assignment, [
                      'Critical (${urgencyCounts['Critical'] ?? 0})',
                      'High (${urgencyCounts['High'] ?? 0})',
                      'Medium (${urgencyCounts['Medium'] ?? 0})',
                      'Low (${urgencyCounts['Low'] ?? 0})',
                    ]),
                    _buildSidebarSection('Analytics', Icons.analytics, [
                      'Response Time',
                      'Resolution Rate',
                      'Satisfaction'
                    ]),
                    _buildSidebarSection('Insights', Icons.lightbulb, [
                      'Peak Hours',
                      'Common Issue',
                      'Hotspot'
                    ]),
                    _buildSidebarSection('Predictions', Icons.trending_up, [
                      'Next Week',
                      'Risk Areas'
                    ]),
                    _buildSidebarSection('Officers', Icons.people, [
                      'John Smith',
                      'Sarah Johnson'
                    ]),
                  ],
                );
              },
            ),
          ),

          // Main content
          Expanded(
            child: Consumer<DataService>(
              builder: (context, dataService, child) {
                if (dataService.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (dataService.error != null) {
                  return Center(child: Text('Error: ${dataService.error}'));
                }
                if (dataService.data.isEmpty) {
                  return const Center(child: Text('No issues found'));
                }

                // Total clustered issues
                final clusteredIssuesCount = dataService.data.fold<int>(
                  0,
                  (sum, issue) => sum + ((issue['count'] ?? 0) as num).toInt(),
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Clustered Issue Count : $uniqueIssueCount',
                        style: const TextStyle(
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: dataService.data.length,
                        itemBuilder: (context, index) {
                          final issue = dataService.data[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: () {
                                  final urgency =
                                      (issue['urgency'] ?? '').toString().toLowerCase();
                                  if (urgency == 'critical') return Colors.purple;
                                  if (urgency == 'high') return Colors.red;
                                  if (urgency == 'medium') return Colors.orange;
                                  if (urgency == 'low') return Colors.green;
                                  return Colors.grey;
                                }(),
                                child: Text('${issue['count']}'),
                              ),
                              title: Text(
                                "${issue['issue_type']} (${issue['count']} reports)",
                              ),
                              subtitle: Text(
                                "Address: ${issue['address'] ?? 'N/A'}\n"
                                "Latitude: ${issue['latitude']}, Longitude: ${issue['longitude']}\n"
                                "${issue['description'] ?? ''}",
                              ),
                              trailing: DropdownButton<String>(
  value: issue['status'],
  underline: const SizedBox(),
  items: const [
    DropdownMenuItem(value: 'Reported', child: Text('Reported')),
    DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
    DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
    DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
  ],
  onChanged: (newStatus) async {
    if (newStatus == null) return;
    final dataService = Provider.of<DataService>(context, listen: false);

    // Optimistic UI update
    setState(() {
      issue['status'] = newStatus;
    });

    await dataService.updateIssueStatus(
      List<String>.from(issue['ids']), // full paths stored here
      newStatus,
    );
  },
),

                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarSection(String title, IconData icon, List<String> items) {
    return Container(
      margin: const EdgeInsets.all(8),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const Divider(height: 1),
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.grey),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item, style: const TextStyle(fontSize: 12))),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
