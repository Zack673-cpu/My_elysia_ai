import 'dart:io';

/// Windows 开机自启动：往用户级注册表 HKCU\...\Run 写一条启动项。
///
/// 注册表只登记一个隐藏启动器 VBS，它拉起项目根目录的 start_app.bat：
/// 后端没起就先静默启动后端 → 启动前端 → 前端退出后同步关闭后端。
/// 关闭开关即删除注册项；同时清理旧版前后端分离的启动项与脚本。
class AutostartService {
  static const _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _appValue = 'MyElysiaApp';

  /// 旧版（前后端分离）启动项，disable/重新 enable 时一并清理
  static const _legacyValues = ['MyElysiaBackend', 'MyElysiaFrontend'];

  /// 默认后端目录（与本机项目位置一致，可在设置里改）
  static const defaultBackendDir = r'D:\My_Elysia_ai\backend';

  String get _scriptDir {
    final local = Platform.environment['LOCALAPPDATA'] ?? '.';
    return '$local\\MyElysiaAI';
  }

  String get _launcherVbs => '$_scriptDir\\autostart_app.vbs';
  String get _legacyBackendBat => '$_scriptDir\\autostart_backend.bat';
  String get _legacyBackendVbs => '$_scriptDir\\autostart_backend.vbs';
  String get _legacyFrontendBat => '$_scriptDir\\autostart_frontend.bat';

  Future<bool> _regValueExists(String value) async {
    final result = await Process.run('reg', ['query', _runKey, '/v', value]);
    return result.exitCode == 0;
  }

  Future<bool> isEnabled() async {
    if (await _regValueExists(_appValue)) return true;
    for (final legacy in _legacyValues) {
      if (await _regValueExists(legacy)) return true;
    }
    return false;
  }

  /// 注册开机自启。backendDir 用于定位项目根目录下的 start_app.bat。
  /// 返回 null 表示成功，否则返回失败原因。
  Future<String?> enable({required String backendDir}) async {
    final launcher = '${File(backendDir).parent.path}\\start_app.bat';
    if (!File(launcher).existsSync()) {
      return '找不到统一启动脚本: $launcher';
    }

    try {
      Directory(_scriptDir).createSync(recursive: true);

      // VBS 隐藏启动器：bat 里有等待逻辑会一直占用控制台，
      // 用 WScript.Shell.Run 以窗口样式 0（完全隐藏）拉起
      File(_launcherVbs).writeAsStringSync(
        'CreateObject("WScript.Shell").Run """$launcher""", 0, False\r\n',
        encoding: const SystemEncoding(),
      );

      // 清掉旧版分离式启动项，避免新旧同时生效启动两遍
      for (final legacy in _legacyValues) {
        await Process.run('reg', ['delete', _runKey, '/v', legacy, '/f']);
      }

      final add = await Process.run('reg', [
        'add', _runKey, '/v', _appValue, '/t', 'REG_SZ',
        '/d', '"$_launcherVbs"', '/f',
      ]);
      if (add.exitCode != 0) {
        return '注册开机启动项失败（可能被安全软件拦截）';
      }
      return null;
    } catch (e) {
      return '写入启动脚本失败: $e';
    }
  }

  /// 移除开机自启（注册项 + 脚本文件，含旧版遗留）
  Future<void> disable() async {
    for (final value in [_appValue, ..._legacyValues]) {
      await Process.run('reg', ['delete', _runKey, '/v', value, '/f']);
    }
    for (final path in [
      _launcherVbs,
      _legacyBackendBat,
      _legacyBackendVbs,
      _legacyFrontendBat,
    ]) {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
