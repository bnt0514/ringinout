/// 다국어 블루투스 연결/해제 키워드 관리 유틸리티
/// 음성인식 텍스트에서 연결/해제 의도를 파악하기 위한 키워드 목록
///
/// 지원 언어: 한국어(ko), 영어(en), 일본어(ja), 중국어(zh)
class DeviceTriggerKeywords {
  /// 연결(Connect) 키워드 - 언어별 맵
  static const Map<String, List<String>> connectKeywords = {
    'ko': [
      // 연결 관련
      '연결', '연결되', '연결될', '연결된', '연결됐',
      '연결하', '연결할', '연결한', '연결했',
      '연결 시', '연결시', '연결되면', '연결될 때', '연결될때',
      // 접속 관련
      '접속', '접속되', '접속될', '접속된', '접속됐',
      '접속하', '접속할', '접속한', '접속했',
      '접속되면', '접속될 때', '접속될때', '접속 시', '접속시',
      // 켜짐/켜기
      '켜지', '켜질', '켜진', '켜졌',
      '켜면', '켜질 때', '켜질때',
      // 잡히면/감지
      '잡히', '잡힐', '잡힌', '잡혔',
      '잡히면', '잡힐 때', '잡힐때',
      '감지', '감지되', '감지될', '감지된', '감지됐',
      '감지되면', '감지될 때', '감지될때',
      // 블루투스 관련
      '블루투스 연결', '블루투스 접속', '블루투스 켜',
      '페어링', '페어링되', '페어링될', '페어링된', '페어링됐',
      '페어링되면', '페어링될 때', '페어링될때',
    ],

    'en': [
      // Connect
      'connect', 'connects', 'connecting', 'connected',
      'connection', 'when connected', 'on connect', 'on connection',
      'gets connected', 'get connected', 'is connected',
      // Pair
      'pair', 'pairs', 'pairing', 'paired',
      'when paired', 'on pair', 'gets paired',
      // Link
      'link', 'links', 'linking', 'linked',
      'when linked', 'gets linked',
      // Join
      'join', 'joins', 'joining', 'joined',
      // Turn on / Switch on
      'turn on', 'turns on', 'turned on', 'turning on',
      'switch on', 'switches on', 'switched on',
      // Detect
      'detect', 'detects', 'detecting', 'detected',
      'when detected', 'on detection',
      // Bluetooth
      'bluetooth connect', 'bluetooth connected',
    ],

    'ja': [
      // 接続
      '接続', '接続する', '接続した', '接続したら', '接続して',
      '接続される', '接続された', '接続されたら',
      'せつぞく', 'つながる', 'つながった', 'つながったら',
      // 繋がる/繋げる
      '繋がる', '繋がった', '繋がったら', '繋がって',
      '繋げる', '繋げた', '繋げたら',
      // ペアリング
      'ペアリング', 'ペアリングする', 'ペアリングした', 'ペアリングしたら',
      // 検出
      '検出', '検出する', '検出した', '検出したら', '検出された',
      // オンにする
      'オンにする', 'オンにした', 'オンになる', 'オンになった', 'オンになったら',
    ],

    'zh': [
      // 连接
      '连接', '连接了', '连接时', '连接的时候', '连上',
      '已连接', '连接上', '连接成功',
      // 配对
      '配对', '配对了', '配对时', '配对成功',
      // 接通
      '接通', '接通了', '接通时',
      // 检测到
      '检测到', '检测', '发现', '发现了',
      // 打开/开启
      '打开', '开启', '开了',
      // 蓝牙
      '蓝牙连接', '蓝牙配对',
    ],
  };

