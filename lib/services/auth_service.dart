/**
 * AuthService - 인증 관리 서비스
 * 
 * 기능:
 * - Google Sign-In + Firebase Auth 로그인
 * - Firebase ID Token 관리
 * - 서버 세션 연동
 * 
 * 원칙:
 * - 이메일/이름 등은 UI 표시용으로만 사용
 * - 서버로 전송하지 않음 (ID Token만 전송)
 */

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AuthService {
  static const String serverUrl = 'http://localhost:3000'; // TODO: 프로덕션 URL로 변경

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// 현재 로그인된 사용자
  User? get currentUser => _auth.currentUser;

  /// 인증 상태 스트림
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Google Sign-In 초기화
  Future<void> initialize() async {
    await _googleSignIn.initialize(
      serverClientId:
          '120131573076-4dgtii5olr1385gfq8jovp6nd7mue2b5.apps.googleusercontent.com',
    );
  }

  /// Google 로그인
  Future<User?> signInWithGoogle() async {
    try {
      // Google 인증
      final googleUser = await _googleSignIn.authenticate();
      if (googleUser == null) {
        throw Exception('Google Sign-In canceled');
      }

      final idToken = googleUser.authentication.idToken;
      if (idToken == null) {
        throw Exception('Failed to get ID Token');
      }

      // Firebase 인증
      final credential = GoogleAuthProvider.credential(idToken: idToken);
      final userCredential = await _auth.signInWithCredential(credential);

      // 서버 세션 생성
      await _createServerSession(idToken);

      return userCredential.user;
    } catch (e) {
      print('❌ Sign-in failed: $e');
      rethrow;
    }
  }

  /// 서버 세션 생성
  Future<void> _createServerSession(String idToken) async {
    try {
      final response = await http.post(
        Uri.parse('$serverUrl/auth/session'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (response.statusCode != 200) {
        throw Exception('Server session creation failed: ${response.body}');
      }

      print('✅ Server session created');
    } catch (e) {
      print('⚠️ Server session creation failed (continuing): $e');
      // 서버 연결 실패해도 로그인은 유지 (오프라인 대응)
    }
  }

  /// 현재 ID Token 가져오기
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final user = currentUser;
    if (user == null) return null;

    try {
      return await user.getIdToken(forceRefresh);
    } catch (e) {
      print('❌ Failed to get ID Token: $e');
      return null;
    }
  }

  /// 로그아웃
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    print('✅ Signed out');
  }

  /// 계정 삭제
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    // TODO: 서버에 계정 삭제 요청 (구독 데이터 삭제)

    await user.delete();
    await _googleSignIn.signOut();
    print('✅ Account deleted');
  }
}
