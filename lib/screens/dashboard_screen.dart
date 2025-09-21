import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';
import '../data_service.dart';
import 'package:intl/intl.dart';

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
                final urgencyCounts = <String, int>{};
                for (var issue in dataService.data) {
                  final urgency = (issue['urgency'] ?? 'Medium').toString();
                  urgencyCounts[urgency] =
                      (urgencyCounts[urgency] ?? 0) + ((issue['count'] ?? 0) as num).toInt();
                }

                String formatDate(DateTime? date) =>
                    date != null ? DateFormat('dd MMM yyyy').format(date) : '';

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Reports
                      Text(
                        'Total Reports : ${dataService.data.fold<int>(0, (sum, i) => sum + ((i['count'] ?? 0) as num).toInt())}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),

                      // RESET FILTERS BUTTON
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                          ),
                          onPressed: () {
                            setState(() {
                              dataService.selectedTypes = [];
                              dataService.selectedDepartments = [];
                              dataService.selectedUserIds = [];
                              dataService.selectedLocations = [];
                              dataService.startDate = null;
                              dataService.endDate = null;
                              dataService.applyFilters();
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Type Filter
                      _buildDropdownFilter(
                        title: 'Type',
                        options: dataService.data.map((e) => e['issue_type'] ?? '').toSet().toList().cast<String>(),
                        selectedItems: dataService.selectedTypes,
                        onChanged: (values) {
                          setState(() {
                            dataService.selectedTypes = values;
                            dataService.applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Department Filter
                      _buildDropdownFilter(
                        title: 'Department',
                        options: dataService.data.map((e) => e['department'] ?? '').toSet().toList().cast<String>(),
                        selectedItems: dataService.selectedDepartments,
                        onChanged: (values) {
                          setState(() {
                            dataService.selectedDepartments = values;
                            dataService.applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // User ID Filter
                      _buildDropdownFilter(
                        title: 'User ID',
                        options: dataService.data.map((e) => e['user_id'] ?? '').toSet().toList().cast<String>(),
                        selectedItems: dataService.selectedUserIds,
                        onChanged: (values) {
                          setState(() {
                            dataService.selectedUserIds = values;
                            dataService.applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Location Filter
                      _buildDropdownFilter(
                        title: 'Location',
                        options: dataService.data.map((e) => e['address'] ?? '').toSet().toList().cast<String>(),
                        selectedItems: dataService.selectedLocations,
                        onChanged: (values) {
                          setState(() {
                            dataService.selectedLocations = values;
                            dataService.applyFilters();
                          });
                        },
                      ),
                      const SizedBox(height: 12),

                      // Date Filter
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade900,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          final picked = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) {
                            setState(() {
                              dataService.startDate = picked.start;
                              dataService.endDate = picked.end;
                              dataService.applyFilters();
                            });
                          }
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          dataService.startDate != null && dataService.endDate != null
                              ? '${formatDate(dataService.startDate)} - ${formatDate(dataService.endDate)}'
                              : 'Filter by Date',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      _buildSidebarSection('Issues', Icons.assignment, [
                        'Critical (${urgencyCounts['Critical'] ?? 0})',
                        'High (${urgencyCounts['High'] ?? 0})',
                        'Medium (${urgencyCounts['Medium'] ?? 0})',
                        'Low (${urgencyCounts['Low'] ?? 0})',
                      ]),
                    ],
                  ),
                );
              },
            ),
          ),

          // Main content (issues list)
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

                final uniqueIssueCount = dataService.data.length;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'Clustered Issue Count : $uniqueIssueCount',
                        style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: dataService.data.length,
                        itemBuilder: (context, index) {
                          final issue = dataService.data[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 8, left: 12, right: 12),
                            elevation: 2,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: () {
                                  final urgency = (issue['urgency'] ?? '').toString().toLowerCase();
                                  if (urgency == 'critical') return Colors.purple;
                                  if (urgency == 'high') return Colors.red;
                                  if (urgency == 'medium') return Colors.orange;
                                  if (urgency == 'low') return Colors.green;
                                  return Colors.grey;
                                }(),
                                child: Text('${issue['count']}'),
                              ),
                              title: Text("${issue['issue_type']} (${issue['count']} reports)"),
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
                                  final dataService =
                                      Provider.of<DataService>(context, listen: false);
                                  setState(() {
                                    issue['status'] = newStatus;
                                  });
                                  await dataService.updateIssueStatus(
                                    List<String>.from(issue['ids']),
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
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownFilter({
  required String title,
  required List<String> options,
  required List<String> selectedItems,
  required Function(List<String>) onChanged,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      GestureDetector(
        onTap: () async {
          // Make a copy of the current selections **outside** the dialog builder
          List<String> tempSelected = List<String>.from(selectedItems);

          final result = await showDialog<List<String>>(
            context: context,
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setDialogState) {
                  return AlertDialog(
                    title: Text('Select $title'),
                    content: SizedBox(
                      width: double.maxFinite,
                      child: ListView(
                        shrinkWrap: true,
                        children: options.map((option) {
                          final isChecked = tempSelected.contains(option.trim());
                          return CheckboxListTile(
                            value: isChecked,
                            title: Text(option),
                            controlAffinity: ListTileControlAffinity.leading,
                            onChanged: (selected) {
                              setDialogState(() {
                                if (selected == true) {
                                  if (!tempSelected.contains(option)) tempSelected.add(option);
                                } else {
                                  tempSelected.remove(option);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, null),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, tempSelected),
                        child: const Text('OK'),
                      ),
                    ],
                  );
                },
              );
            },
          );

          if (result != null) {
            onChanged(result);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  selectedItems.isEmpty
                      ? 'Select $title'
                      : '${selectedItems.length} selected',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    ],
  );
}
}