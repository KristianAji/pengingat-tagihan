import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/bill_provider.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const PengingatTagihanApp());

  // Notifikasi disiapkan SETELAH frame pertama, bukan sebelumnya.
  //
  // init() meminta izin notifikasi, dan di Android 12 juga membuka halaman
  // Settings izin alarm. Keduanya baru selesai setelah pengguna menjawab,
  // jadi bila ditunggu sebelum runApp() layar aplikasi tidak pernah tampil —
  // pengguna cuma melihat jendela kosong sambil tertahan di dialog izin.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(NotificationService.instance.init());
  });
}

class PengingatTagihanApp extends StatefulWidget {
  const PengingatTagihanApp({super.key});

  @override
  State<PengingatTagihanApp> createState() => _PengingatTagihanAppState();
}

class _PengingatTagihanAppState extends State<PengingatTagihanApp> {
  // Instance tunggal + stream di-cache agar tidak re-subscribe tiap rebuild.
  final AuthService _auth = AuthService();
  late final Stream<User?> _authState = _auth.authState;

  @override
  Widget build(BuildContext context) {
    return Provider<AuthService>.value(
      value: _auth,
      child: StreamBuilder<User?>(
        stream: _authState,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          final user = snapshot.data;

          final Widget home = waiting
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : user == null
                  ? const LoginScreen()
                  : const HomeShell();

          final app = MaterialApp(
            title: 'Pengingat Tagihan',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            home: home,
          );

          // Saat login: BillProvider sengaja diletakkan DI ATAS MaterialApp.
          // Dengan begitu halaman yang dibuka lewat Navigator.push
          // (AddBillScreen, BillListScreen, dll.) tetap menemukan provider ini,
          // karena Navigator milik MaterialApp berada di bawahnya.
          if (user != null) {
            return ChangeNotifierProvider<BillProvider>(
              key: ValueKey(user.uid),
              create: (_) => BillProvider(user.uid),
              child: app,
            );
          }
          return app;
        },
      ),
    );
  }
}
