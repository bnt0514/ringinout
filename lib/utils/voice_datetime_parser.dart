import 'package:flutter/material.dart';

/// 음성인식 텍스트에서 날짜/시간/요일 정보를 추출하는 유틸리티
///
/// 지원 언어: 한국어(ko), 영어(en), 일본어(ja), 중국어(zh)
class VoiceDateTimeParser {
  // ═══════════════════════════════════════════════════════════
  //  요일 코드 → 한국어 이름 (UI 표시용)
  // ═══════════════════════════════════════════════════════════
  static const Map<String, String> weekdayNames = {
    'sun': '일',
    'mon': '월',
    'tue': '화',
    'wed': '수',
    'thu': '목',
    'fri': '금',
    'sat': '토',
  };

  // ═══════════════════════════════════════════════════════════
  //  요일 키워드 맵 (언어별)
  // ═══════════════════════════════════════════════════════════
  static const Map<String, Map<String, List<String>>> _weekdayKeywords = {
    'ko': {
      'mon': ['월요일', '월욜'],
      'tue': ['화요일', '화욜'],
      'wed': ['수요일', '수욜'],
      'thu': ['목요일', '목욜'],
      'fri': ['금요일', '금욜'],
      'sat': ['토요일', '토욜'],
      'sun': ['일요일', '일욜'],
    },
    'en': {
      'mon': ['monday', 'mon'],
      'tue': ['tuesday', 'tue', 'tues'],
      'wed': ['wednesday', 'wed'],
      'thu': ['thursday', 'thu', 'thur', 'thurs'],
      'fri': ['friday', 'fri'],
      'sat': ['saturday', 'sat'],
      'sun': ['sunday', 'sun'],
    },
    'ja': {
      'mon': ['月曜日', '月曜', 'げつようび', 'げつよう'],
      'tue': ['火曜日', '火曜', 'かようび', 'かよう'],
      'wed': ['水曜日', '水曜', 'すいようび', 'すいよう'],
      'thu': ['木曜日', '木曜', 'もくようび', 'もくよう'],
      'fri': ['金曜日', '金曜', 'きんようび', 'きんよう'],
      'sat': ['土曜日', '土曜', 'どようび', 'どよう'],
      'sun': ['日曜日', '日曜', 'にちようび', 'にちよう'],
    },
    'zh': {
      'mon': ['星期一', '周一', '礼拜一'],
      'tue': ['星期二', '周二', '礼拜二'],
      'wed': ['星期三', '周三', '礼拜三'],
      'thu': ['星期四', '周四', '礼拜四'],
      'fri': ['星期五', '周五', '礼拜五'],
      'sat': ['星期六', '周六', '礼拜六'],
      'sun': ['星期日', '星期天', '周日', '周天', '礼拜天'],
    },
    // 지원 언어: ko, en, ja, zh, de, fr, es
    'de': {
      'mon': ['montag', 'mo'],
      'tue': ['dienstag', 'di'],
      'wed': ['mittwoch', 'mi'],
      'thu': ['donnerstag', 'do'],
      'fri': ['freitag', 'fr'],
      'sat': ['samstag', 'sa'],
      'sun': ['sonntag', 'so'],
    },
    'fr': {
      'mon': ['lundi', 'lun'],
      'tue': ['mardi', 'mar'],
      'wed': ['mercredi', 'mer'],
      'thu': ['jeudi', 'jeu'],
      'fri': ['vendredi', 'ven'],
      'sat': ['samedi', 'sam'],
      'sun': ['dimanche', 'dim'],
    },
    'es': {
      'mon': ['lunes', 'lun'],
      'tue': ['martes', 'mar'],
      'wed': ['miércoles', 'mié', 'miercoles'],
      'thu': ['jueves', 'jue'],
      'fri': ['viernes', 'vie'],
      'sat': ['sábado', 'sáb', 'sabado'],
      'sun': ['domingo', 'dom'],
    },
  };

