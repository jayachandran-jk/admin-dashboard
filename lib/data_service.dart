import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global variable to count unique issues (clustered)
int uniqueIssueCount = 0;

class DataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _data = [];
  List<Map<String, dynamic>> _filteredData = [];
  bool _isLoading = false;
  String? _error;

  // Issue counts by status
  Map<String, int> _issueCounts = {};

  // Filters
  List<String> selectedTypes = [];
  List<String> selectedDepartments = [];
  List<String> selectedUserIds = [];
  List<String> selectedLocations = [];
  DateTime? startDate;
  DateTime? endDate;

  // Getters
  List<Map<String, dynamic>> get data => _filteredData.isEmpty ? _data : _filteredData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Map<String, int> get issueCounts => _issueCounts;

  /// Fetch all issues and cluster them by type + location
  Future<void> fetchData() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final snapshot = await _firestore.collectionGroup('issues').get();

      // Temporary map to group issues
      final Map<String, Map<String, dynamic>> grouped = {};

      for (var doc in snapshot.docs) {
        final d = doc.data();
        final issueType = d['issue_type'] ?? 'Unknown';
        final lat = d['latitude']?.toString() ?? '0.0';
        final lng = d['longitude']?.toString() ?? '0.0';

        final key = "$issueType-$lat-$lng";

        if (grouped.containsKey(key)) {
          grouped[key]!['count'] += 1;
          grouped[key]!['ids'].add(doc.reference.path);
        } else {
          grouped[key] = {
            'issue_type': issueType,
            'latitude': lat,
            'longitude': lng,
            'address': d['address']?.toString() ?? 'N/A',
            'description': d['description'] ?? '',
            'status': d['status'] ?? 'Pending',
            'urgency': d['urgency'] ?? 'Medium',
            'reported_date': d['reported_date'] ?? '',
            'user_id': d['user_id'] ?? '',
            'department': d['department'] ?? '',
            'count': 1,
            'ids': [doc.reference.path],
          };
        }
      }

      _data = grouped.values.toList();
      uniqueIssueCount = _data.length;

      // Apply filters if any
      applyFilters();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Apply selected filters
  void applyFilters() {
    _filteredData = _data.where((issue) {
      final typeMatch = selectedTypes.isEmpty || selectedTypes.contains(issue['issue_type']);
      final deptMatch = selectedDepartments.isEmpty || selectedDepartments.contains(issue['department']);
      final userMatch = selectedUserIds.isEmpty || selectedUserIds.contains(issue['user_id']);
      final locMatch = selectedLocations.isEmpty || selectedLocations.any((loc) => (issue['address'] as String).toLowerCase().contains(loc.toLowerCase()));

      bool dateMatch = true;
      if (startDate != null || endDate != null) {
        try {
          final issueDate = DateTime.parse(issue['reported_date']);
          if (startDate != null && issueDate.isBefore(startDate!)) dateMatch = false;
          if (endDate != null && issueDate.isAfter(endDate!)) dateMatch = false;
        } catch (_) {
          dateMatch = false;
        }
      }

      return typeMatch && deptMatch && userMatch && locMatch && dateMatch;
    }).toList();
  }

  /// Reset all filters
  void resetFilters() {
    selectedTypes.clear();
    selectedDepartments.clear();
    selectedUserIds.clear();
    selectedLocations.clear();
    startDate = null;
    endDate = null;
    applyFilters();
    notifyListeners();
  }

  /// Stream issue counts by status in real-time
  Stream<void> fetchIssueCounts() {
    return _firestore.collectionGroup('issues').snapshots().map((snapshot) {
      final counts = <String, int>{};
      for (var doc in snapshot.docs) {
        final status = doc['status'] ?? 'Pending';
        counts[status] = (counts[status] ?? 0) + 1;
      }
      _issueCounts = counts;
      notifyListeners();
    });
  }

  /// Update the status of all docs in a clustered issue
  Future<void> updateIssueStatus(List<String> docPaths, String newStatus) async {
    try {
      final batch = _firestore.batch();
      for (final path in docPaths) {
        batch.update(_firestore.doc(path), {'status': newStatus});
      }
      await batch.commit();
      await fetchData(); // refresh local cache after update
    } catch (e) {
      debugPrint('Status update failed: $e');
    }
  }
}
