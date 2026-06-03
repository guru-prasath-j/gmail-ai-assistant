import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
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
  final _appLinks = AppLinks();
  final _navKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _appLinks.uriLinkStream.listen((uri) {
      if (uri.scheme == 'gmailai' && uri.host == 'auth') {
        // OAuth callback — navigate to home
        _navKey.currentState?.pushNamedAndRemoveUntil('/', (_) => false);
      }
    });
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
        '/':       (_) => const HomeScreen(),
        '/setup':  (_) => const SetupScreen(),
        '/inbox':  (_) => const InboxScreen(),
        '/replies':(_) => const RepliesScreen(),
        '/profile':(_) => const ProfileScreen(),
      },
    );
  }
}
