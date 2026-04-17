// lib/utils/report_rate_limiter.dart
// 버그 리포트 / 건의사항 전송 횟수 제한 유틸리티.
// - 30분 쿨다운
// - 하루 최대 3회
// 서버 안정성 보호 및 악용 방지 목적.

import 'package:hive_flutter/hive_flutter.dart';

class ReportRateLimiter {
  static const String _boxName = 'report_rate_limit';
  static const Duration cooldown = Duration(minutes: 30);
  static const int maxPerDay = 3;

  static Box? _box;

  /// 앱 시작 시 한 번 호출
  static Future<void> init() async {
    _box ??= await Hive.openBox(_boxName);
  }

  /// 전송 가능 여부 확인.
  /// [type]: 'bug_report' 또는 'feedback'
  /// 반환: null이면 전송 가능, 문자열이면 거부 사유 메시지.
  static String? canSend(String type) {
    if (_box == null || !_box!.isOpen) return null; // 초기화 안 됐으면 허용

    final lastSentMs =
        _box!.get('${type}_last_sent_ms', defaultValue: 0) as int;
    final dailyCount = _box!.get('${type}_daily_count', defaultValue: 0) as int;
    final dailyDate =
        _box!.get('${type}_daily_date', defaultValue: '') as String;

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    // 날짜가 바뀌었으면 카운터 리셋
    final effectiveCount = (dailyDate == today) ? dailyCount : 0;

    // 하루 최대 횟수 초과
    if (effectiveCount >= maxPerDay) {
      return 'daily_limit'; // 오늘 최대 $maxPerDay회 전송 완료
    }

    // 쿨다운 체크
    if (lastSentMs > 0) {
      final lastSent = DateTime.fromMillisecondsSinceEpoch(lastSentMs);
      final remaining = cooldown - now.difference(lastSent);
      if (remaining.isNegative == false && remaining.inSeconds > 0) {
        return 'cooldown:${remaining.inMinutes}:${(remaining.inSeconds % 60).toString().padLeft(2, '0')}';
      }
    }

    return null; // 전송 가능
  }

  /// 전송 완료 후 기록 갱신
  static Future<void> recordSent(String type) async {
    if (_box == null || !_box!.isOpen) return;

    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final dailyDate =
        _box!.get('${type}_daily_date', defaultValue: '') as String;
    int dailyCount = _box!.get('${type}_daily_count', defaultValue: 0) as int;

    if (dailyDate != today) {
      dailyCount = 0;
    }

    await _box!.put('${type}_last_sent_ms', now.millisecondsSinceEpoch);
    await _box!.put('${type}_daily_count', dailyCount + 1);
    await _box!.put('${type}_daily_date', today);
  }

  /// 남은 쿨다운 시간 (없으면 Duration.zero)
  static Duration remainingCooldown(String type) {
    if (_box == null || !_box!.isOpen) return Duration.zero;
    final lastSentMs =
        _box!.get('${type}_last_sent_ms', defaultValue: 0) as int;
    if (lastSentMs == 0) return Duration.zero;
    final lastSent = DateTime.fromMillisecondsSinceEpoch(lastSentMs);
    final remaining = cooldown - DateTime.now().difference(lastSent);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 오늘 남은 전송 횟수
  static int remainingToday(String type) {
    if (_box == null || !_box!.isOpen) return maxPerDay;
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final dailyDate =
        _box!.get('${type}_daily_date', defaultValue: '') as String;
    final dailyCount = _box!.get('${type}_daily_count', defaultValue: 0) as int;
    if (dailyDate != today) return maxPerDay;
    return (maxPerDay - dailyCount).clamp(0, maxPerDay);
  }
}
