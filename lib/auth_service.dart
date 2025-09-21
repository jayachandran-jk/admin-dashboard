import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? user;
  bool isLoading = false;

  Future<bool> signInWithEmailAndPassword(String email, String password, String department) async {
    try {
      isLoading = true;
      notifyListeners();

      UserCredential result = await _auth.signInWithEmailAndPassword(email: email, password: password);
      user = result.user;

      // Set displayName as department for RBAC
      await user?.updateDisplayName(department);
      await user?.reload();
      user = _auth.currentUser;

      isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    user = null;
    notifyListeners();
  }
}