  /// 음성 텍스트에서 요일을 추출하여 요일 코드 Set 반환
  /// 매칭된 요일이 없으면 빈 Set 반환
  ///
  /// [text] 음성인식 원본 텍스트
  /// [localeId] 언어 코드 (예: 'ko-KR', 'en-US', 'ja-JP', 'zh-CN')
  ///           null이면 모든 언어에서 검색
  static Set<String> extractWeekdays(String text, {String? localeId}) {
    final normalized = _normalize(text);
    final result = <String>{};

    // 언어 코드 추출 (ko-KR → ko)
    final lang = localeId?.split('-').first.split('_').first.toLowerCase();

    // 검사할 언어 목록
    final langKeys =
        (lang != null && _weekdayKeywords.containsKey(lang))
            ? [lang]
            : _weekdayKeywords.keys.toList();

    for (final l in langKeys) {
      final dayMap = _weekdayKeywords[l]!;
      for (final entry in dayMap.entries) {
        final dayCode = entry.key;
        for (final keyword in entry.value) {
          if (normalized.contains(_normalize(keyword))) {
            result.add(dayCode);
            break;
          }
        }
      }
    }

    return result;
  }

  // ═══════════════════════════════════════════════════════════
  //  날짜 추출
  // ═══════════════════════════════════════════════════════════

