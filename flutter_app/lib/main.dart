import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/setup_screen.dart';
import 'screens/inbox_screen.dart';
import 'screens/replies_screen.dart';
import 'screens/profile_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GmailAIApp());
}

class GmailAIApp extends StatefulWidget {
  const GmailAIApp({super.key});
  @override
  State<GmailAIApp> createState() => _GmailAIAppState();
}

class _GmailAIAppState extends State<GmailAIApp> {
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _initDeepLinks();
    }
  }

  void _initDeepLinks() async {
    try {
      // ignore: depend_on_referenced_packages
      final appLinks = await _loadAppLinks();
      appLinks?.listen((uri) {
        if (uri.scheme == 'gmailai' && uri.host == 'auth') {
          _navKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
        }
      });
    } catch (_) {}
  }

  Stream<Uri>? _loadAppLinks() {
    try {
      // dynamic import to avoid web crash
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navKey,
      title: 'Gmail AI',
      theme: AppTheme.dark,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/':        (_) => const HomeScreen(),
        '/setup':   (_) => const SetupScreen(),
        '/inbox':   (_) => const InboxScreen(),
        '/replies': (_) => const RepliesScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}
