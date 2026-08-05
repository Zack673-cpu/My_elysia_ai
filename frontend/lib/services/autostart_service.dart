import 'dart:io';

/// Windows 开机自启动：往用户级注册表 HKCU\...\Run 写两条启动项。
///
/// 后端先启动（隐藏窗口跑 uvicorn），前端延迟 2 秒再启动。
/// 为避免注册表命令的引号转义问题，实际启动逻辑写在两个 .bat 脚本里，
/// 注册表只登记脚本路径，关闭开关即删除注册项。
class AutostartService {
  static const _runKey =
      r'HKCU\Software\Microsoft\Windows\CurrentVersion\Run';
  static const _backendValue = 'MyElysiaBackend';
  static const _frontendValue = 'MyElysiaFrontend';

  /// 默认后端目录（与本机项目位置一致，可在设置里改）
  static const defaultBackendDir = r'D:\My_Elysia_ai\backend';

  String get _scriptDir {
    final local = Platform.environment['LOCALAPPDATA'] ?? '.';
    return '$local\\MyElysiaAI';
  }

  String get _backendBat => '$_scriptDir\\autostart_backend.bat';
  String get _frontendBat => '$_scriptDir\\autostart_frontend.bat';

  /// 找一个能用的 Python：where 出来的候选逐个验证 --version，
  /// 优先用 pythonw.exe（无控制台窗口）
  Future<String?> _findPython() async {
    ProcessResult result;
    try {
      result = await Process.run('where.exe', ['python']);
    } catch (_) {
      return null;
    }
    if (result.exitCode != 0) return null;

    final candidates = (result.stdout as String)
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.toLowerCase().endsWith('python.exe'));
    for (final candidate in candidates) {
      try {
        final test = await Process.run(candidate, ['--version']);
        if (test.exitCode != 0) continue;
      } catch (_) {
        continue;
      }
      final windowless = candidate.replaceFirst(
        RegExp(r'python\.exe$', caseSensitive: false),
        'pythonw.exe',
      );
      if (await File(windowless).exists()) return windowless;
      return candidate;
    }
    return null;
  }

  int _parsePort(String baseUrl) {
    final match = RegExp(r':(\d+)\s*$').firstMatch(baseUrl);
    return match != null ? int.parse(match.group(1)!) : 8000;
  }

  Future<bool> isEnabled() async {
    final result = await Process.run('reg', ['query', _runKey, '/v', _frontendValue]);
    return result.exitCode == 0;
  }

  /// 注册开机自启。backendDir 为后端目录，baseUrl 用于解析端口。
  /// 返回 null 表示成功，否则返回失败原因。
  Future<String?> enable({
    required String backendDir,
    required String baseUrl,
  }) async {
    final python = await _findPython();
    if (python == null) {
      return '找不到可用的 Python，请确认已安装并加入 PATH';
    }

    final exePath = Platform.resolvedExecutable;
    final port = _parsePort(baseUrl);

    try {
      Directory(_scriptDir).createSync(recursive: true);

      // 后端脚本：切到后端目录，隐藏窗口启动 uvicorn（不带热重载）
      // 注意：pythonw 没有控制台，必须把输出重定向到日志文件，
      // 否则 uvicorn 写日志时找不到 stderr 会直接闪退
      File(_backendBat).writeAsStringSync(
        '@echo off\r\n'
        'cd /d "$backendDir"\r\n'
        'start /min "" "$python" -m uvicorn app.main:app --host 127.0.0.1 --port $port > "$_scriptDir\\backend.log" 2>&1\r\n',
        encoding: const SystemEncoding(),
      );

      // 前端脚本：等 2 秒让后端就绪，再启动前端
      File(_frontendBat).writeAsStringSync(
        '@echo off\r\n'
        'timeout /t 2 /nobreak >nul\r\n'
        'start "" "$exePath"\r\n',
        encoding: const SystemEncoding(),
      );

      final addBackend = await Process.run('reg', [
        'add', _runKey, '/v', _backendValue, '/t', 'REG_SZ',
        '/d', '"$_backendBat"', '/f',
      ]);
      if (addBackend.exitCode != 0) {
        return '注册后端启动项失败（可能被安全软件拦截）';
      }
      final addFrontend = await Process.run('reg', [
        'add', _runKey, '/v', _frontendValue, '/t', 'REG_SZ',
        '/d', '"$_frontendBat"', '/f',
      ]);
      if (addFrontend.exitCode != 0) {
        return '注册前端启动项失败（可能被安全软件拦截）';
      }
      return null;
    } catch (e) {
      return '写入启动脚本失败: $e';
    }
  }

  /// 移除开机自启（注册项 + 脚本文件）
  Future<void> disable() async {
    for (final value in [_backendValue, _frontendValue]) {
      await Process.run('reg', ['delete', _runKey, '/v', value, '/f']);
    }
    for (final bat in [_backendBat, _frontendBat]) {
      final file = File(bat);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }
}
