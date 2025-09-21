import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../auth_service.dart';
import '../data_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String selectedSort = 'Latest';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<DataService>(context, listen: false).fetchData();
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
            builder: (_, auth, __) => IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Sign Out',
              onPressed: () async => await auth.signOut(),
            ),
          ),
        ],
      ),
      body: Consumer<DataService>(
        builder: (_, ds, __) {
          if (ds.isLoading) return const Center(child: CircularProgressIndicator());
          if (ds.error != null) return Center(child: Text('Error: ${ds.error}'));
          if (ds.data.isEmpty) return const Center(child: Text('No issues found'));

          // Sidebar counts
          final urgencyCounts = <String, int>{};
          int totalReports = 0;
          for (final issue in ds.data) {
            final u = (issue['urgency'] ?? 'Medium').toString();
            urgencyCounts[u] = (urgencyCounts[u] ?? 0) + (issue['count'] as int);
            totalReports += (issue['count'] as int);
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Sidebar =====
                Container(
                  width: 180,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 2))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCountCard('Report Count', totalReports, Colors.blue.shade100),
                      const SizedBox(height: 16),
                      const Text('Urgency Levels', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      ...['Critical', 'High', 'Medium', 'Low'].map((lvl) {
                        return Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: _urgencyColor(lvl),
                                child: Text(
                                  (urgencyCounts[lvl] ?? 0).toString(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Flexible(child: Text(lvl, style: const TextStyle(fontSize: 14))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(width: 16),

                // ===== Main Content =====
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: cluster count + refresh + sort + filter
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Clustered Issue Count: ${ds.data.length}',
                              style: const TextStyle(fontSize: 20, fontStyle: FontStyle.italic),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.refresh, color: Colors.blue),
                            tooltip: 'Refresh Data',
                            onPressed: () async {
                              await Provider.of<DataService>(context, listen: false).fetchData();
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              setState(() => selectedSort = value);
                              _sortData(ds, value);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'Latest', child: Text('Latest')),
                              PopupMenuItem(value: 'Oldest', child: Text('Oldest')),
                              PopupMenuItem(value: 'Priority', child: Text('Priority')),
                              PopupMenuItem(value: 'Priority Descending', child: Text('Priority Descending')),
                              PopupMenuItem(value: 'Priority Ascending', child: Text('Priority Ascending')),
                            ],
                            child: Row(
                              children: [
                                const Icon(Icons.sort, color: Colors.blue),
                                const SizedBox(width: 4),
                                Text(selectedSort, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                                const SizedBox(width: 12),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.filter_list),
                            label: const Text('Filters'),
                            onPressed: () => _openFilterDialog(context, ds),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ===== Issue List =====
                      Expanded(
                        child: ListView.builder(
                          itemCount: ds.data.length,
                          itemBuilder: (_, i) {
                            final issue = ds.data[i];
                            final priorityScore = _calculatePriorityScore(issue);

                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor: _urgencyColor(issue['urgency']),
                                          child: Text('${issue['count']}'),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 40,
                                          height: 6,
                                          child: LinearProgressIndicator(
                                            value: priorityScore / 100,
                                            backgroundColor: Colors.grey.shade300,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${issue['issue_type']} (${issue['count']} reports)",
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          _issueDetailsWidget(issue),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        DropdownButton<String>(
                                          value: issue['status'],
                                          underline: const SizedBox(),
                                          items: const [
                                            DropdownMenuItem(value: 'Reported', child: Text('Reported')),
                                            DropdownMenuItem(value: 'Assigned', child: Text('Assigned')),
                                            DropdownMenuItem(value: 'In Progress', child: Text('In Progress')),
                                            DropdownMenuItem(value: 'Resolved', child: Text('Resolved')),
                                          ],
                                          onChanged: (val) async {
                                            if (val == null) return;
                                            setState(() => issue['status'] = val);
                                            await Provider.of<DataService>(context, listen: false)
                                                .updateIssueStatus(List<String>.from(issue['ids']), val);
                                          },
                                        ),
                                        const SizedBox(height: 4),
                                        // 🔴 Dynamic Aging Priority %
                                        Text(
                                          '${priorityScore.toStringAsFixed(2)}%',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.redAccent),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ===== Helpers =====

  double _calculatePriorityScore(Map<String, dynamic> issue) {
    final baseScores = {'low': 10.0, 'medium': 15.0, 'high': 25.0, 'critical': 40.0};
    final urgency = (issue['urgency'] ?? 'medium').toString().toLowerCase();
    double score = baseScores[urgency] ?? 15.0;

    // Age factor
    try {
      final reported = DateTime.tryParse(issue['reported_date'] ?? '');
      if (reported != null) {
        final daysOld = DateTime.now().difference(reported).inDays;
        double ageFactor = (daysOld / 7) * 2.5; // 2.5% per week
        if (ageFactor > 30) ageFactor = 30;
        score += ageFactor;
      }
    } catch (_) {}

    // Status factor
    if ((issue['status'] ?? '').toString().toLowerCase() == 'reported') score += 10.0;

    // Dynamic report count factor (1–5%)
    final count = (issue['count'] as int?) ?? 1;
    final reportFactorPercent = (min(count, 50) / 50) * 5;
    score += score * (reportFactorPercent / 100);

    // Clamp
    return score.clamp(0, 100);
  }

  void _sortData(DataService ds, String value) {
    if (value == 'Priority Descending') {
      ds.data.sort((a, b) => _calculatePriorityScore(b).compareTo(_calculatePriorityScore(a)));
    } else if (value == 'Priority Ascending') {
      ds.data.sort((a, b) => _calculatePriorityScore(a).compareTo(_calculatePriorityScore(b)));
    } else if (value == 'Priority') {
      ds.data.sort((a, b) {
        const baseScores = {'low': 10, 'medium': 15, 'high': 25, 'critical': 40};
        final aScore = baseScores[(a['urgency'] ?? 'medium').toString().toLowerCase()] ?? 0;
        final bScore = baseScores[(b['urgency'] ?? 'medium').toString().toLowerCase()] ?? 0;
        return bScore.compareTo(aScore);
      });
    } else if (value == 'Latest') {
      ds.data.sort((a, b) {
        final da = DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime.now();
        final db = DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime.now();
        return db.compareTo(da);
      });
    } else if (value == 'Oldest') {
      ds.data.sort((a, b) {
        final da = DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime.now();
        final db = DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime.now();
        return da.compareTo(db);
      });
    }
  }

  Widget _issueDetailsWidget(Map<String, dynamic> issue) {
    final reported = DateTime.tryParse(issue['reported_date'] ?? '');
    final dateStr = reported != null ? DateFormat('dd MMM yyyy').format(reported) : '';
    final timeStr = reported != null ? DateFormat('hh:mm a').format(reported) : '';
    final lat = issue['latitude'] ?? '';
    final lng = issue['longitude'] ?? '';
    final description = issue['description'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(child: Text("${issue['address']} (Lat: $lat, Lng: $lng)", style: const TextStyle(fontSize: 14))),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(dateStr, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 12),
            const Icon(Icons.access_time, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(timeStr, style: const TextStyle(fontSize: 14)),
            if (description.isNotEmpty) ...[
              const SizedBox(width: 12),
              const Icon(Icons.description, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Expanded(child: Text(description, style: const TextStyle(fontSize: 14))),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildCountCard(String title, int count, Color bgColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Text(
        '$title: $count',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }

  Color _urgencyColor(String? u) {
    switch ((u ?? '').toLowerCase()) {
      case 'critical':
        return Colors.purple;
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _openFilterDialog(BuildContext context, DataService ds) async {
    String fmt(DateTime? d) => d != null ? DateFormat('dd MMM yyyy').format(d) : '';
    List<String> types = List.from(ds.selectedTypes);
    List<String> depts = List.from(ds.selectedDepartments);
    List<String> users = List.from(ds.selectedUserIds);
    List<String> locs = List.from(ds.selectedLocations);
    List<String> urgencies = List.from(ds.selectedUrgencies);
    DateTime? start = ds.startDate;
    DateTime? end = ds.endDate;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, setDialog) => AlertDialog(
          title: const Text('Filters'),
          content: SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _multiSelect('Type', ds.allTypes, types, (v) => setDialog(() => types = v)),
                  _multiSelect('Department', ds.allDepartments, depts, (v) => setDialog(() => depts = v)),
                  _multiSelect('User ID', ds.allUsers, users, (v) => setDialog(() => users = v)),
                  _multiSelect('Location', ds.allLocations, locs, (v) => setDialog(() => locs = v)),
                  _multiSelect('Urgency', ['Critical','High','Medium','Low'], urgencies, (v) => setDialog(() => urgencies = v)),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.date_range),
                    label: Text(start != null && end != null ? '${fmt(start)} - ${fmt(end)}' : 'Filter by Date'),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2000),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                        initialDateRange: start != null && end != null ? DateTimeRange(start: start!, end: end!) : null,
                      );
                      if (picked != null) setDialog(() { start = picked.start; end = picked.end; });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setDialog(() {
                  types.clear();
                  depts.clear();
                  users.clear();
                  locs.clear();
                  urgencies.clear();
                  start = null;
                  end = null;
                });
                setState(() => ds.resetFilters());
              },
              child: const Text('Reset Filters', style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => ds.updateFilters(types, depts, users, locs, start, end, urgencies));
                Navigator.pop(context);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _multiSelect(String title, List<String> opts, List<String> selected, void Function(List<String>) onChange) {
    return ExpansionTile(
      title: Text('$title (${selected.length})'),
      children: opts.map((o) {
        final checked = selected.contains(o);
        return CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(o),
          value: checked,
          onChanged: (v) {
            if (v == true) selected.add(o); else selected.remove(o);
            onChange(List.from(selected));
          },
        );
      }).toList(),
    );
  }
}
