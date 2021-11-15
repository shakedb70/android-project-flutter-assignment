import 'dart:developer';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

enum Status { Uninitialized, Authenticated, Authenticating, Unauthenticated }

class FirebaseRepository with ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  User? _user;
  String? _id;
  Status _status = Status.Uninitialized;
  String _image = "";
  final Set<String> _favorites = {};

  FirebaseRepository.instance() : _auth = FirebaseAuth.instance {
    _auth.authStateChanges().listen(_onAuthStateChanged);
    _user = _auth.currentUser;
    _onAuthStateChanged(_user);
  }

  Status get status => _status;

  String get image => _image;

  User? get user => _user;

  Set<String> get favorites => _favorites;

  bool get isAuthenticated => status == Status.Authenticated;

  setImage(String url)
  {
    _image = url;
  }

  addToFavorites(String favorite) {
    _favorites.add(favorite);
    if (_user != null) {
      updateFavoritesInDatabase(_user!.email);
    }
  }

  deleteFromFavorites(String favorite) {
    _favorites.remove(favorite);
    notifyListeners();
    if (_user != null) {
      updateFavoritesInDatabase(_user!.email);
    }
  }

  Future<UserCredential?> signUp(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      UserCredential user = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);

      _user = user.user;
      await _db
          .collection("favorites")
          .add({"email": email, "favorites": _favorites.toList()});

      notifyListeners();

      return user;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return null;
    }
  }

  Future<bool> signIn(String email, String password) async {
    try {
      _status = Status.Authenticating;
      notifyListeners();
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      _image = await FirebaseStorage.instance.ref('avatar/$email').getDownloadURL();

      notifyListeners();
      return true;
    } catch (e) {
      _status = Status.Unauthenticated;
      notifyListeners();
      return false;
    }
  }

  Stream<QuerySnapshot?>? getFavoritesFromDatabase() {
    String? email;

    if (_user == null) {
      return null;
    }
    else{
      email = user!.email;
    }

    return _db
        .collection("favorites")
        .where(
      'email',
      isEqualTo: email,
    ).snapshots();
  }

  Future<void> updateFavoritesInDatabase(String? email) async {
    await _db
        .collection("favorites")
        .where(
      'email',
      isEqualTo: email,
    )
        .get()
        .then((querySnapshot) {
      for (var document in querySnapshot.docs) {
        _id = document.id;
      }
    });

    _db
        .collection("favorites")
        .doc(_id)
        .update({"email": email, "favorites": _favorites.toList()});

    notifyListeners();
  }

  Future signOut() async {
    updateFavoritesInDatabase(_user!.email);
    _auth.signOut();
    _status = Status.Unauthenticated;
    _id = null;
    _image = "";
    notifyListeners();
    return Future.delayed(Duration.zero);
  }

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    if (firebaseUser == null) {
      _user = null;
      _status = Status.Unauthenticated;
    } else {
      _user = firebaseUser;
      _status = Status.Authenticated;
    }
    notifyListeners();
  }
}
