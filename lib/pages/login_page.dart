import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ringinout/services/app_localizations.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;
  bool _isInitialized = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _initializeGoogleSignIn();
  }

  Future<void> _initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '120131573076-4dgtii5olr1385gfq8jovp6nd7mue2b5.apps.googleusercontent.com',
      );
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      print('Google Sign-In 초기화 실패: $e');
      setState(() {
        _isInitialized = true;
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // google_sign_in 7.x API
      final user = await GoogleSignIn.instance.authenticate();

      if (user == null) {
        _showError('로그인이 취소되었습니다.');
        return;
      }

      // ID Token 가져오기 (google_sign_in 7.x)
      final idToken = user.authentication.idToken;

      if (idToken == null) {
        _showError('ID Token을 가져올 수 없습니다.');
        return;
      }

      // Firebase Auth 인증
      final credential = GoogleAuthProvider.credential(idToken: idToken);

      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Firestore에 사용자 정보 저장
      final firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        await _firestore.collection('users').doc(firebaseUser.uid).set({
          'email': firebaseUser.email,
          'displayName': firebaseUser.displayName,
          'photoURL': firebaseUser.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;
        // 메인 화면으로 이동 (뒤로가기 불가)
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      _showError('로그인 실패: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade400),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // 로고 자리 (추후 로고 추가)
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(
                  Icons.location_on,
                  size: 60,
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 24),

              // 앱 이름
              const Text(
                'Ringinout',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),

              const SizedBox(height: 12),

              // 앱 핵심 기능 소개
              Text(
                l10n.get('login_app_description'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),

              const Spacer(flex: 1),

              // 데이터 보안 안내
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.security,
                          color: Colors.blue.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          l10n.get('login_data_security_title'),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.get('login_data_security_content'),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 앱 삭제 시 데이터 삭제 안내
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.get('login_data_deletion_warning'),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Google 로그인 버튼
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed:
                      _isInitialized && !_isLoading
                          ? _handleGoogleSignIn
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Google 로고
                              Image.network(
                                'https://www.google.com/favicon.ico',
                                width: 24,
                                height: 24,
                                errorBuilder:
                                    (context, error, stackTrace) => const Icon(
                                      Icons.g_mobiledata,
                                      size: 24,
                                    ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                l10n.get('login_continue_with_google'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                ),
              ),

              const SizedBox(height: 32),

              // 개인정보처리방침 링크
              TextButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/privacy_policy');
                },
                child: Text(
                  l10n.get('privacy_policy'),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