  /// 음성 텍스트에서 날짜(월/일)를 추출하여 DateTime 반환
  /// 추출 실패 시 null 반환
  ///
  /// 지원 형식:
  /// - KO: "4월 12일", "4월12일"
  /// - EN: "april 12", "april 12th", "4/12"
  /// - JA: "4月12日", "4月12日"
  /// - ZH: "4月12号", "4月12日"
  static DateTime? extractDate(String text, {String? localeId}) {
    final normalized = _normalize(text);

    // 1. 한국어/일본어: N월 M일 (공백 정규화 후)
    final koJaMatch = RegExp(
      r'(\d{1,2})\s*[월月]\s*(\d{1,2})\s*[일日]',
    ).firstMatch(text);
    if (koJaMatch != null) {
      final month = int.tryParse(koJaMatch.group(1)!);
      final day = int.tryParse(koJaMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 2. 중국어: N月M号 / N月M日
    final zhMatch = RegExp(
      r'(\d{1,2})\s*[月]\s*(\d{1,2})\s*[号日]',
    ).firstMatch(text);
    if (zhMatch != null) {
      final month = int.tryParse(zhMatch.group(1)!);
      final day = int.tryParse(zhMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 3. 숫자 슬래시: M/D
    final slashMatch = RegExp(
      r'\b(\d{1,2})\s*/\s*(\d{1,2})\b',
    ).firstMatch(normalized);
    if (slashMatch != null) {
      final month = int.tryParse(slashMatch.group(1)!);
      final day = int.tryParse(slashMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 4. 영어 월 이름 (월-일 순서): "april 12", "april 12th"
    final enMonthMatch = RegExp(
      r'\b(january|february|march|april|may|june|july|august|september|october|november|december|'
      r'jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b\s*(\d{1,2})(?:st|nd|rd|th)?',
      caseSensitive: false,
    ).firstMatch(text);
    if (enMonthMatch != null) {
      final monthName = enMonthMatch.group(1)!.toLowerCase();
      final day = int.tryParse(enMonthMatch.group(2)!);
      final month = _englishMonthToNumber(monthName);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 5. 영어 일-월 순서: "24th April", "24 April", "the 24th of April"
    final enDayMonthMatch = RegExp(
      r'(?:\bthe\s+)?(\d{1,2})(?:st|nd|rd|th)?\s+(?:of\s+)?(january|february|march|april|may|june|july|august|september|october|november|december|'
      r'jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (enDayMonthMatch != null) {
      final day = int.tryParse(enDayMonthMatch.group(1)!);
      final monthName = enDayMonthMatch.group(2)!.toLowerCase();
      final month = _englishMonthToNumber(monthName);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 6. 독일어: "12. April", "12 April", "am 12. April"
    final deMatch = RegExp(
      r'(?:\bam\s+)?(\d{1,2})\.?\s+'
      r'(januar|februar|märz|maerz|april|mai|juni|juli|august|september|oktober|november|dezember)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (deMatch != null) {
      final day = int.tryParse(deMatch.group(1)!);
      final month = _germanMonthToNumber(deMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 7. 프랑스어: "12 avril", "le 12 avril"
    final frMatch = RegExp(
      r'(?:\ble\s+)?(\d{1,2})\s+'
      r'(janvier|février|fevrier|mars|avril|mai|juin|juillet|août|aout|septembre|octobre|novembre|décembre|decembre)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (frMatch != null) {
      final day = int.tryParse(frMatch.group(1)!);
      final month = _frenchMonthToNumber(frMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 8. 스페인어: "12 de abril", "el 12 de abril"
    final esMatch = RegExp(
      r'(?:\bel\s+)?(\d{1,2})\s+(?:de\s+)?'
      r'(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (esMatch != null) {
      final day = int.tryParse(esMatch.group(1)!);
      final month = _spanishMonthToNumber(esMatch.group(2)!);
      if (month != null && day != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    // 9. EU 점 구분 (DD.MM.): 독일/프랑스/스페인 공통
    final euDotMatch = RegExp(r'\b(\d{1,2})\.(\d{1,2})\.').firstMatch(text);
    if (euDotMatch != null) {
      final day = int.tryParse(euDotMatch.group(1)!);
      final month = int.tryParse(euDotMatch.group(2)!);
      if (day != null && month != null && _isValidDate(month, day)) {
        final now = DateTime.now();
        final dt = DateTime(now.year, month, day);
        return dt.isBefore(DateTime(now.year, now.month, now.day))
            ? DateTime(now.year + 1, month, day)
            : dt;
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  시간 추출
  // ═══════════════════════════════════════════════════════════

  /// 음성 텍스트에서 시간을 추출하여 TimeOfDay 반환
  /// 추출 실패 시 null 반환
  ///
  /// 지원 형식:
  /// - KO: "6시", "오전 9시", "오후 3시 30분", "9시 30분"
  /// - EN: "6 o'clock", "9am", "3:30pm", "at 6"
  /// - JA: "6時", "午前9時", "午後3時30分"
  /// - ZH: "6点", "上午9点", "下午3点30分"
  static TimeOfDay? extractTime(String text, {String? localeId}) {
    // 오전/오후/AM/PM 판별 (P.M., A.M. 등 점 포함 형태도 처리)
    final isPM = _containsAfternoon(text);
    final isAM = _containsMorning(text);

    // 1. 한국어/일본어: N시 M분 / N時M分
    final koJaMatch = RegExp(
      r'(\d{1,2})\s*[시時]\s*(\d{1,2})?\s*[분分]?',
    ).firstMatch(text);
    if (koJaMatch != null) {
      final h = int.tryParse(koJaMatch.group(1)!);
      final m = int.tryParse(koJaMatch.group(2) ?? '0') ?? 0;
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        final hour = _adjustHour(h, isPM: isPM, isAM: isAM);
        return TimeOfDay(hour: hour, minute: m);
      }
    }

    // 2. 중국어: N点M分 / N点
    final zhMatch = RegExp(
      r'(\d{1,2})\s*[点點]\s*(\d{1,2})?\s*[分]?',
    ).firstMatch(text);
    if (zhMatch != null) {
      final h = int.tryParse(zhMatch.group(1)!);
      final m = int.tryParse(zhMatch.group(2) ?? '0') ?? 0;
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        final hour = _adjustHour(h, isPM: isPM, isAM: isAM);
        return TimeOfDay(hour: hour, minute: m);
      }
    }

    // 3. 영어: HH:MM (am/pm 선택) — "5:00 PM", "5:00 P.M.", "5:00pm" 모두 처리
    // 점 제거 버전에서도 검색
    final textNoDot = text.replaceAll('.', '');
    final colonMatch = RegExp(
      r'\b(\d{1,2}):(\d{2})\s*([aApP][mM])?',
    ).firstMatch(textNoDot);
    if (colonMatch != null) {
      final h = int.tryParse(colonMatch.group(1)!);
      final m = int.tryParse(colonMatch.group(2)!);
      final ampm = colonMatch.group(3)?.toLowerCase();
      if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        final pmLocal = ampm == 'pm' || isPM;
        final amLocal = ampm == 'am' || isAM;
        final hour = _adjustHour(h, isPM: pmLocal, isAM: amLocal);
        return TimeOfDay(hour: hour, minute: m);
      }
    }

    // 4. 영어: "N am/pm", "N o'clock", "N PM", "N A.M." 등
    // 점 제거 버전에서 검색
    final enSimpleMatch = RegExp(
      r"\b(\d{1,2})\s*(?:o'clock|o clock|oclock|[aApP][mM])\b",
    ).firstMatch(textNoDot);
    if (enSimpleMatch != null) {
      final h = int.tryParse(enSimpleMatch.group(1)!);
      final suffix = enSimpleMatch.group(0)!.toLowerCase().replaceAll('.', '');
      if (h != null && h >= 1 && h <= 12) {
        final pmLocal = suffix.contains('pm') || isPM;
        final amLocal = suffix.contains('am') || isAM;
        final hour = _adjustHour(h, isPM: pmLocal, isAM: amLocal);
        return TimeOfDay(hour: hour, minute: 0);
      }
    }

    // 5. "after N pm/am" 패턴 — "after 5 pm" 처리
    final afterMatch = RegExp(
      r'\bafter\s+(\d{1,2})(?:\s*(?:pm|am|p\.m\.|a\.m\.))?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (afterMatch != null) {
      final h = int.tryParse(afterMatch.group(1)!);
      if (h != null && h >= 0 && h <= 23) {
        final hour = _adjustHour(h, isPM: isPM, isAM: isAM);
        return TimeOfDay(hour: hour, minute: 0);
      }
    }

    // 6. "at N" 패턴 (영어 단순)
    final atMatch = RegExp(
      r'\bat\s+(\d{1,2})\b',
    ).firstMatch(text.toLowerCase());
    if (atMatch != null) {
      final h = int.tryParse(atMatch.group(1)!);
      if (h != null && h >= 0 && h <= 23) {
        final hour = _adjustHour(h, isPM: isPM, isAM: isAM);
        return TimeOfDay(hour: hour, minute: 0);
      }
    }

    // 7. 독일어: "14 Uhr 30", "14 Uhr", "um 14 Uhr 30"
    final deTimeMatch = RegExp(
      r'(?:\bum\s+)?(\d{1,2})\s*uhr\s*(\d{1,2})?',
      caseSensitive: false,
    ).firstMatch(text);
    if (deTimeMatch != null) {
      final h = int.tryParse(deTimeMatch.group(1)!);
      final m = int.tryParse(deTimeMatch.group(2) ?? '0') ?? 0;
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return TimeOfDay(hour: h, minute: m);
      }
    }

    // 8. 프랑스어: "14h30", "14 h 30", "à 14h", "14 heures 30"
    final frTimeMatch = RegExp(
      r'(?:\bà\s+)?(\d{1,2})\s*(?:heures?|h)\s*(\d{1,2})?',
      caseSensitive: false,
    ).firstMatch(text);
    if (frTimeMatch != null) {
      final h = int.tryParse(frTimeMatch.group(1)!);
      final m = int.tryParse(frTimeMatch.group(2) ?? '0') ?? 0;
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        return TimeOfDay(hour: h, minute: m);
      }
    }

    // 9. 스페인어: "a las 14", "las 2 y media", "a las 3 y 30"
    final esTimeMatch = RegExp(
      r'(?:\ba\s+)?(?:las?\s+)?(\d{1,2})(?:\s+y\s+(\d{1,2}|media|cuarto))?\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (esTimeMatch != null) {
      final h = int.tryParse(esTimeMatch.group(1)!);
      final mStr = esTimeMatch.group(2)?.toLowerCase();
      int m = 0;
      if (mStr == 'media') {
        m = 30;
      } else if (mStr == 'cuarto') {
        m = 15;
      } else if (mStr != null) {
        m = int.tryParse(mStr) ?? 0;
      }
      if (h != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
        final hour = _adjustHour(h, isPM: isPM, isAM: isAM);
        return TimeOfDay(hour: hour, minute: m);
      }
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════
  //  내부 헬퍼
  // ═══════════════════════════════════════════════════════════

  static String _normalize(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// 텍스트에서 오후(PM) 표현 감지
  /// "P.M.", "p.m.", "PM", "pm", "오후", "午後", "下午", "chiều", "บ่าย" 등 처리
  static bool _containsAfternoon(String text) {
    // 점 제거한 버전으로도 검사 (P.M. → pm)
    final t = text.toLowerCase();
    final tNoDot = t.replaceAll('.', '');
    return t.contains('오후') ||
        tNoDot.contains('pm') ||
        t.contains('午後') ||
        t.contains('下午') ||
        t.contains('chiều') || // 베트남어
        t.contains('ตอนบ่าย') || // 태국어
        t.contains('บ่าย') || // 태국어 단축
        t.contains('afternoon') ||
        t.contains('after noon') ||
        // "after N" 패턴 — "after 5" 같은 경우 PM으로 간주하지 않음
        // 단, "in the afternoon", "in the evening" 은 PM
        t.contains('in the afternoon') ||
        t.contains('in the evening') ||
        t.contains('tonight') ||
        t.contains('this evening') ||
        // 말레이어
        t.contains('petang') ||
        t.contains('malam') ||
        // 독일어/프랑스어/스페인어
        t.contains('nachmittag') ||
        t.contains('abend') ||
        t.contains('après-midi') ||
        t.contains('apres-midi') ||
        t.contains('soir') ||
        t.contains('tarde') ||
        t.contains('noche');
  }

  /// 텍스트에서 오전(AM) 표현 감지
  /// "A.M.", "a.m.", "AM", "am", "오전", "午前", "上午" 등 처리
  static bool _containsMorning(String text) {
    final t = text.toLowerCase();
    final tNoDot = t.replaceAll('.', '');
    return t.contains('오전') ||
        tNoDot.contains('am') ||
        t.contains('午前') ||
        t.contains('上午') ||
        t.contains('sáng') || // 베트남어
        t.contains('ตอนเช้า') || // 태국어
        t.contains('เช้า') || // 태국어 단축
        t.contains('morning') ||
        t.contains('in the morning') ||
        // 말레이어
        t.contains('pagi') ||
        // 독일어/프랑스어/스페인어
        t.contains('morgen') ||
        t.contains('vormittag') ||
        t.contains('matin') ||
        t.contains('mañana') ||
        t.contains('manana');
  }

  /// 오전/오후 기반으로 시간 조정
  /// - isPM + h < 12 → h + 12
  /// - isAM + h == 12 → 0 (자정)
  /// - 아무 힌트 없고 h <= 11 → 그대로 (24시간제 기준)
  static int _adjustHour(int h, {required bool isPM, required bool isAM}) {
    if (isPM && h < 12) return h + 12;
    if (isAM && h == 12) return 0;
    return h;
  }

  static bool _isValidDate(int month, int day) {
    if (month < 1 || month > 12) return false;
    if (day < 1 || day > 31) return false;
    const maxDays = [0, 31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return day <= maxDays[month];
  }

  static int? _englishMonthToNumber(String month) {
    const map = {
      'january': 1,
      'jan': 1,
      'february': 2,
      'feb': 2,
      'march': 3,
      'mar': 3,
      'april': 4,
      'apr': 4,
      'may': 5,
      'june': 6,
      'jun': 6,
      'july': 7,
      'jul': 7,
      'august': 8,
      'aug': 8,
      'september': 9,
      'sep': 9,
      'october': 10,
      'oct': 10,
      'november': 11,
      'nov': 11,
      'december': 12,
      'dec': 12,
    };
    return map[month.toLowerCase()];
  }

  static int? _germanMonthToNumber(String month) {
    const map = {
      'januar': 1,
      'februar': 2,
      'märz': 3,
      'maerz': 3,
      'april': 4,
      'mai': 5,
      'juni': 6,
      'juli': 7,
      'august': 8,
      'september': 9,
      'oktober': 10,
      'november': 11,
      'dezember': 12,
    };
    return map[month.toLowerCase()];
  }

  static int? _frenchMonthToNumber(String month) {
    const map = {
      'janvier': 1,
      'février': 2,
      'fevrier': 2,
      'mars': 3,
      'avril': 4,
      'mai': 5,
      'juin': 6,
      'juillet': 7,
      'août': 8,
      'aout': 8,
      'septembre': 9,
      'octobre': 10,
      'novembre': 11,
      'décembre': 12,
      'decembre': 12,
    };
    return map[month.toLowerCase()];
  }

  static int? _spanishMonthToNumber(String month) {
    const map = {
      'enero': 1,
      'febrero': 2,
      'marzo': 3,
      'abril': 4,
      'mayo': 5,
      'junio': 6,
      'julio': 7,
      'agosto': 8,
      'septiembre': 9,
      'octubre': 10,
      'noviembre': 11,
      'diciembre': 12,
    };
    return map[month.toLowerCase()];
  }

  // ═══════════════════════════════════════════════════════════
  //  날짜/시간/요일 키워드 제거 (텍스트 정제)
  // ═══════════════════════════════════════════════════════════

  /// 음성인식 텍스트에서 요일·날짜·시간 표현을 제거하여 반환
  ///
  /// 예: "월요일 6시 이후 회사 도착하면" → "회사 도착하면"
  /// 예: "4월 12일 집에서 나갈 때" → "집에서 나갈 때"
  static String stripDateTimeKeywords(String text, {String? localeId}) {
    String result = text;

    // 0. 요일 바로 앞에 오는 주기 표현만 제거
    //    ("every"는 단독 제거 금지 — "every N hours" 같은 표현이 있을 수 있음)
    //    ko: 매주  |  en: every <요일>  |  ja: 毎週/まいしゅう  |  zh: 每周/每週

    // ko: 매주 + 공백 (뒤에 무엇이 오든 관계없이 — 요일 키워드 제거로 이어짐)
    result = result.replaceAll(RegExp(r'매주\s*'), '');

    // ja: 毎週/まいしゅう + 공백
    result = result.replaceAll(RegExp(r'(?:毎週|まいしゅう)\s*'), '');

    // zh: 每周/每週 + 공백
    result = result.replaceAll(RegExp(r'(?:每周|每週)\s*'), '');

    // en: every 바로 뒤에 요일이 올 때만 제거 (lookahead)
    //     예: "every monday" → "monday"  /  "every 5 minutes" → 그대로
    final enDayPattern =
        r'(?:monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
        r'mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun)';
    result = result.replaceAll(
      RegExp(r'\bevery\s+(?=' + enDayPattern + r'\b)', caseSensitive: false),
      '',
    );

    // de: jede/jeden + 요일
    result = result.replaceAll(
      RegExp(r'(?:jede[ns]?)\s+', caseSensitive: false),
      '',
    );
    // fr: chaque/tous les + 요일
    result = result.replaceAll(
      RegExp(r'(?:chaque|tous\s+les)\s+', caseSensitive: false),
      '',
    );
    // es: cada/todos los + 요일
    result = result.replaceAll(
      RegExp(r'(?:cada|todos\s+los)\s+', caseSensitive: false),
      '',
    );

    // 1. 요일 키워드 제거
    final lang = localeId?.split('-').first.split('_').first.toLowerCase();
    final langKeys =
        (lang != null && _weekdayKeywords.containsKey(lang))
            ? [lang]
            : _weekdayKeywords.keys.toList();
    for (final l in langKeys) {
      final dayMap = _weekdayKeywords[l]!;
      for (final keywords in dayMap.values) {
        // 긴 키워드부터 제거 (부분 매칭 방지)
        final sorted = List<String>.from(keywords)
          ..sort((a, b) => b.length.compareTo(a.length));
        for (final kw in sorted) {
          result = result.replaceAll(
            RegExp(RegExp.escape(kw), caseSensitive: false),
            ' ',
          );
        }
      }
    }

    // 2. 날짜 패턴 제거 (한/일: N월M일, 중: N月M号, 슬래시: M/D, 영어월)
    result = result
        // 한국어/일본어: 4월 12일
        .replaceAll(RegExp(r'\d{1,2}\s*[월月]\s*\d{1,2}\s*[일日]'), ' ')
        // 중국어: 4月12号 / 4月12日
        .replaceAll(RegExp(r'\d{1,2}\s*[月]\s*\d{1,2}\s*[号日]'), ' ')
        // 슬래시: 4/12
        .replaceAll(RegExp(r'\b\d{1,2}\s*/\s*\d{1,2}\b'), ' ')
        // 영어 월이름 + 숫자 (월-일 순서): april 12, april 12th
        .replaceAll(
          RegExp(
            r'\b(?:january|february|march|april|may|june|july|august|'
            r'september|october|november|december|'
            r'jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)'
            r'\s*\d{1,2}(?:st|nd|rd|th)?\b',
            caseSensitive: false,
          ),
          ' ',
        )
        // 영어 일-월 순서 (British): 24th April, the 24th of April
        .replaceAll(
          RegExp(
            r'\b(?:the\s+)?\d{1,2}(?:st|nd|rd|th)?\s+(?:of\s+)?'
            r'(?:january|february|march|april|may|june|july|august|'
            r'september|october|november|december|'
            r'jan|feb|mar|apr|jun|jul|aug|sep|oct|nov|dec)\b',
            caseSensitive: false,
          ),
          ' ',
        );

    // 독일어 날짜: "am 12. April", "12. April"
    result = result.replaceAll(
      RegExp(
        r'\b(?:am\s+)?\d{1,2}\.?\s*(?:januar|februar|m(?:ä|ae)rz|april|mai|juni|juli|august|september|oktober|november|dezember)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    // 프랑스어 날짜: "le 12 avril", "12 avril"
    result = result.replaceAll(
      RegExp(
        r'\b(?:le\s+)?\d{1,2}\s*(?:janvier|f[ée]vrier|mars|avril|mai|juin|juillet|ao[uû]t|septembre|octobre|novembre|d[ée]cembre)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    // 스페인어 날짜: "el 12 de abril", "12 de abril"
    result = result.replaceAll(
      RegExp(
        r'\b(?:el\s+)?\d{1,2}\s*(?:de\s+)?(?:enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)\b',
        caseSensitive: false,
      ),
      ' ',
    );
    // EU 점 구분 날짜: 12.04.
    result = result.replaceAll(RegExp(r'\b\d{1,2}\.\d{1,2}\.'), ' ');

    // 3. 시간 패턴 제거
    result = result
        // 오전/오후 + 시분: 오전 9시 30분, 오후 3시
        .replaceAll(RegExp(r'(?:오전|오후)\s*\d{1,2}\s*시\s*(?:\d{1,2}\s*분)?'), ' ')
        // 시분만: 9시 30분, 6시
        .replaceAll(RegExp(r'\d{1,2}\s*[시時]\s*(?:\d{1,2}\s*[분分])?'), ' ')
        // 중국어: 上午/下午 + N点M分
        .replaceAll(
          RegExp(r'(?:上午|下午|午前|午後)\s*\d{1,2}\s*[点點時]\s*(?:\d{1,2}\s*[分])?'),
          ' ',
        )
        // 중국어 시간만: 6点30分, 6点
        .replaceAll(RegExp(r'\d{1,2}\s*[点點]\s*(?:\d{1,2}\s*[分])?'), ' ')
        // 영어: 5:30 pm, 5:00, 9am, 9 PM
        .replaceAll(
          RegExp(
            r'\b\d{1,2}:\d{2}\s*(?:am|pm|a\.m\.|p\.m\.)?\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r"\b\d{1,2}\s*(?:am|pm|a\.m\.|p\.m\.|o'clock|oclock)\b",
            caseSensitive: false,
          ),
          ' ',
        )
        // "after N", "at N" 패턴
        .replaceAll(RegExp(r'\bafter\s+\d{1,2}\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bat\s+\d{1,2}\b', caseSensitive: false), ' ')
        // 독일어: "um 14 Uhr 30", "14 Uhr"
        .replaceAll(
          RegExp(
            r'(?:\bum\s+)?\d{1,2}\s*uhr\s*(?:\d{1,2})?',
            caseSensitive: false,
          ),
          ' ',
        )
        // 프랑스어: "à 14h30", "14 heures 30"
        .replaceAll(
          RegExp(
            r'(?:\bà\s+)?\d{1,2}\s*(?:heures?|h)\s*(?:\d{1,2})?',
            caseSensitive: false,
          ),
          ' ',
        )
        // 스페인어: "a las 3 y 30", "las 2 y media"
        .replaceAll(
          RegExp(
            r'(?:\ba\s+)?(?:las?\s+)?\d{1,2}(?:\s+y\s+(?:\d{1,2}|media|cuarto))?',
            caseSensitive: false,
          ),
          ' ',
        );

    // 4. 오전/오후 단독 제거 (시간 뒤에 붙었던 것)
    result = result
        .replaceAll(RegExp(r'오전|오후'), ' ')
        .replaceAll(RegExp(r'上午|下午|午前|午後'), ' ')
        .replaceAll(
          RegExp(
            r'\b(?:nachmittag|abend|vormittag|morgens?)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(
            r'\b(?:après-midi|apres-midi|matin|soir)\b',
            caseSensitive: false,
          ),
          ' ',
        )
        .replaceAll(
          RegExp(r'\b(?:tarde|noche|mañana|manana)\b', caseSensitive: false),
          ' ',
        );

    // 5. 이후/later 등 시간 조건 접속어 제거
    result = result
        .replaceAll(RegExp(r'\s*이후\s*', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\bafter\b', caseSensitive: false), ' ');

    // 6. 연속 공백 정리
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();

    return result;
  }
}
