import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/user_settings.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  StreamSubscription? _userSubscription;

  AuthCubit() : super(AuthInitial()) {
    _userSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        emit(AuthSuccess(user));
      } else {
        emit(AuthInitial());
      }
    });
  }

  Future<void> signUpWithEmailPassword(String email, String password, String name) async {
    emit(AuthLoading());
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update display name
      await userCredential.user!.updateDisplayName(name);
      
      // Create user settings in database
      final userSettings = UserSettings(
        userId: userCredential.user!.uid,
        username: name,
        email: email,
        avatar: '👤',
      );
      
      // Save user data to database
      await _database.child('users').child(userCredential.user!.uid).set({
        'name': name,
        'email': email,
        'avatar': '👤',
        'gamesPlayed': 0,
        'gamesWon': 0,
        'totalScore': 0,
        'createdAt': DateTime.now().toIso8601String(),
        'lastSeen': DateTime.now().toIso8601String(),
      });
      
      // Save user settings
      await _database.child('users').child(userCredential.user!.uid).child('settings').set(userSettings.toJson());
      
      // The listener will automatically emit AuthSuccess
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('حدث خطأ غير متوقع: $e'));
    }
  }

  Future<void> signInWithEmailPassword(String email, String password) async {
    emit(AuthLoading());
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      
      // Update last seen
      if (_auth.currentUser != null) {
        await _database.child('users').child(_auth.currentUser!.uid).update({
          'lastSeen': DateTime.now().toIso8601String(),
        });
      }
      
      // The listener will automatically emit AuthSuccess
    } on FirebaseAuthException catch (e) {
      emit(AuthError(_mapFirebaseError(e.code)));
    } catch (e) {
      emit(AuthError('حدث خطأ غير متوقع'));
    }
  }

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      emit(AuthError('فشل تسجيل الخروج'));
    }
  }

  Future<void> updateUserProfile(String name, String avatar) async {
    try {
      if (_auth.currentUser != null) {
        await _auth.currentUser!.updateDisplayName(name);
        
        await _database.child('users').child(_auth.currentUser!.uid).update({
          'name': name,
          'avatar': avatar,
        });
      }
    } catch (e) {
      emit(AuthError('فشل تحديث الملف الشخصي'));
    }
  }

  Future<Map<String, dynamic>?> getUserData(String userId) async {
    try {
      final snapshot = await _database.child('users').child(userId).get();
      if (snapshot.exists) {
        return Map<String, dynamic>.from(snapshot.value as Map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _userSubscription?.cancel();
    return super.close();
  }

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'المستخدم غير موجود';
      case 'wrong-password':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'البريد الإلكتروني مستخدم بالفعل';
      case 'invalid-email':
        return 'البريد الإلكتروني غير صالح';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جدًا';
      default:
        return 'حدث خطأ في المصادقة';
    }
  }
} 