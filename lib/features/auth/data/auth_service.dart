import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_storage_service.dart'; // Import the memory helper

class AuthService {
  // 1. Get the tools we need
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- SIGN UP FUNCTION ---
  Future<void> registerUser({
    required String phone,
    required String password,
    required String name,
  }) async {
    try {
      // Step A: Create the "Auth" User
      String fakeEmail = "$phone@expense.com";

      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      // Step B: Save the extra details to Firestore
      String uid = userCredential.user!.uid;

      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'phone': phone,
        'mpin': '',
        'balance': 0,
        'createdAt': DateTime.now(),
        'uid': uid,
      });

      // Step C: Save Phone to Local Memory
      await LocalStorageService.savePhoneNumber(phone);

    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw "This phone number is already registered. Please Login.";
      } else if (e.code == 'weak-password') {
        throw "Password is too weak.";
      } else {
        throw e.message ?? "Registration failed";
      }
    } catch (e) {
      throw e.toString();
    }
  }

  // --- LOGIN FUNCTION ---
  Future<void> loginUser({
    required String phone,
    required String password,
  }) async {
    try {
      String fakeEmail = "$phone@expense.com";

      await _auth.signInWithEmailAndPassword(
        email: fakeEmail,
        password: password,
      );

      await LocalStorageService.savePhoneNumber(phone);

    } catch (e) {
      throw "Invalid Phone or Password";
    }
  }

  // --- UPDATE MPIN FUNCTION ---
  Future<void> setMpin(String mpin) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await _firestore.collection('users').doc(user.uid).update({
        'mpin': mpin,
      });
    } else {
      throw "User not logged in";
    }
  }

  // --- NEW: CHECK IF USER HAS FINISHED SETUP ---
  // Returns TRUE if they have accounts, FALSE if they are new.
  Future<bool> isAccountSetup() async {
    User? user = _auth.currentUser;
    if (user == null) return false;

    // Check if the 'accounts' subcollection has any documents
    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('accounts')
        .limit(1) // We only need to know if 1 exists
        .get();

    return snapshot.docs.isNotEmpty;
  }
}