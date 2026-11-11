import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'language.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaEnterpriseProvider(
      '6Le-8RouAAAAAJzDLMNfFn9h_M_YYrD4NgQ_isP6',
    ),
  );

  runApp(const MotherCareApp());
}

class MotherCareApp extends StatelessWidget {
  const MotherCareApp({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<String>(
    valueListenable: appLanguage,
    builder: (context, lang, _) => MaterialApp(
      title: 'MotherCare Connect',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFC04467),
          surface: const Color(0xFFFFF8FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8FA),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFF8FA),
          centerTitle: false,
        ),
      ),
      home: const SessionGate(),
    ),
  );
}

class SessionGate extends StatelessWidget {
  const SessionGate({super.key});
  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.authStateChanges(),
    builder: (context, authSnap) {
      if (authSnap.connectionState == ConnectionState.waiting)
        return const LoadingView();
      final user = authSnap.data;
      if (user == null) return const AuthScreen();
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, profileSnap) {
          if (profileSnap.hasError)
            return ErrorView(
              message:
                  'Cannot load profile. Check Firestore rules. ${profileSnap.error}',
            );
          if (!profileSnap.hasData) return const LoadingView();
          final profile = profileSnap.data!.data();
          if (profile == null) return MissingProfileScreen(uid: user.uid);
          final role = profile['role'] as String? ?? '';
          if (role == 'patient')
            return PatientDashboard(
              uid: user.uid,
              name: profile['name'] as String? ?? 'Mother',
            );
          if (role == 'worker')
            return WorkerDashboard(
              uid: user.uid,
              name: profile['name'] as String? ?? 'Healthcare worker',
            );
          if (role == 'admin') return const AdminDashboard();
          if (role == 'worker_rejected') return const RejectedScreen();
          return const PendingScreen();
        },
      );
    },
  );
}
