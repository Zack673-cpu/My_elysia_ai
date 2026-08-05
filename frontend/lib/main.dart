import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/app_config.dart';
import 'config/theme.dart';
import 'providers/chat_provider.dart';
import 'providers/daily_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/chat_screen.dart';
import 'screens/daily_screen.dart';
import 'services/api_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyElysiaAi());
}

class MyElysiaAi extends StatelessWidget {
  const MyElysiaAi({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => DailyProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: AppConfig.appFullName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.settings.isDarkMode
                ? ThemeMode.dark
                : ThemeMode.light,
            home: const _DailyBootstrapper(child: ChatScreen()),
          );
        },
      ),
    );
  }
}

/// 启动引导：后端连上后检查今日每日问答，未完成则自动打开每日页面
class _DailyBootstrapper extends StatefulWidget {
  final Widget child;

  const _DailyBootstrapper({required this.child});

  @override
  State<_DailyBootstrapper> createState() => _DailyBootstrapperState();
}

class _DailyBootstrapperState extends State<_DailyBootstrapper> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    if (settings.isConnected && !_checked) {
      _checked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkDaily());
    }
    return widget.child;
  }

  Future<void> _checkDaily() async {
    try {
      final api = ApiService();
      final state = await api.getDailyToday();
      if (!state.isDone && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DailyScreen()),
        );
      }
    } catch (_) {
      // 后端未就绪或获取失败时不打扰用户
    }
  }
}
