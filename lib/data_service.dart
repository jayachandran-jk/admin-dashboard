import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _error;

  // Filters
  List<String> selectedTypes = [];
  List<String> selectedDepartments = [];
  List<String> selectedUserIds = [];
  List<String> selectedLocations = [];
  List<String> selectedUrgencies = [];
  DateTime? startDate;
  DateTime? endDate;

  // Convenience getters
  List<Map<String, dynamic>> get data => _data;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Unique values for filter lists
  List<String> get allTypes => _unique('issue_type');
  List<String> get allDepartments => _unique('department');
  List<String> get allUsers => _unique('user_id');
  List<String> get allLocations => _unique('address');

  // ------------------- Fetch data (always fresh) -------------------
  Future<void> fetchData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final snap = await _firestore.collectionGroup('issues').get();

      final List<Map<String, dynamic>> allIssues = snap.docs.map((doc) {
        final d = doc.data();
        return {
          'id': doc.reference.path,
          'issue_type': d['issue_type'] ?? 'Unknown',
          'latitude': double.tryParse(d['latitude']?.toString() ?? '') ?? 0.0,
          'longitude': double.tryParse(d['longitude']?.toString() ?? '') ?? 0.0,
          'address': d['address'] ?? '',
          'description': d['description'] ?? '',
          'status': d['status'] ?? 'Reported',
          'urgency': d['urgency'] ?? 'Medium',
          'reported_date': d['reported_date'] ?? '',
          'user_id': d['user_id'] ?? '',
          'department': d['department'] ?? '',
        };
      }).toList();

      // ---------------- Clustering ----------------
      const double proximityThresholdMeters = 50; // cluster if within 50m
      List<Map<String, dynamic>> clusters = [];

      for (var issue in allIssues) {
        bool added = false;

        for (var cluster in clusters) {
          if (cluster['issue_type'] == issue['issue_type'] &&
              _distanceMeters(cluster['latitude'], cluster['longitude'],
                      issue['latitude'], issue['longitude']) <=
                  proximityThresholdMeters) {
            cluster['count'] += 1;
            cluster['ids'].add(issue['id']);
            added = true;
            break;
          }
        }

        if (!added) {
          clusters.add({
            'issue_type': issue['issue_type'],
            'latitude': issue['latitude'],
            'longitude': issue['longitude'],
            'address': issue['address'],
            'description': issue['description'],
            'status': issue['status'],
            'urgency': issue['urgency'],
            'reported_date': issue['reported_date'],
            'user_id': issue['user_id'],
            'department': issue['department'],
            'count': 1,
            'ids': [issue['id']],
          });
        }
      }

      _data = clusters;
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  // ------------------- Update issue status -------------------
  Future<void> updateIssueStatus(List<String> docPaths, String newStatus) async {
    try {
      final batch = _firestore.batch();
      for (final path in docPaths) {
        batch.update(_firestore.doc(path), {'status': newStatus});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Status update failed: $e');
    }

    // Refresh data after status update
    await fetchData();
  }

  // ------------------- Filters -------------------
  List<Map<String, dynamic>> applyFilters() {
    final filtered = _data.where((issue) {
      final t = selectedTypes.isEmpty || selectedTypes.contains(issue['issue_type']);
      final d = selectedDepartments.isEmpty || selectedDepartments.contains(issue['department']);
      final u = selectedUserIds.isEmpty || selectedUserIds.contains(issue['user_id']);
      final l = selectedLocations.isEmpty ||
          selectedLocations.any((loc) =>
              (issue['address'] as String).toLowerCase().contains(loc.toLowerCase()));
      final urg = selectedUrgencies.isEmpty || selectedUrgencies.contains(issue['urgency']);
      bool dateOK = true;
      if (startDate != null || endDate != null) {
        try {
          final issueDate = DateTime.tryParse(issue['reported_date'] ?? '');
          if (issueDate == null) return false;
          if (startDate != null && issueDate.isBefore(startDate!)) dateOK = false;
          if (endDate != null && issueDate.isAfter(endDate!)) dateOK = false;
        } catch (_) {
          dateOK = false;
        }
      }
      return t && d && u && l && urg && dateOK;
    }).toList();
    return filtered;
  }

  void updateFilters(
    List<String> types,
    List<String> depts,
    List<String> users,
    List<String> locs,
    DateTime? start,
    DateTime? end,
    List<String> urgencies,
  ) {
    selectedTypes = types;
    selectedDepartments = depts;
    selectedUserIds = users;
    selectedLocations = locs;
    selectedUrgencies = urgencies;
    startDate = start;
    endDate = end;
    notifyListeners();
  }

  void resetFilters() {
    selectedTypes.clear();
    selectedDepartments.clear();
    selectedUserIds.clear();
    selectedLocations.clear();
    selectedUrgencies.clear();
    startDate = null;
    endDate = null;
    notifyListeners();
  }

  // ------------------- Sorting -------------------
  void sortData(String type) {
    int compareDate(a, b) =>
        (DateTime.tryParse(b['reported_date'] ?? '') ?? DateTime.now())
            .compareTo(DateTime.tryParse(a['reported_date'] ?? '') ?? DateTime.now());

    if (type == 'Latest') {
      _data.sort(compareDate);
    } else if (type == 'Oldest') {
      _data.sort((a, b) => compareDate(b, a));
    } else if (type == 'Priority') {
      const priorityOrder = {'Low': 1, 'Medium': 2, 'High': 3, 'Critical': 4};
      _data.sort((a, b) {
        final pa = priorityOrder[(a['urgency'] ?? 'Medium').toString()] ?? 2;
        final pb = priorityOrder[(b['urgency'] ?? 'Medium').toString()] ?? 2;
        return pb.compareTo(pa);
      });
    }
    notifyListeners();
  }

  // ------------------- Helpers -------------------
  List<String> _unique(String field) =>
      _data.map((e) => e[field]?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371000; // Earth radius in meters
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
}
