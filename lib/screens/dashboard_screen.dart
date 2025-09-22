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
  String sortType = "Priority";
  int agingDays = 0;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final dataService = Provider.of<DataService>(context, listen: false);
      dataService.fetchData().then((_) {
        dataService.sortData("Priority");
      });
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
          if (ds.isLoading)
            return const Center(child: CircularProgressIndicator());
          if (ds.error != null)
            return Center(child: Text('Error: ${ds.error}'));
          if (ds.data.isEmpty)
            return const Center(child: Text('No issues found'));

          int clusteredCount = ds.data
              .where((issue) => (issue['isClustered'] ?? false))
              .fold<int>(0, (sum, i) => sum + (i['count'] as int));

          int resolvedCount = ds.data
              .where((i) =>
                  (i['status'] ?? '').toString().toLowerCase() == 'resolved')
              .fold<int>(0, (sum, i) => sum + (i['count'] as int));

          int totalReports =
              ds.data.fold<int>(0, (sum, i) => sum + (i['count'] as int));

          final urgencyCounts = <String, int>{};
          for (final issue in ds.data) {
            final u = (issue['urgency'] ?? 'Medium').toString();
            urgencyCounts[u] =
                (urgencyCounts[u] ?? 0) + (issue['count'] as int);
          }

          final now = DateTime.now();
          final filteredIssues = ds.data.where((issue) {
            if (agingDays != 0) {
              final reported = DateTime.tryParse(issue['reported_date'] ?? '');
              if (reported == null ||
                  now.difference(reported).inDays > agingDays) return false;
            }
            if (searchQuery.isNotEmpty) {
              final q = searchQuery.toLowerCase();
              final type = (issue['issue_type'] ?? '').toString().toLowerCase();
              final addr = (issue['address'] ?? '').toString().toLowerCase();
              if (!type.contains(q) && !addr.contains(q)) return false;
            }
            return true;
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== Sidebar =====
                Container(
                  width: 250,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 6,
                          offset: Offset(2, 2))
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          decoration: const InputDecoration(
                            hintText: 'Search issues...',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (val) =>
                              setState(() => searchQuery = val),
                        ),
                        const SizedBox(height: 12),
                        _buildCountCard(
                            'Report Count', totalReports, Colors.blue.shade100),
                        // _buildCountCard(
                        //     'Clustered Issues', clusteredCount, Colors.orange.shade100),
                        _buildCountCard(
                            'Resolved Issues', resolvedCount, Colors.green.shade100),
                        const SizedBox(height: 16),
                        const Text('Urgency Levels',
                            style: TextStyle(fontWeight: FontWeight.bold)),
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
                                    style: const TextStyle(
                                        color: Colors.white, fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(lvl,
                                        style: const TextStyle(fontSize: 14))),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // ===== Main Content =====
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 6,
                                  offset: Offset(2, 2))
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // ===== Heatmap with Y-axis label =====
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: LayoutBuilder(
                                        builder: (_, constraints) {
                                          final width = constraints.maxWidth;
                                          final height = constraints.maxHeight;

                                          final lats = ds.data
                                              .map((e) =>
                                                  e['latitude'] as double? ?? 0)
                                              .toList();
                                          final lngs = ds.data
                                              .map((e) =>
                                                  e['longitude'] as double? ?? 0)
                                              .toList();
                                          final minLat =
                                              lats.isNotEmpty ? lats.reduce(min) : 0;
                                          final maxLat =
                                              lats.isNotEmpty ? lats.reduce(max) : 1;
                                          final minLng =
                                              lngs.isNotEmpty ? lngs.reduce(min) : 0;
                                          final maxLng =
                                              lngs.isNotEmpty ? lngs.reduce(max) : 1;

                                          return Stack(
                                            children: ds.data.map((issue) {
                                              final lat =
                                                  issue['latitude'] as double? ?? 0;
                                              final lng =
                                                  issue['longitude'] as double? ?? 0;

                                              final dx = maxLng - minLng != 0
                                                  ? ((lng - minLng) / (maxLng - minLng)) *
                                                      width
                                                  : width / 2;
                                              final dy = maxLat - minLat != 0
                                                  ? height -
                                                      ((lat - minLat) /
                                                              (maxLat - minLat)) *
                                                          height
                                                  : height / 2;

                                              return Positioned(
                                                left: dx - 8,
                                                top: dy - 16,
                                                child: const Icon(
                                                    Icons.location_on,
                                                    color: Colors.red,
                                                    size: 16),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Longitude',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),

                              // ===== Vertical Divider =====
                              Container(
                                width: 1,
                                color: Colors.grey.shade400,
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                              ),

                              // ===== Bar chart with Y-axis label =====
                              Expanded(
                                flex: 1,
                                child: Column(
                                  children: [
                                    const Text('Urgency Count',
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 8, horizontal: 8),
                                        child: _buildUrgencyChart(ds, small: false),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ===== Issue List =====
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredIssues.length,
                          itemBuilder: (_, i) {
                            final issue = filteredIssues[i];
                            final priorityScore =
                                _calculatePriorityScore(issue);
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 6),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          backgroundColor:
                                              _urgencyColor(issue['urgency']),
                                          child: Text('${issue['count']}'),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          width: 40,
                                          height: 6,
                                          child: LinearProgressIndicator(
                                            value: priorityScore / 100,
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            color: Colors.redAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${issue['issue_type']} (${issue['count']} reports)",
                                            style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600),
                                          ),
                                          const SizedBox(height: 4),
                                          _issueDetailsWidget(issue),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        DropdownButton<String>(
                                          value: issue['status'],
                                          underline: const SizedBox(),
                                          items: const [
                                            DropdownMenuItem(
                                                value: 'Reported',
                                                child: Text('Reported')),
                                            DropdownMenuItem(
                                                value: 'Assigned',
                                                child: Text('Assigned')),
                                            DropdownMenuItem(
                                                value: 'In Progress',
                                                child: Text('In Progress')),
                                            DropdownMenuItem(
                                                value: 'Resolved',
                                                child: Text('Resolved')),
                                          ],
                                          onChanged: (val) async {
                                            if (val == null) return;
                                            setState(
                                                () => issue['status'] = val);
                                            await Provider.of<DataService>(
                                                    context,
                                                    listen: false)
                                                .updateIssueStatus(
                                                    List<String>.from(
                                                        issue['ids']),
                                                    val);
                                          },
                                        ),
                                        const SizedBox(height: 4),
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
    final baseScores = {
      'low': 10.0,
      'medium': 15.0,
      'high': 25.0,
      'critical': 40.0
    };
    final urgency = (issue['urgency'] ?? 'medium').toString().toLowerCase();
    double score = baseScores[urgency] ?? 15.0;
    try {
      final reported = DateTime.tryParse(issue['reported_date'] ?? '');
      if (reported != null) {
        final daysOld = DateTime.now().difference(reported).inDays;
        double ageFactor = (daysOld / 7) * 2.5;
        if (ageFactor > 30) ageFactor = 30;
        score += ageFactor;
      }
    } catch (_) {}
    if ((issue['status'] ?? '').toString().toLowerCase() == 'reported')
      score += 10.0;
    final count = (issue['count'] as int?) ?? 1;
    final reportFactorPercent = (min(count, 50) / 50) * 5;
    score += score * (reportFactorPercent / 100);
    return score.clamp(0, 100);
  }

  Widget _issueDetailsWidget(Map<String, dynamic> issue) {
    final reported = DateTime.tryParse(issue['reported_date'] ?? '');
    final dateStr =
        reported != null ? DateFormat('dd MMM yyyy').format(reported) : '';
    final timeStr =
        reported != null ? DateFormat('hh:mm a').format(reported) : '';
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
            Expanded(
                child: Text("${issue['address']} (Lat: $lat, Lng: $lng)",
                    style: const TextStyle(fontSize: 14))),
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
              Expanded(
                  child:
                      Text(description, style: const TextStyle(fontSize: 14))),
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
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
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

  Widget _buildUrgencyChart(DataService ds, {bool small = false}) {
    final urgencies = ['Critical', 'High', 'Medium', 'Low'];
    final counts = urgencies.map((u) {
      return ds.data
          .where((i) => (i['urgency'] ?? '').toLowerCase() == u.toLowerCase())
          .fold<int>(0, (sum, i) => sum + (i['count'] as int));
    }).toList();
    final maxCount = counts.isNotEmpty ? counts.reduce(max) : 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(4, (i) {
        final barHeight = (counts[i] / maxCount) * (small ? 100 : 150);
        final barWidth = small ? 20.0 : 30.0;

        return Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('${counts[i]}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            const SizedBox(height: 4),
            Container(width: barWidth, height: barHeight, color: _urgencyColor(urgencies[i])),
            const SizedBox(height: 4),
            Text(urgencies[i], style: TextStyle(fontSize: small ? 10 : 12)),
          ],
        );
      }),
    );
  }
}
