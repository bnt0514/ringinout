// lib/services/hive_helper.dart
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart'; // ✅ 추가
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';
import 'package:ringinout/utils/geocoding_cache.dart';
import 'package:ringinout/utils/report_rate_limiter.dart';

class HiveHelper {
  static late Box _placeBox;
  static late Box _alarmBox;
  static late Box _settingsBox;
  static late Box _deviceAlarmBox; // ✅ 독립형 블루투스 기기 알람 박스
  static late Box _myDevicesBox; // ✅ 내 기기 박스
  static bool _isInitialized = false; // ✅ 초기화 상태 추가
  static const Uuid _uuid = Uuid();
  static String? _activeOwnerUid;
  static const String _activeOwnerKey = 'active_owner_uid';
  static const String _canonicalOwnerResetKey = 'canonical_owner_reset_v1';
  static const String _lastFirebaseUidKey = 'last_firebase_uid_v1';
  static const String _developerLoginOptionsKey = 'developer_login_options_v1';

  static bool get _bluetoothFeaturesEnabled =>
      AppConfig.enableBluetoothFeatures;

  // ✅ 앱 시작 시 반드시 호출해야 함
  static Future<void> init() async {
    if (_isInitialized) return; // ✅ 중복 초기화 방지

    try {
      // ✅ 고유 경로로 초기화 (충돌 방지)
      final appDir = await getApplicationDocumentsDirectory();
      final uniquePath = '${appDir.path}/ringinout_unique_v3'; // ✅ 고유 경로

      await Hive.initFlutter(uniquePath);
      print('📦 Hive 고유 경로 설정: $uniquePath');

      // ✅ 박스 열기 + late 변수에 할당
      if (!Hive.isBoxOpen('savedLocations_v2')) {
        // ✅ 버전 추가로 충돌 방지
        _placeBox = await Hive.openBox('savedLocations_v2');
      } else {
        _placeBox = Hive.box('savedLocations_v2');
      }

      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        // ✅ 버전 추가
        _alarmBox = await Hive.openBox('locationAlarms_v2');
      } else {
        _alarmBox = Hive.box('locationAlarms_v2');
      }

      if (!Hive.isBoxOpen('settings_v2')) {
        // ✅ 버전 추가
        _settingsBox = await Hive.openBox('settings_v2');
      } else {
        _settingsBox = Hive.box('settings_v2');
      }

      // ✅ 독립형 블루투스 기기 알람 박스
      if (!Hive.isBoxOpen('bluetoothDeviceAlarms_v1')) {
        _deviceAlarmBox = await Hive.openBox('bluetoothDeviceAlarms_v1');
      } else {
        _deviceAlarmBox = Hive.box('bluetoothDeviceAlarms_v1');
      }

      // ✅ 내 기기 박스
      if (!Hive.isBoxOpen('myDevices_v1')) {
        _myDevicesBox = await Hive.openBox('myDevices_v1');
      } else {
        _myDevicesBox = Hive.box('myDevices_v1');
      }

      await _runPlaceAlarmMigrations();

      // ✅ 지오코딩 캐시 + 전송 제한 초기화
      await GeocodingCache().init();
      await ReportRateLimiter.init();

      _isInitialized = true; // ✅ 초기화 완료 플래그
      print('📦 HiveHelper 초기화 완료 (고유 경로)');
    } catch (e) {
      print('❌ HiveHelper 초기화 실패: $e');

      // ✅ 락 파일 충돌 시 재시도
      if (e.toString().contains('lock failed')) {
        print('🔄 Hive 락 충돌 감지, 재시도...');
        await _retryWithFallback();
      } else {
        rethrow;
      }
    }
  }

  // ✅ 백그라운드 초기화 (Flutter UI 없는 환경용)
  static Future<void> initBackground() async {
    if (_isInitialized) return;

    try {
      final appDir = await getApplicationDocumentsDirectory();
      final uniquePath = '${appDir.path}/ringinout_unique_v3';

      Hive.init(uniquePath);
      print('📦 Hive 백그라운드 경로 설정: $uniquePath');

      if (!Hive.isBoxOpen('savedLocations_v2')) {
        _placeBox = await Hive.openBox('savedLocations_v2');
      } else {
        _placeBox = Hive.box('savedLocations_v2');
      }

      if (!Hive.isBoxOpen('locationAlarms_v2')) {
        _alarmBox = await Hive.openBox('locationAlarms_v2');
      } else {
        _alarmBox = Hive.box('locationAlarms_v2');
      }

      if (!Hive.isBoxOpen('settings_v2')) {
        _settingsBox = await Hive.openBox('settings_v2');
      } else {
        _settingsBox = Hive.box('settings_v2');
      }

      // ✅ 독립형 블루투스 기기 알람 박스 (백그라운드)
      if (!Hive.isBoxOpen('bluetoothDeviceAlarms_v1')) {
        _deviceAlarmBox = await Hive.openBox('bluetoothDeviceAlarms_v1');
      } else {
        _deviceAlarmBox = Hive.box('bluetoothDeviceAlarms_v1');
      }

      // ✅ 내 기기 박스 (백그라운드)
      if (!Hive.isBoxOpen('myDevices_v1')) {
        _myDevicesBox = await Hive.openBox('myDevices_v1');
      } else {
        _myDevicesBox = Hive.box('myDevices_v1');
      }

      await _runPlaceAlarmMigrations();

      _isInitialized = true;
      print('✅ HiveHelper 백그라운드 초기화 완료');
    } catch (e) {
      print('❌ HiveHelper 백그라운드 초기화 실패: $e');
      rethrow;
    }
  }

  // ✅ 충돌 시 폴백 재시도 — 기존 데이터 유지를 위해 동일 경로/박스명 사용
  static Future<void> _retryWithFallback() async {
    try {
      // ⚠️ 기존 코드는 매번 새 타임스탬프 경로 + _fallback 박스명을 사용하여
      //    기존 알람/장소 데이터가 전부 빈 박스로 교체되는 치명적 버그가 있었음.
      //    동일 경로와 동일 박스명을 사용하여 기존 데이터를 유지한다.
      final appDir = await getApplicationDocumentsDirectory();
      final uniquePath = '${appDir.path}/ringinout_unique_v3'; // ✅ 원본과 동일 경로

      // 짧은 지연 후 재시도 (락 파일 해제 대기)
      await Future.delayed(const Duration(milliseconds: 500));

      await Hive.initFlutter(uniquePath);
      print('🔄 동일 경로로 폴백 재시도: $uniquePath');

      // ✅ 원본과 동일한 박스명 사용 → 기존 데이터 보존
      _placeBox = await Hive.openBox('savedLocations_v2');
      _alarmBox = await Hive.openBox('locationAlarms_v2');
      _settingsBox = await Hive.openBox('settings_v2');
      _deviceAlarmBox = await Hive.openBox('bluetoothDeviceAlarms_v1');

      _isInitialized = true;
      print('✅ 폴백 초기화 성공 (기존 데이터 유지)');
    } catch (e) {
      print('❌ 폴백 초기화도 실패: $e');
      rethrow;
    }
  }

  // ✅ 안전한 getter들 (초기화 체크 포함)
  static Box get placeBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _placeBox;
  }

  static Box get alarmBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _alarmBox;
  }

  static Box get settingsBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _settingsBox;
  }

  /// ✅ 독립형 블루투스 기기 알람 박스
  static Box get deviceAlarmBox {
    if (!_isInitialized) {
      throw StateError('HiveHelper가 초기화되지 않았습니다. init()을 먼저 호출하세요.');
    }
    return _deviceAlarmBox;
  }

  // ✅ 초기화 상태 확인
  static bool get isInitialized => _isInitialized;

  static String? get activeOwnerUid => storedActiveOwnerUid;

  static String? get storedActiveOwnerUid {
    final cached = _activeOwnerUid;
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final saved = _settingsBox.get(_activeOwnerKey)?.toString();
      if (saved != null && saved.isNotEmpty) {
        _activeOwnerUid = saved;
        return saved;
      }
    } catch (_) {}
    return null;
  }

  static bool get hasStoredActiveOwnerUid {
    final stored = storedActiveOwnerUid;
    return stored != null && stored.isNotEmpty;
  }

  static bool needsCanonicalOwnerReset(String canonicalOwnerUid) {
    if (!_isInitialized || canonicalOwnerUid.isEmpty) return false;
    final doneFor = _settingsBox.get(_canonicalOwnerResetKey)?.toString();
    return doneFor != canonicalOwnerUid;
  }

  static String? get lastFirebaseUid {
    if (!_isInitialized) return null;
    final uid = _settingsBox.get(_lastFirebaseUidKey)?.toString().trim();
    return uid == null || uid.isEmpty ? null : uid;
  }

  static Future<void> setLastFirebaseUid(String? uid) async {
    if (!_isInitialized) return;
    if (uid == null || uid.isEmpty) {
      await _settingsBox.delete(_lastFirebaseUidKey);
    } else {
      await _settingsBox.put(_lastFirebaseUidKey, uid);
    }
  }

  static bool get showDeveloperLoginOptions {
    if (!_isInitialized) return false;
    return _settingsBox.get(_developerLoginOptionsKey) == true;
  }

  static Future<void> setDeveloperLoginOptions(bool enabled) async {
    if (!_isInitialized) return;
    if (enabled) {
      await _settingsBox.put(_developerLoginOptionsKey, true);
    } else {
      await _settingsBox.delete(_developerLoginOptionsKey);
    }
  }

  static bool hasAnyAccountScopedLocalData() {
    if (!_isInitialized) return false;
    return _placeBox.isNotEmpty ||
        _alarmBox.isNotEmpty ||
        _deviceAlarmBox.isNotEmpty;
  }

  static Future<void> resetAccountScopedLocalDataForCanonicalOwner(
    String canonicalOwnerUid,
  ) async {
    if (!_isInitialized || canonicalOwnerUid.isEmpty) return;
    if (!needsCanonicalOwnerReset(canonicalOwnerUid)) return;

    await setActiveOwnerUid(canonicalOwnerUid);
    await reassignAllLocalDataToCurrentOwner();

    try {
      final triggerBox = await Hive.openBox('trigger_counts_v2');
      final snoozeBox = await Hive.openBox('snoozeSchedules');
      await triggerBox.clear();
      await snoozeBox.clear();
    } catch (e) {
      debugPrint('account-scoped runtime box clear failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final runtimePrefixes = <String>[
      'alarm_name_',
      'alarm_disabled_',
      'alarm_snoozed_',
      'place_state_',
      'cooldown_until_',
      'alarm_triggered_date_',
      'pause_until_entry_',
      'pause_until_exit_',
      'trigger_count_',
      'native_alarm_',
      'snooze_',
    ];
    for (final key in prefs.getKeys().toList()) {
      if (runtimePrefixes.any((prefix) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
    }

    await _settingsBox.put(_canonicalOwnerResetKey, canonicalOwnerUid);
    debugPrint('Account-scoped runtime data reset for canonical owner');
  }

  static Future<void> clearAllAccountScopedLocalData() async {
    if (!_isInitialized) return;
    await _placeBox.clear();
    await _alarmBox.clear();
    await _deviceAlarmBox.clear();
    await _myDevicesBox.clear();

    try {
      final triggerBox = await Hive.openBox('trigger_counts_v2');
      final snoozeBox = await Hive.openBox('snoozeSchedules');
      await triggerBox.clear();
      await snoozeBox.clear();
    } catch (e) {
      debugPrint('account-scoped runtime box clear failed: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    final runtimePrefixes = <String>[
      'alarm_name_',
      'alarm_disabled_',
      'alarm_snoozed_',
      'place_state_',
      'cooldown_until_',
      'alarm_triggered_date_',
      'pause_until_entry_',
      'pause_until_exit_',
      'trigger_count_',
      'native_alarm_',
      'snooze_',
    ];
    for (final key in prefs.getKeys().toList()) {
      if (runtimePrefixes.any((prefix) => key.startsWith(prefix))) {
        await prefs.remove(key);
      }
    }

    await setActiveOwnerUid(null);
    await _settingsBox.delete(_canonicalOwnerResetKey);
    await _settingsBox.delete(_lastFirebaseUidKey);
  }

  static Future<void> setActiveOwnerUid(String? uid) async {
    _activeOwnerUid = uid;
    if (!_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    if (uid == null || uid.isEmpty) {
      await _settingsBox.delete(_activeOwnerKey);
      await prefs.remove(_activeOwnerKey);
    } else {
      await _settingsBox.put(_activeOwnerKey, uid);
      await prefs.setString(_activeOwnerKey, uid);
      await attachLegacyLocalDataToCurrentOwner();
    }
  }

  static bool isOwnedByCurrentUser(Map<String, dynamic> data) {
    final uid = activeOwnerUid;
    if (uid == null || uid.isEmpty) return false;
    return data['ownerUid']?.toString() == uid;
  }

  static Map<String, dynamic> _withCurrentOwner(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);
    final uid = activeOwnerUid;
    final existingOwner = normalized['ownerUid']?.toString().trim();
    if ((existingOwner == null || existingOwner.isEmpty) &&
        uid != null &&
        uid.isNotEmpty) {
      normalized['ownerUid'] = uid;
    }
    return normalized;
  }

  static Future<void> attachLegacyLocalDataToCurrentOwner() async {
    final uid = activeOwnerUid;
    if (uid == null || uid.isEmpty || !_isInitialized) return;

    var changed = false;
    for (var index = 0; index < _placeBox.length; index++) {
      final raw = _placeBox.getAt(index);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final owner = data['ownerUid']?.toString().trim();
      if (owner == null || owner.isEmpty) {
        data['ownerUid'] = uid;
        await _placeBox.putAt(index, data);
        changed = true;
      }
    }

    for (final key in _alarmBox.keys.toList()) {
      final raw = _alarmBox.get(key);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final owner = data['ownerUid']?.toString().trim();
      if (owner == null || owner.isEmpty) {
        data['ownerUid'] = uid;
        await _alarmBox.put(key, data);
        changed = true;
      }
    }

    for (final key in _deviceAlarmBox.keys.toList()) {
      final raw = _deviceAlarmBox.get(key);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      final owner = data['ownerUid']?.toString().trim();
      if (owner == null || owner.isEmpty) {
        data['ownerUid'] = uid;
        await _deviceAlarmBox.put(key, data);
        changed = true;
      }
    }

    if (changed) {
      debugPrint('📦 Legacy local alarms/places attached to current user');
    }
  }

  static Map<String, Map<String, int>> getLocalOwnerSummary() {
    final summary = <String, Map<String, int>>{};

    Map<String, int> bucket(String ownerUid) => summary.putIfAbsent(
      ownerUid,
      () => {'places': 0, 'alarms': 0, 'devices': 0},
    );

    String ownerOf(dynamic raw) {
      if (raw is! Map) return '(invalid)';
      final owner = raw['ownerUid']?.toString().trim();
      return owner == null || owner.isEmpty ? '(none)' : owner;
    }

    for (var index = 0; index < _placeBox.length; index++) {
      final owner = ownerOf(_placeBox.getAt(index));
      final counts = bucket(owner);
      counts['places'] = (counts['places'] ?? 0) + 1;
    }
    for (final key in _alarmBox.keys) {
      final owner = ownerOf(_alarmBox.get(key));
      final counts = bucket(owner);
      counts['alarms'] = (counts['alarms'] ?? 0) + 1;
    }
    for (final key in _deviceAlarmBox.keys) {
      final owner = ownerOf(_deviceAlarmBox.get(key));
      final counts = bucket(owner);
      counts['devices'] = (counts['devices'] ?? 0) + 1;
    }
    return summary;
  }

  static Future<Map<String, int>> reassignAllLocalDataToCurrentOwner() async {
    final uid = activeOwnerUid;
    if (uid == null || uid.isEmpty || !_isInitialized) {
      return {'places': 0, 'alarms': 0, 'devices': 0};
    }

    var places = 0;
    var alarms = 0;
    var devices = 0;

    for (var index = 0; index < _placeBox.length; index++) {
      final raw = _placeBox.getAt(index);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (data['ownerUid']?.toString() == uid) continue;
      data['ownerUid'] = uid;
      await _placeBox.putAt(index, data);
      places++;
    }

    for (final key in _alarmBox.keys.toList()) {
      final raw = _alarmBox.get(key);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (data['ownerUid']?.toString() == uid) continue;
      data['ownerUid'] = uid;
      await _alarmBox.put(key, data);
      alarms++;
    }

    for (final key in _deviceAlarmBox.keys.toList()) {
      final raw = _deviceAlarmBox.get(key);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (data['ownerUid']?.toString() == uid) continue;
      data['ownerUid'] = uid;
      await _deviceAlarmBox.put(key, data);
      devices++;
    }

    return {'places': places, 'alarms': alarms, 'devices': devices};
  }

  static List<MapEntry<int, Map<String, dynamic>>> getVisiblePlaceEntries() {
    final entries = <MapEntry<int, Map<String, dynamic>>>[];
    for (var index = 0; index < _placeBox.length; index++) {
      final raw = _placeBox.getAt(index);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (isOwnedByCurrentUser(data)) {
        entries.add(MapEntry(index, _normalizePlaceRecord(data)));
      }
    }
    return entries;
  }

  static List<MapEntry<int, Map<String, dynamic>>> getVisibleAlarmEntries() {
    final entries = <MapEntry<int, Map<String, dynamic>>>[];
    for (var index = 0; index < _alarmBox.length; index++) {
      final raw = _alarmBox.getAt(index);
      if (raw is! Map) continue;
      final data = Map<String, dynamic>.from(raw);
      if (isOwnedByCurrentUser(data)) {
        entries.add(MapEntry(index, _normalizeAlarmRecord(data)));
      }
    }
    return entries;
  }

  // ✅ MyPlaces 관련 (안전한 접근)
  static List<Map<String, dynamic>> getSavedLocations() {
    try {
      return getVisiblePlaceEntries().map((entry) => entry.value).toList();
    } catch (e) {
      debugPrint('❌ getSavedLocations 에러: $e');
      return [];
    }
  }

  /// 장소에 Wi-Fi 네트워크가 등록되어 있는지 확인
  static bool placeHasWifi(Map<String, dynamic> place) {
    final wifi = place['wifiNetworks'];
    return wifi is List && wifi.isNotEmpty;
  }

  /// 장소에 블루투스 기기가 등록되어 있는지 확인
  static bool placeHasBluetooth(Map<String, dynamic> place) {
    final bt = place['bluetoothDevices'];
    return bt is List && bt.isNotEmpty;
  }

  /// placeId로 해당 장소의 블루투스 기기 목록 가져오기
  static List<Map<String, dynamic>> getBluetoothDevicesForPlace(
    String placeId,
  ) {
    try {
      final places = getSavedLocations();
      final place = places.firstWhere(
        (p) => p['id']?.toString() == placeId,
        orElse: () => <String, dynamic>{},
      );
      if (place.isEmpty) return [];
      final bt = place['bluetoothDevices'];
      if (bt is List) {
        return bt.map((d) => Map<String, dynamic>.from(d as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ getBluetoothDevicesForPlace 에러: $e');
      return [];
    }
  }

  /// placeId로 해당 장소의 Wi-Fi 네트워크 목록 가져오기
  static List<Map<String, dynamic>> getWifiNetworksForPlace(String placeId) {
    try {
      final places = getSavedLocations();
      final place = places.firstWhere(
        (p) => p['id']?.toString() == placeId,
        orElse: () => <String, dynamic>{},
      );
      if (place.isEmpty) return [];
      final wifi = place['wifiNetworks'];
      if (wifi is List) {
        return wifi.map((w) => Map<String, dynamic>.from(w as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('❌ getWifiNetworksForPlace 에러: $e');
      return [];
    }
  }

  static Future<void> addLocationAlarm(Map<String, dynamic> alarmData) async {
    try {
      final String id = await saveLocationAlarm(alarmData);
      debugPrint('✅ 위치 알람 저장 완료 (ID: $id)');
      debugPrint('📦 현재 알람 목록: ${_alarmBox.values.toList()}');
    } catch (e) {
      debugPrint('❌ addLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static Future<void> addLocation(Map<String, dynamic> location) async {
    try {
      final normalizedLocation = _normalizePlaceRecord(
        _withCurrentOwner(location),
      );
      await _placeBox.add(normalizedLocation);
      debugPrint('✅ Hive에 저장 완료: $normalizedLocation');
      debugPrint('📦 현재 Hive 상태 (저장 후): ${_placeBox.values.toList()}');
    } catch (e) {
      debugPrint('❌ addLocation 에러: $e');
      rethrow;
    }
  }

  static Future<void> updateLocationAt(
    int index,
    Map<String, dynamic> newLocation,
  ) async {
    try {
      final box = placeBox;
      if (index >= 0 && index < box.length) {
        final existing = Map<String, dynamic>.from(box.getAt(index) as Map);
        final normalizedLocation = _normalizePlaceRecord(
          _withCurrentOwner(newLocation),
          fallbackId: existing['id']?.toString(),
        );
        await box.putAt(index, normalizedLocation);
        await _syncLinkedAlarmsForPlaceUpdate(existing, normalizedLocation);
      }
    } catch (e) {
      debugPrint('❌ updateLocationAt 에러: $e');
      rethrow;
    }
  }

  static Future<void> deleteLocation(int index) async {
    try {
      await _placeBox.deleteAt(index);
    } catch (e) {
      debugPrint('❌ deleteLocation 에러: $e');
      rethrow;
    }
  }

  /// 장소에 연결된 알람 수를 반환합니다.
  static int getLinkedAlarmCount(int placeIndex) {
    try {
      final place = Map<String, dynamic>.from(_placeBox.getAt(placeIndex));
      final placeId = place['id']?.toString() ?? '';
      final placeName = place['name']?.toString() ?? '';
      if (placeId.isEmpty && placeName.isEmpty) return 0;

      int count = 0;
      for (final alarm in _alarmBox.values) {
        final a = Map<String, dynamic>.from(alarm);
        if (!isOwnedByCurrentUser(a)) continue;
        final aPlaceId = a['placeId']?.toString() ?? '';
        final aPlaceName = a['placeName']?.toString() ?? '';
        if ((placeId.isNotEmpty && aPlaceId == placeId) ||
            (placeId.isEmpty &&
                placeName.isNotEmpty &&
                aPlaceName == placeName)) {
          count++;
        }
      }
      return count;
    } catch (e) {
      debugPrint('❌ getLinkedAlarmCount 에러: $e');
      return 0;
    }
  }

  /// 장소를 삭제하면서 연결된 알람도 모두 함께 삭제합니다.
  static Future<void> deleteLocationWithLinkedAlarms(int index) async {
    try {
      final place = Map<String, dynamic>.from(_placeBox.getAt(index));
      if (!isOwnedByCurrentUser(place)) {
        throw StateError('Cannot delete a place owned by another account.');
      }
      final placeId = place['id']?.toString() ?? '';
      final placeName = place['name']?.toString() ?? '';

      // 1) 연결된 알람 ID 수집
      final alarmKeysToDelete = <dynamic>[];
      for (final key in _alarmBox.keys) {
        final alarm = Map<String, dynamic>.from(_alarmBox.get(key));
        if (!isOwnedByCurrentUser(alarm)) continue;
        final aPlaceId = alarm['placeId']?.toString() ?? '';
        final aPlaceName = alarm['placeName']?.toString() ?? '';
        if ((placeId.isNotEmpty && aPlaceId == placeId) ||
            (placeId.isEmpty &&
                placeName.isNotEmpty &&
                aPlaceName == placeName)) {
          alarmKeysToDelete.add(key);
        }
      }

      // 2) 연결된 알람 및 관련 데이터 삭제
      if (alarmKeysToDelete.isNotEmpty) {
        final triggerBox = await Hive.openBox('trigger_counts_v2');
        final snoozeBox = await Hive.openBox('snoozeSchedules');
        final prefs = await SharedPreferences.getInstance();

        for (final alarmKey in alarmKeysToDelete) {
          final alarmId = alarmKey.toString();
          await _alarmBox.delete(alarmKey);
          await triggerBox.delete(alarmId);
          await snoozeBox.delete(alarmId);
          await prefs.remove('alarm_name_$alarmId');
          await prefs.remove('alarm_disabled_$alarmId');
          await prefs.remove('place_state_$alarmId');
          await prefs.remove('cooldown_until_$alarmId');
          await prefs.remove('alarm_triggered_date_$alarmId');
        }
        debugPrint(
          '🗑️ 장소 "${place['name']}" 연결 알람 ${alarmKeysToDelete.length}개 삭제 완료',
        );
      }

      // 3) 장소 삭제
      await _placeBox.deleteAt(index);
      debugPrint('🗑️ 장소 인덱스 $index 삭제 완료');
    } catch (e) {
      debugPrint('❌ deleteLocationWithLinkedAlarms 에러: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> getLocation(int index) {
    try {
      return Map<String, dynamic>.from(_placeBox.getAt(index));
    } catch (e) {
      debugPrint('❌ getLocation 에러: $e');
      return {};
    }
  }

  static int getLength() {
    try {
      return _placeBox.length;
    } catch (e) {
      debugPrint('❌ getLength 에러: $e');
      return 0;
    }
  }

  // ✅ 알람 저장용 - 이미 열린 박스 사용
  static Future<String> saveLocationAlarm(
    Map<String, dynamic> alarmData,
  ) async {
    try {
      final id =
          alarmData['id']?.toString().trim().isNotEmpty == true
              ? alarmData['id'].toString()
              : _uuid.v4();
      final normalizedAlarm = _normalizeAlarmRecord(
        _withCurrentOwner({...alarmData, 'id': id}),
      );

      await _alarmBox.put(id, normalizedAlarm); // 이미 열린 박스 사용
      return id;
    } catch (e) {
      debugPrint('❌ saveLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static List<Map<String, dynamic>> getLocationAlarms() {
    try {
      return getVisibleAlarmEntries().map((entry) => entry.value).toList();
    } catch (e) {
      debugPrint('❌ getLocationAlarms 에러: $e');
      return [];
    }
  }

  static List<Map<String, dynamic>> getActiveAlarmsForMonitoring({
    DateTime? now,
  }) {
    final current = now ?? DateTime.now();
    try {
      final alarms = getLocationAlarms();
      return alarms
          .where((alarm) => alarm['enabled'] == true)
          .where((alarm) => isAlarmActiveForMonitoring(alarm, current))
          .toList();
    } catch (e) {
      debugPrint('❌ getActiveAlarmsForMonitoring 에러: $e');
      return [];
    }
  }

  /// 알람이 현재 모니터링이 필요한지 확인
  /// - 최초 진입/진출 알람 (repeat == null): 항상 활성
  /// - 특정 날짜 알람 (repeat가 ISO8601 문자열): 오늘이 해당 날짜인 경우만 활성
  /// - 요일별 알람 (repeat가 List): 오늘 요일이 포함된 경우만 활성
  static bool isAlarmActiveForMonitoring(
    Map<String, dynamic> alarm,
    DateTime now,
  ) {
    if (alarm['enabled'] != true) return false;

    final repeat = alarm['repeat'];

    // 최초 진입/진출 알람: repeat이 null이면 항상 활성
    if (repeat == null) {
      return true;
    }

    // 특정 날짜 알람: repeat이 ISO8601 문자열
    if (repeat is String) {
      final targetDate = DateTime.tryParse(repeat);
      if (targetDate != null) {
        // 오늘 날짜와 비교 (시간 무시, 날짜만 비교)
        final todayOnly = DateTime(now.year, now.month, now.day);
        final targetOnly = DateTime(
          targetDate.year,
          targetDate.month,
          targetDate.day,
        );
        return todayOnly.isAtSameMomentAs(targetOnly);
      }
      return false; // 파싱 실패 시 비활성
    }

    // 요일별 알람: repeat이 List
    if (repeat is List && repeat.isNotEmpty) {
      final weekdayStr =
          ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'][now.weekday % 7];
      // 구 데이터(한글/일본어/중국어 요일) 호환: 모든 값을 영문 코드로 정규화
      final days = repeat.map((e) => _toWeekdayCode(e.toString())).toList();
      return days.contains(weekdayStr);
    }

    // 빈 리스트인 경우 (요일 선택 없음) - 최초 진입/진출과 동일하게 처리
    if (repeat is List && repeat.isEmpty) {
      return true;
    }

    return true;
  }

  static Future<void> deleteLocationAlarm(int index) async {
    try {
      // ✅ 삭제 전에 알람 ID 가져오기
      final alarm = _alarmBox.getAt(index);
      final alarmId = alarm?['id'];

      await _alarmBox.deleteAt(index);

      // ✅ 관련 데이터도 삭제 (삭제된 알람이 울리는 버그 방지)
      if (alarmId is String) {
        final triggerBox = await Hive.openBox('trigger_counts_v2');
        final snoozeBox = await Hive.openBox('snoozeSchedules');
        final prefs = await SharedPreferences.getInstance();

        await triggerBox.delete(alarmId);
        await snoozeBox.delete(alarmId);
        await prefs.remove('alarm_name_$alarmId');
        await prefs.remove('alarm_disabled_$alarmId');
        await prefs.remove('place_state_$alarmId');
        await prefs.remove('cooldown_until_$alarmId');
        await prefs.remove('alarm_triggered_date_$alarmId');

        print('🗑️ 알람 인덱스 $index (ID: $alarmId) 관련 데이터 삭제 완료');
      }
    } catch (e) {
      debugPrint('❌ deleteLocationAlarm 에러: $e');
      rethrow;
    }
  }

  static Future<void> updateLocationAlarm(
    int index,
    Map<String, dynamic> updatedAlarm,
  ) async {
    try {
      final normalizedAlarm = _normalizeAlarmRecord(
        _withCurrentOwner(updatedAlarm),
      );
      await _alarmBox.putAt(index, normalizedAlarm);
    } catch (e) {
      debugPrint('❌ updateLocationAlarm 에러: $e');
      rethrow;
    }
  }

  // ✅ ID 기반 알람 업데이트 (UUID String으로 업데이트)
  static Future<void> updateLocationAlarmById(
    String id,
    Map<String, dynamic> updatedAlarm,
  ) async {
    try {
      if (!_alarmBox.containsKey(id)) {
        throw Exception('알람 ID를 찾을 수 없습니다: $id');
      }

      // ✅ ID를 키로 사용하여 업데이트 (putAt이 아닌 put 사용)
      final normalizedAlarm = _normalizeAlarmRecord({
        ..._withCurrentOwner(updatedAlarm),
        'id': id,
      });
      await _alarmBox.put(id, normalizedAlarm);
      debugPrint('✅ 알람 업데이트 완료 (ID: $id)');
    } catch (e) {
      debugPrint('❌ updateLocationAlarmById 에러: $e');
      rethrow;
    }
  }

  static Future<void> deleteAlarmById(String id) async {
    try {
      final triggerBox = await Hive.openBox('trigger_counts_v2'); // ✅ 버전 추가
      final snoozeBox = await Hive.openBox('snoozeSchedules'); // ✅ 스누즈 스케줄도 삭제
      final prefs = await SharedPreferences.getInstance();

      await alarmBox.delete(id); // 알람 삭제
      await triggerBox.delete(id); // triggerCount 삭제
      await snoozeBox.delete(id); // ✅ 스누즈 스케줄 삭제 (삭제된 알람이 울리는 버그 방지)
      await prefs.remove('alarm_name_$id'); // 캐시 삭제
      await prefs.remove('alarm_disabled_$id'); // ✅ 비활성화 플래그도 삭제
      await prefs.remove('place_state_$id'); // ✅ v3: stale 상태 정리
      await prefs.remove('cooldown_until_$id'); // ✅ v3: 쿨다운 정리
      await prefs.remove('alarm_triggered_date_$id'); // ✅ 당일 트리거 기록 정리

      print('🗑️ 알람 $id 삭제 완료 (알람 + 트리거 + 스누즈 + 상태 + 캐시)');
    } catch (e) {
      debugPrint('❌ deleteAlarmById 에러: $e');
      rethrow;
    }
  }

  // ✅ FAB 위치 저장
  static Future<void> saveFabPosition(double x, double y) async {
    try {
      await _settingsBox.put('fabX', x);
      await _settingsBox.put('fabY', y);
    } catch (e) {
      debugPrint('❌ saveFabPosition 에러: $e');
      rethrow;
    }
  }

  static Future<Offset> getFabPosition() async {
    try {
      final x = _settingsBox.get('fabX', defaultValue: 300.0);
      final y = _settingsBox.get('fabY', defaultValue: 600.0);
      return Offset(x, y);
    } catch (e) {
      debugPrint('❌ getFabPosition 에러: $e');
      return const Offset(300.0, 600.0);
    }
  }

  // ✅ 알람 설정값 (벨소리, 진동, 다시 울림) 저장/불러오기
  static Future<void> saveAlarmSound(String path) async {
    try {
      await _settingsBox.put('alarmSound', path);
    } catch (e) {
      debugPrint('❌ saveAlarmSound 에러: $e');
      rethrow;
    }
  }

  static String getAlarmSound() {
    try {
      return _settingsBox.get('alarmSound', defaultValue: '기본 알람음');
    } catch (e) {
      debugPrint('❌ getAlarmSound 에러: $e');
      return '기본 알람음';
    }
  }

  static Future<void> saveVibration(String vibration) async {
    try {
      await _settingsBox.put('vibration', vibration);
    } catch (e) {
      debugPrint('❌ saveVibration 에러: $e');
      rethrow;
    }
  }

  static String getVibration() {
    try {
      return _settingsBox.get('vibration', defaultValue: '짧은 진동');
    } catch (e) {
      debugPrint('❌ getVibration 에러: $e');
      return '짧은 진동';
    }
  }

  static Future<void> saveSnooze(String snooze) async {
    try {
      await _settingsBox.put('snooze', snooze);
    } catch (e) {
      debugPrint('❌ saveSnooze 에러: $e');
      rethrow;
    }
  }

  static String getSnooze() {
    try {
      return _settingsBox.get('snooze', defaultValue: '5분 후 1회');
    } catch (e) {
      debugPrint('❌ getSnooze 에러: $e');
      return '5분 후 1회';
    }
  }

  // ✅ 공휴일 국가 설정 (auto 또는 국가코드)
  static String getHolidayCountry() {
    try {
      return _settingsBox.get('holidayCountry', defaultValue: 'auto');
    } catch (e) {
      debugPrint('❌ getHolidayCountry 에러: $e');
      return 'auto';
    }
  }

  static Future<void> setHolidayCountry(String countryCode) async {
    try {
      await _settingsBox.put('holidayCountry', countryCode);
    } catch (e) {
      debugPrint('❌ setHolidayCountry 에러: $e');
      rethrow;
    }
  }

  static Future<void> _runPlaceAlarmMigrations() async {
    try {
      final normalizedPlaces = <Map<String, dynamic>>[];
      var placesChanged = false;

      for (var index = 0; index < _placeBox.length; index++) {
        final rawPlace = _placeBox.getAt(index);
        if (rawPlace is! Map) continue;

        final original = Map<String, dynamic>.from(rawPlace);
        final normalized = _normalizePlaceRecord(original);
        normalizedPlaces.add(normalized);

        if (!_mapsEqual(original, normalized)) {
          await _placeBox.putAt(index, normalized);
          placesChanged = true;
        }
      }

      var alarmsChanged = false;
      for (final key in _alarmBox.keys.toList()) {
        final rawAlarm = _alarmBox.get(key);
        if (rawAlarm is! Map) continue;

        final original = Map<String, dynamic>.from(rawAlarm);
        final normalized = _normalizeAlarmRecord(
          original,
          places: normalizedPlaces,
        );

        if (!_mapsEqual(original, normalized)) {
          await _alarmBox.put(key, normalized);
          alarmsChanged = true;
        }
      }

      if (placesChanged || alarmsChanged) {
        debugPrint(
          '✅ place/alarm 마이그레이션 완료 (placesChanged=$placesChanged, alarmsChanged=$alarmsChanged)',
        );
      }
    } catch (e) {
      debugPrint('❌ place/alarm 마이그레이션 실패: $e');
      rethrow;
    }
  }

  static Map<String, dynamic> _normalizePlaceRecord(
    Map<String, dynamic> place, {
    String? fallbackId,
  }) {
    final normalized = _withCurrentOwner(place);
    final existingId = normalized['id']?.toString().trim();
    normalized['id'] =
        (existingId != null && existingId.isNotEmpty)
            ? existingId
            : ((fallbackId != null && fallbackId.isNotEmpty)
                ? fallbackId
                : _uuid.v4());
    // Wi-Fi 네트워크 데이터 보존 (List<Map> 형태)
    if (normalized.containsKey('wifiNetworks')) {
      final wifi = normalized['wifiNetworks'];
      if (wifi is List) {
        normalized['wifiNetworks'] =
            wifi.map((w) => Map<String, dynamic>.from(w as Map)).toList();
      }
    }
    // ✅ 블루투스 기기 데이터 보존 (List<Map> 형태)
    if (normalized.containsKey('bluetoothDevices')) {
      final bt = normalized['bluetoothDevices'];
      if (bt is List) {
        normalized['bluetoothDevices'] =
            bt.map((d) => Map<String, dynamic>.from(d as Map)).toList();
      }
    }
    return normalized;
  }

  static Map<String, dynamic> _normalizeAlarmRecord(
    Map<String, dynamic> alarm, {
    List<Map<String, dynamic>>? places,
  }) {
    final normalized = _withCurrentOwner(alarm);
    final existingAlarmId = normalized['id']?.toString().trim();
    if (existingAlarmId == null || existingAlarmId.isEmpty) {
      normalized['id'] = _uuid.v4();
    } else {
      // ★ 반드시 String으로 정규화 (Hive 역직렬화 타입 불일치 방지)
      normalized['id'] = existingAlarmId;
    }

    final placeList = places ?? getSavedLocations();
    final currentPlaceId = normalized['placeId']?.toString().trim();
    final currentPlaceName =
        (normalized['place'] ?? normalized['locationName'])?.toString().trim();

    Map<String, dynamic>? matchedPlace;
    if (currentPlaceId != null && currentPlaceId.isNotEmpty) {
      matchedPlace = placeList.cast<Map<String, dynamic>?>().firstWhere(
        (place) => place?['id']?.toString() == currentPlaceId,
        orElse: () => null,
      );
    }

    if (matchedPlace == null &&
        currentPlaceName != null &&
        currentPlaceName.isNotEmpty) {
      matchedPlace = placeList.cast<Map<String, dynamic>?>().firstWhere(
        (place) => place?['name']?.toString() == currentPlaceName,
        orElse: () => null,
      );
    }

    if (matchedPlace != null) {
      normalized['placeId'] = matchedPlace['id']?.toString();
      normalized['place'] = matchedPlace['name'] ?? currentPlaceName ?? '';
    } else if (currentPlaceId != null && currentPlaceId.isNotEmpty) {
      normalized['placeId'] = currentPlaceId;
      if (currentPlaceName != null) {
        normalized['place'] = currentPlaceName;
      }
    }

    // 구 데이터 요일(한글/일본어/중국어 등) → 영문 코드로 정규화
    final repeat = normalized['repeat'];
    if (repeat is List && repeat.isNotEmpty) {
      normalized['repeat'] =
          repeat.map((e) => _toWeekdayCode(e.toString())).toList();
    }

    normalized['detectionMode'] = AlarmDetectionMode.resolve(
      normalized,
      place: matchedPlace,
      places: placeList,
    );

    return normalized;
  }

  static Future<void> _syncLinkedAlarmsForPlaceUpdate(
    Map<String, dynamic> oldPlace,
    Map<String, dynamic> newPlace,
  ) async {
    final placeId = newPlace['id']?.toString();
    final oldName = oldPlace['name']?.toString();
    final newName = newPlace['name']?.toString() ?? '';

    if (placeId == null || placeId.isEmpty) return;

    for (final key in _alarmBox.keys.toList()) {
      final rawAlarm = _alarmBox.get(key);
      if (rawAlarm is! Map) continue;

      final alarm = Map<String, dynamic>.from(rawAlarm);
      final alarmPlaceId = alarm['placeId']?.toString();
      final alarmPlaceName =
          (alarm['place'] ?? alarm['locationName'])?.toString();

      final matchesPlace =
          alarmPlaceId == placeId ||
          (oldName != null && alarmPlaceName == oldName);
      if (!matchesPlace) continue;

      final updatedAlarm =
          Map<String, dynamic>.from(alarm)
            ..['placeId'] = placeId
            ..['place'] = newName;

      if (!_mapsEqual(alarm, updatedAlarm)) {
        await _alarmBox.put(key, updatedAlarm);
      }
    }
  }

  /// 구 데이터(한글/일본어/중국어 요일 등) → 영문 코드 변환 (마이그레이션 호환)
  static const _weekdayCodeMap = <String, String>{
    // Korean
    '일': 'sun',
    '월': 'mon',
    '화': 'tue',
    '수': 'wed',
    '목': 'thu',
    '금': 'fri',
    '토': 'sat',
    // Japanese
    '日': 'sun',
    '月': 'mon',
    '火': 'tue',
    '水': 'wed',
    '木': 'thu',
    '金': 'fri',
    '土': 'sat',
    // Chinese
    '一': 'mon', '二': 'tue', '三': 'wed', '四': 'thu', '五': 'fri', '六': 'sat',
    // English abbreviated (대소문자)
    'Sun': 'sun',
    'Mon': 'mon',
    'Tue': 'tue',
    'Wed': 'wed',
    'Thu': 'thu',
    'Fri': 'fri',
    'Sat': 'sat',
  };

  static String _toWeekdayCode(String val) => _weekdayCodeMap[val] ?? val;

  static bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key) || b[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  // ═══════════════════════════════════════════════════════════
  //  독립형 블루투스 기기 알람 (Device Alarm) CRUD
  // ═══════════════════════════════════════════════════════════

  /// 독립형 기기 알람 저장 (장소 무관, BT 연결/해제 시 알람)
  /// alarmData 필수 필드:
  ///   - name: String (알람 이름)
  ///   - macAddress: String (BT MAC 주소)
  ///   - deviceName: String (BT 기기 이름)
  ///   - trigger: 'connect' | 'disconnect' (연결/해제 시 알람)
  ///   - enabled: bool
  static Future<String> saveDeviceAlarm(Map<String, dynamic> alarmData) async {
    if (!_bluetoothFeaturesEnabled) {
      throw StateError('Bluetooth/device alarms are currently disabled.');
    }
    try {
      final id =
          alarmData['id']?.toString().trim().isNotEmpty == true
              ? alarmData['id'].toString()
              : _uuid.v4();
      final normalized = _withCurrentOwner(alarmData);
      normalized['id'] = id;
      normalized['enabled'] ??= true;
      normalized['trigger'] ??= 'connect';
      normalized['createdAt'] ??= DateTime.now().toIso8601String();

      await _deviceAlarmBox.put(id, normalized);
      debugPrint('✅ 기기 알람 저장 완료 (ID: $id)');
      return id;
    } catch (e) {
      debugPrint('❌ saveDeviceAlarm 에러: $e');
      rethrow;
    }
  }

  /// 모든 독립형 기기 알람 조회
  static List<Map<String, dynamic>> getDeviceAlarms() {
    if (!_bluetoothFeaturesEnabled) return [];
    try {
      return _deviceAlarmBox.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .where(isOwnedByCurrentUser)
          .toList();
    } catch (e) {
      debugPrint('❌ getDeviceAlarms 에러: $e');
      return [];
    }
  }

  /// 활성화된 독립형 기기 알람만 조회
  static List<Map<String, dynamic>> getActiveDeviceAlarms() {
    try {
      return getDeviceAlarms()
          .where((alarm) => alarm['enabled'] == true)
          .toList();
    } catch (e) {
      debugPrint('❌ getActiveDeviceAlarms 에러: $e');
      return [];
    }
  }

  /// 독립형 기기 알람 업데이트 (ID 기반)
  static Future<void> updateDeviceAlarm(
    String id,
    Map<String, dynamic> updatedAlarm,
  ) async {
    if (!_bluetoothFeaturesEnabled) {
      throw StateError('Bluetooth/device alarms are currently disabled.');
    }
    try {
      if (!_deviceAlarmBox.containsKey(id)) {
        throw Exception('기기 알람 ID를 찾을 수 없습니다: $id');
      }
      final normalized = _withCurrentOwner(updatedAlarm);
      normalized['id'] = id;
      await _deviceAlarmBox.put(id, normalized);
      debugPrint('✅ 기기 알람 업데이트 완료 (ID: $id)');
    } catch (e) {
      debugPrint('❌ updateDeviceAlarm 에러: $e');
      rethrow;
    }
  }

  /// 독립형 기기 알람 삭제 (ID 기반)
  static Future<void> deleteDeviceAlarm(String id) async {
    if (!_bluetoothFeaturesEnabled) return;
    try {
      await _deviceAlarmBox.delete(id);
      debugPrint('✅ 기기 알람 삭제 완료 (ID: $id)');
    } catch (e) {
      debugPrint('❌ deleteDeviceAlarm 에러: $e');
      rethrow;
    }
  }

  /// 특정 MAC 주소에 매칭되는 독립형 기기 알람 조회
  static List<Map<String, dynamic>> getDeviceAlarmsByMac(String macAddress) {
    if (!_bluetoothFeaturesEnabled) return [];
    try {
      return getDeviceAlarms()
          .where(
            (alarm) =>
                alarm['macAddress']?.toString().toUpperCase() ==
                macAddress.toUpperCase(),
          )
          .toList();
    } catch (e) {
      debugPrint('❌ getDeviceAlarmsByMac 에러: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════
  //  내 기기 (My Devices) CRUD
  // ═══════════════════════════════════════════════════════════

  static Box get myDevicesBox => _myDevicesBox;

  /// 내 기기 저장 (macAddress 기반 ID)
  static Future<String> saveMyDevice(Map<String, dynamic> deviceData) async {
    if (!_bluetoothFeaturesEnabled) {
      throw StateError('Bluetooth/device alarms are currently disabled.');
    }
    try {
      final mac = (deviceData['macAddress'] ?? '').toString().toUpperCase();
      if (mac.isEmpty) throw Exception('MAC 주소가 비어있습니다');
      final normalized = Map<String, dynamic>.from(deviceData);
      normalized['macAddress'] = mac;
      normalized['createdAt'] ??= DateTime.now().toIso8601String();
      await _myDevicesBox.put(mac, normalized);
      debugPrint('✅ 내 기기 저장 완료 (MAC: $mac)');
      return mac;
    } catch (e) {
      debugPrint('❌ saveMyDevice 에러: $e');
      rethrow;
    }
  }

  /// 모든 내 기기 조회
  static List<Map<String, dynamic>> getMyDevices() {
    if (!_bluetoothFeaturesEnabled) return [];
    try {
      return _myDevicesBox.values
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('❌ getMyDevices 에러: $e');
      return [];
    }
  }

  /// 내 기기 업데이트 (MAC 기반)
  static Future<void> updateMyDevice(
    String mac,
    Map<String, dynamic> updatedDevice,
  ) async {
    if (!_bluetoothFeaturesEnabled) {
      throw StateError('Bluetooth/device alarms are currently disabled.');
    }
    try {
      final key = mac.toUpperCase();
      final normalized = Map<String, dynamic>.from(updatedDevice);
      normalized['macAddress'] = key;
      await _myDevicesBox.put(key, normalized);
      debugPrint('✅ 내 기기 업데이트 완료 (MAC: $key)');
    } catch (e) {
      debugPrint('❌ updateMyDevice 에러: $e');
      rethrow;
    }
  }

  /// 내 기기 삭제
  static Future<void> deleteMyDevice(String mac) async {
    if (!_bluetoothFeaturesEnabled) return;
    try {
      await _myDevicesBox.delete(mac.toUpperCase());
      debugPrint('✅ 내 기기 삭제 완료 (MAC: $mac)');
    } catch (e) {
      debugPrint('❌ deleteMyDevice 에러: $e');
      rethrow;
    }
  }

  /// 내 기기 존재 확인
  static bool hasMyDevice(String mac) {
    if (!_bluetoothFeaturesEnabled) return false;
    return _myDevicesBox.containsKey(mac.toUpperCase());
  }
}