  /// 해제(Disconnect) 키워드 - 언어별 맵
  static const Map<String, List<String>> disconnectKeywords = {
    'ko': [
      // 해제 관련
      '해제', '해제되', '해제될', '해제된', '해제됐',
      '해제하', '해제할', '해제한', '해제했',
      '해제되면', '해제될 때', '해제될때', '해제 시', '해제시',
      // 끊기/끊어짐
      '끊기', '끊길', '끊긴', '끊겼',
      '끊어지', '끊어질', '끊어진', '끊어졌',
      '끊기면', '끊길 때', '끊길때', '끊어지면', '끊어질 때', '끊어질때',
      // 연결 해제
      '연결 해제', '연결해제', '연결 끊', '연결끊',
      '연결이 끊', '연결이끊',
      // 접속 해제/끊김
      '접속 해제', '접속해제', '접속 끊', '접속끊',
      '접속이 끊', '접속이끊',
      // 꺼짐/끄기
      '꺼지', '꺼질', '꺼진', '꺼졌',
      '꺼지면', '꺼질 때', '꺼질때',
      // 사라짐
      '사라지', '사라질', '사라진', '사라졌',
      '사라지면', '사라질 때', '사라질때',
      // 블루투스 관련
      '블루투스 해제', '블루투스 끊', '블루투스 꺼',
    ],

    'en': [
      // Disconnect
      'disconnect', 'disconnects', 'disconnecting', 'disconnected',
      'disconnection', 'when disconnected', 'on disconnect',
      'gets disconnected', 'get disconnected', 'is disconnected',
      // Unpair
      'unpair', 'unpairs', 'unpairing', 'unpaired',
      'when unpaired',
      // Unlink
      'unlink', 'unlinks', 'unlinking', 'unlinked',
      // Lose connection
      'lose connection', 'lost connection', 'loses connection',
      'connection lost', 'connection drops', 'connection dropped',
      // Turn off / Switch off
      'turn off', 'turns off', 'turned off', 'turning off',
      'switch off', 'switches off', 'switched off',
      // Cut off
      'cut off', 'cuts off', 'cutting off',
      // Drop
      'drop', 'drops', 'dropping', 'dropped',
      // Bluetooth
      'bluetooth disconnect', 'bluetooth disconnected',
      'bluetooth off',
    ],

    'ja': [
      // 切断/切れる
      '切断', '切断する', '切断した', '切断したら', '切断して',
      '切断される', '切断された', '切断されたら',
      '切れる', '切れた', '切れたら',
      'せつだん', 'きれる', 'きれた', 'きれたら',
      // 接続解除
      '接続解除', '接続が切れる', '接続が切れた', '接続が切れたら',
      // 繋がらない/繋がり切れ
      '繋がらない', '繋がらなくなった', '繋がらなくなったら',
      // オフにする
      'オフにする', 'オフにした', 'オフになる', 'オフになった', 'オフになったら',
      // 外す/外れる
      '外す', '外した', '外したら', '外れる', '外れた', '外れたら',
      'はずす', 'はずした', 'はずれる', 'はずれた',
    ],

    'zh': [
      // 断开/断连
      '断开', '断开了', '断开时', '断开的时候', '断连',
      '已断开', '断开连接',
      // 解除
      '解除', '解除了', '解除配对', '解除连接',
      // 断了/掉线
      '断了', '掉线', '掉线了', '掉了',
      // 关闭/关掉
      '关闭', '关掉', '关了',
      // 失去连接
      '失去连接', '连接丢失', '连接断开',
      // 蓝牙
      '蓝牙断开', '蓝牙关闭',
    ],
  };

  /// 주어진 텍스트에서 연결 키워드가 포함되어 있는지 확인
  static bool containsConnectKeyword(String text, {String? locale}) {
    final normalizedText = _normalizeText(text);

    if (locale != null) {
      final keywords = connectKeywords[locale] ?? [];
      return keywords.any((kw) => normalizedText.contains(_normalizeText(kw)));
    }

    for (final keywords in connectKeywords.values) {
      if (keywords.any((kw) => normalizedText.contains(_normalizeText(kw)))) {
        return true;
      }
    }
    return false;
  }

  /// 주어진 텍스트에서 해제 키워드가 포함되어 있는지 확인
  static bool containsDisconnectKeyword(String text, {String? locale}) {
    final normalizedText = _normalizeText(text);

    if (locale != null) {
      final keywords = disconnectKeywords[locale] ?? [];
      return keywords.any((kw) => normalizedText.contains(_normalizeText(kw)));
    }

    for (final keywords in disconnectKeywords.values) {
      if (keywords.any((kw) => normalizedText.contains(_normalizeText(kw)))) {
        return true;
      }
    }
    return false;
  }

  /// 텍스트를 정규화 (소문자 변환, 공백 제거)
  static String _normalizeText(String text) {
    return text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  }

  /// 주어진 텍스트에서 연결/해제 트리거 타입 감지
  /// 반환값: 'connect', 'disconnect', null
  static String? detectTriggerType(String text, {String? locale}) {
    final hasConnect = containsConnectKeyword(text, locale: locale);
    final hasDisconnect = containsDisconnectKeyword(text, locale: locale);

    if (hasConnect && hasDisconnect) {
      // 해제 키워드가 더 우선 (연결 해제, 접속 해제 등에서 '연결'도 매칭되므로)
      return 'disconnect';
    }
    if (hasConnect) return 'connect';
    if (hasDisconnect) return 'disconnect';
    return null;
  }

  /// 텍스트에서 연결/해제 트리거 키워드를 제거한 정제 텍스트 반환
  static String stripTriggerKeywords(String text, {String? locale}) {
    String result = text;

    // 제거 대상 언어 결정
    final langKeys =
        (locale != null && connectKeywords.containsKey(locale))
            ? [locale]
            : connectKeywords.keys.toList();

    for (final lang in langKeys) {
      // 연결 키워드 제거 (긴 것부터)
      final cKeywords = List<String>.from(connectKeywords[lang] ?? [])
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final kw in cKeywords) {
        result = result.replaceAll(
          RegExp(RegExp.escape(kw), caseSensitive: false),
          ' ',
        );
      }
      // 해제 키워드 제거 (긴 것부터)
      final dKeywords = List<String>.from(disconnectKeywords[lang] ?? [])
        ..sort((a, b) => b.length.compareTo(a.length));
      for (final kw in dKeywords) {
        result = result.replaceAll(
          RegExp(RegExp.escape(kw), caseSensitive: false),
          ' ',
        );
      }
    }

    // 연속 공백 정리
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }
}
