import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Global variable to count unique issues (clustered)
int uniqueIssueCount = 0;

class DataService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _data = [];
  bool _isLoading = false;
  String? _error;

  // Issue counts by status
  Map<String, int> _issueCounts = {};

  // Getters
  List<Map<String, dynamic>> get data => _data;
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

        // Unique key for clustering
        final key = "$issueType-$lat-$lng";

        if (grouped.containsKey(key)) {
          grouped[key]!['count'] += 1;
          // ✅ store full document path for batch updates
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
            'count': 1,
            // ✅ use full path instead of doc.id
            'ids': [doc.reference.path],
          };
        }
      }

      // Update data list
      _data = grouped.values.toList();

      // Update global unique issue count
      uniqueIssueCount = _data.length;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
    }
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

      // 🔑 docPaths now contain FULL Firestore paths
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
