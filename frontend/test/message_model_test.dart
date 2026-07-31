import 'package:flutter_test/flutter_test.dart';
import 'package:my_elysia_ai/models/message.dart';

void main() {
  // ═══════════════════════════════════════
  // 第一组：Message 基础功能
  // ═══════════════════════════════════════

  group('Message 创建', () {
    test('正常创建用户消息', () {
      final msg = Message(role: 'user', content: '我今天心情不好');

      // 期望：字段正确赋值
      expect(msg.role, 'user');
      expect(msg.content, '我今天心情不好');
      expect(msg.isUser, true);       // isUser getter 应返回 true
      expect(msg.isAssistant, false); // isAssistant 应返回 false
    });

    test('不传 timestamp 时自动填入当前时间', () {
      final before = DateTime.now();
      final msg = Message(role: 'assistant', content: 'hi');
      final after = DateTime.now();

      // 期望：timestamp 在 before 和 after 之间
      expect(msg.timestamp.isAfter(before) || msg.timestamp.isAtSameMomentAs(before), true);
      expect(msg.timestamp.isBefore(after) || msg.timestamp.isAtSameMomentAs(after), true);
    });

    test('传入指定 timestamp 时使用指定值', () {
      final fixedTime = DateTime(2026, 1, 1, 12, 0);
      final msg = Message(
        role: 'user',
        content: 'hello',
        timestamp: fixedTime,
      );

      // 期望：使用传入的时间，不是当前时间
      expect(msg.timestamp, fixedTime);
    });
  });

  // ═══════════════════════════════════════
  // 第二组：JSON 序列化/反序列化
  // ═══════════════════════════════════════

  group('toJson / fromJson 往返转换', () {
    test('基础消息：toJson 后 fromJson 数据不变', () {
      final original = Message(
        role: 'user',
        content: '测试消息内容',
        timestamp: DateTime(2026, 6, 15, 10, 30, 0),
      );

      // 转成 JSON → 再从 JSON 还原
      final json = original.toJson();
      final restored = Message.fromJson(json);

      // 期望：关键字段完全一致
      expect(restored.role, original.role);
      expect(restored.content, original.content);
      expect(restored.timestamp, original.timestamp);
    });

    test('带搜索元数据的消息：往返后元数据保留', () {
      final original = Message(
        role: 'assistant',
        content: '根据搜索结果...',
        timestamp: DateTime(2026, 6, 15),
        metadata: MessageMetadata(
          modelUsed: 'deepseek-chat',
          searchPerformed: true,
          searchQuery: '焦虑症缓解方法',
          tokensUsed: 512,
        ),
      );

      final json = original.toJson();
      final restored = Message.fromJson(json);

      // 期望：元数据字段正确还原
      expect(restored.metadata.modelUsed, 'deepseek-chat');
      expect(restored.metadata.searchPerformed, true);
      expect(restored.metadata.searchQuery, '焦虑症缓解方法');
      expect(restored.metadata.tokensUsed, 512);
    });

    test('fromJson 处理缺失字段不崩溃', () {
      // 给一个几乎为空的 JSON
      final restored = Message.fromJson({});

      // 期望：使用默认值，不抛异常
      expect(restored.role, 'user');    // 默认值
      expect(restored.content, '');     // 默认值
      expect(restored.metadata.searchPerformed, false); // 默认值
    });

    test('toJson 输出格式正确', () {
      final msg = Message(
        role: 'assistant',
        content: '你好',
        timestamp: DateTime(2026, 6, 15, 8, 0, 0),
      );
      final json = msg.toJson();

      // 期望：JSON 的 key 名称符合约定
      expect(json.containsKey('role'), true);
      expect(json.containsKey('content'), true);
      expect(json.containsKey('timestamp'), true);
      expect(json.containsKey('metadata'), true);
      expect(json['timestamp'], '2026-06-15T08:00:00.000');
    });
  });

  // ═══════════════════════════════════════
  // 第三组：边界情况
  // ═══════════════════════════════════════

  group('边界情况', () {
    test('空字符串内容', () {
      final msg = Message(role: 'user', content: '');
      expect(msg.content, '');
      expect(msg.toJson()['content'], '');
    });

    test('超长内容（10000字）', () {
      final longText = '测试' * 5000; // 10000个字符
      final msg = Message(role: 'assistant', content: longText);

      // 期望：往返后内容完整，不截断
      final restored = Message.fromJson(msg.toJson());
      expect(restored.content.length, 10000);
      expect(restored.content, longText);
    });

    test('含特殊字符的内容', () {
      final special = '中文\n换行\t制表符 "引号" <html> &符号';
      final msg = Message(role: 'user', content: special);
      final restored = Message.fromJson(msg.toJson());

      // 期望：特殊字符完整保留
      expect(restored.content, special);
    });
  });

  // ═══════════════════════════════════════
  // 第四组：角色判断 getter
  // ═══════════════════════════════════════

  group('角色判断', () {
    test('isUser / isAssistant / isSystemContext 互斥', () {
      final userMsg = Message(role: 'user', content: '');
      final assistantMsg = Message(role: 'assistant', content: '');
      final systemMsg = Message(role: 'system_context', content: '');

      // 期望：每条消息只有一个角色为 true
      expect(userMsg.isUser, true);
      expect(userMsg.isAssistant, false);
      expect(userMsg.isSystemContext, false);

      expect(assistantMsg.isUser, false);
      expect(assistantMsg.isAssistant, true);
      expect(assistantMsg.isSystemContext, false);

      expect(systemMsg.isUser, false);
      expect(systemMsg.isAssistant, false);
      expect(systemMsg.isSystemContext, true);
    });
  });
}
