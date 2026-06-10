import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ringinout/pages/admin_dashboard_page.dart';
import 'package:ringinout/services/app_log_buffer.dart';
import 'package:ringinout/services/force_update_service.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/secure_http_headers.dart';
import 'package:ringinout/services/smart_location_monitor.dart';
import 'package:ringinout/services/app_localizations.dart';
import 'package:ringinout/utils/report_rate_limiter.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
  // ── 개발자 모드 (Firestore 기반) ──
  bool _isDevUser = false;

  // ── GPS ──
  Position? _pos;
  DateTime? _lastGps;
  String? _error;
  bool _gpsLoading = false;
  StreamSubscription<Position>? _posSub;

  // ── 서비스 ──
  bool _lmsRunning = false;
  int _alarmCount = 0;

  // ── 로그 ──
  Timer? _refreshTimer;
  List<String> _logs = [];

  // ── 버그 리포트 ──
  bool _bugReportSending = false;

  @override
  void initState() {
    super.initState();
    _checkDevUser();
    _startGpsStream();
    _fetchGps();
    _startAutoRefresh();
  }

  /// Firestore admin_config/special_users 기반 개발자 여부 체크
  Future<void> _checkDevUser() async {
    try {
      if (kDebugMode || HiveHelper.showDeveloperLoginOptions) {
        if (mounted) setState(() => _isDevUser = true);
        return;
      }

      if (await ForceUpdateService.isCurrentUserSpecialOrDeveloper()) {
        await HiveHelper.setDeveloperLoginOptions(true);
        if (mounted) setState(() => _isDevUser = true);
        return;
      }

      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('special_users')
              .get();
      if (doc.exists) {
        final uids = List<String>.from(doc.data()?['uids'] ?? []);
        final canonicalIds = List<String>.from(
          doc.data()?['canonicalAccountIds'] ?? [],
        );
        final ownerUid = HiveHelper.storedActiveOwnerUid;
        final allowed =
            uids.contains(uid) ||
            (ownerUid != null && canonicalIds.contains(ownerUid));
        if (allowed && mounted) {
          setState(() => _isDevUser = true);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  // ═══════════════════════ GPS ═══════════════════════

  Future<void> _startGpsStream() async {
    if (!await _ensurePerm()) return;
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        distanceFilter: 50,
      ),
    ).listen((p) {
      if (!mounted) return;
      setState(() {
        _pos = p;
        _lastGps = DateTime.now();
        _error = null;
      });
    });
  }

  Future<bool> _ensurePerm() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      if (mounted) setState(() => _error = '위치 권한이 필요합니다.');
      return false;
    }
    return true;
  }

  Future<void> _fetchGps() async {
    if (mounted) {
      setState(() {
        _gpsLoading = true;
        _error = null;
      });
    }
    try {
      if (!await _ensurePerm()) return;
      final p = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _pos = p;
        _lastGps = DateTime.now();
      });
    } catch (e) {
      if (mounted) setState(() => _error = '위치 조회 실패: $e');
    } finally {
      if (mounted) setState(() => _gpsLoading = false);
    }
  }

  // ═══════════════════════ 자동 새로고침 ═══════════════════════

  void _startAutoRefresh() {
    _refresh();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refresh(),
    );
  }

  Future<void> _refresh() async {
    _refreshStatus();
    _refreshLogs();
  }

  void _refreshStatus() {
    try {
      final lms = LocationMonitorService.instance;
      final slm = SmartLocationMonitor.getStatus();
      final active = HiveHelper.getActiveAlarmsForMonitoring();
      final running = lms.isRunning || (slm['isRunning'] as bool? ?? false);
      if (!mounted) return;
      setState(() {
        _lmsRunning = running;
        _alarmCount = active.length;
      });
    } catch (_) {}
  }

  void _refreshLogs() {
    final raw = AppLogBuffer.snapshot(window: const Duration(minutes: 30));
    if (!mounted) return;
    setState(() {
      _logs =
          raw.map((e) {
            final t = e['time'] as String? ?? '';
            final tag = e['tag'] as String? ?? '';
            final msg = e['message'] as String? ?? '';
            final short = t.length >= 19 ? t.substring(11, 19) : t;
            return '$short [$tag] $msg';
          }).toList();
    });
  }

  // ═══════════════════════ 유틸 ═══════════════════════

  String _fmtDist(double m) =>
      m >= 1000
          ? '${(m / 1000).toStringAsFixed(2)} km'
          : '${m.toStringAsFixed(0)} m';

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}:'
      '${t.second.toString().padLeft(2, '0')}';

  Map<String, dynamic>? _getFirstAlarm() {
    final all = HiveHelper.getLocationAlarms();
    return all.isNotEmpty ? all.first : null;
  }

  // ═══════════════════════ 강제 트리거 ═══════════════════════

  Future<void> _onForceAlarmTrigger() async {
    final alarm = _getFirstAlarm();
    if (alarm == null) {
      _showSnack('등록된 알람이 없습니다.');
      return;
    }

    final name = alarm['name'] ?? '알람';

    if (alarm['enabled'] != true) {
      final ok = await showDialog<bool>(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('알람 비활성 상태'),
              content: Text('"$name" 알람이 OFF입니다.\n활성화한 후 트리거할까요?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('활성화 후 트리거'),
                ),
              ],
            ),
      );
      if (ok != true) return;

      final id = alarm['id'];
      if (id != null) {
        try {
          final cur = HiveHelper.alarmBox.get(id);
          if (cur is Map &&
              HiveHelper.isOwnedByCurrentUser(Map<String, dynamic>.from(cur))) {
            final upd = Map<String, dynamic>.from(cur);
            upd['enabled'] = true;
            upd['snoozePending'] = false;
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('cooldown_until_$id');
            await HiveHelper.alarmBox.put(id, upd);
          }
        } catch (e) {
          debugPrint('[GPS] ❌ 알람 활성화 실패: $e');
        }
      }

      final refreshed = HiveHelper.alarmBox.get(alarm['id']);
      if (refreshed is Map &&
          HiveHelper.isOwnedByCurrentUser(
            Map<String, dynamic>.from(refreshed),
          )) {
        await _doTrigger(Map<String, dynamic>.from(refreshed));
      }
    } else {
      await _doTrigger(alarm);
    }
  }

  Future<void> _doTrigger(Map<String, dynamic> alarm) async {
    try {
      await LocationMonitorService.instance.forceTriggerAlarm(alarm);
      _refresh();
      _showSnack('🚨 알람 강제 트리거: ${alarm['name']}');
    } catch (e) {
      _showSnack('❌ 강제 트리거 실패: $e');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ═══════════════════════ BUILD ═══════════════════════

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: Text(l10n.get('page_title_gps')),
                actions: [
                  // 어드민 버튼 — Firestore 기반 개발자 계정만 표시
                  if (_isDevUser)
                    IconButton(
                      onPressed:
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboardPage(),
                            ),
                          ),
                      icon: const Icon(Icons.admin_panel_settings),
                      tooltip: '어드민 대시보드',
                    ),
                  IconButton(
                    onPressed: _gpsLoading ? null : _fetchGps,
                    icon: const Icon(Icons.my_location),
                    tooltip: l10n.get('gps_refresh_tooltip'),
                  ),
                ],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _fetchGps,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // 어드민 카드 — Firestore 기반 개발자 계정일 때 표시
            if (_isDevUser) _buildAdminCard(),
            _buildGpsCard(),
            const SizedBox(height: 12),
            // 서비스 상태 / 장소 상태 / 강제 테스트 / 로그 — 개발자 전용
            if (_isDevUser) ...[
              _buildServiceCard(),
              const SizedBox(height: 12),
              _buildPlaceStatesCard(),
              const SizedBox(height: 12),
              _buildForceTestCard(),
              const SizedBox(height: 12),
              _buildLogCard(),
              const SizedBox(height: 12),
            ],
            _buildBugReportButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── 0. 어드민 카드 (데브 UID용) ───

  Widget _buildAdminCard() {
    return Card(
      color: Colors.red.shade900,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(
          Icons.admin_panel_settings,
          color: Colors.white,
          size: 28,
        ),
        title: const Text(
          '어드민 대시보드',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        subtitle: const Text(
          '맵 사용량 · 킬스위치 · 전체 강제 업로드',
          style: TextStyle(color: Colors.white70, fontSize: 12),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 14,
        ),
        onTap:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AdminDashboardPage()),
            ),
      ),
    );
  }

  // ─── 1. 현재 위치 ───

  Widget _buildGpsCard() {
    final l10n = AppLocalizations.of(context);
    // GPS 정확도 뱃지
    String accLabel = '';
    Color accColor = Colors.green;
    if (_pos != null) {
      final acc = _pos!.accuracy;
      if (acc <= 20) {
        accLabel = l10n.get('gps_accuracy_good');
        accColor = Colors.green;
      } else if (acc <= 50) {
        accLabel = l10n.get('gps_accuracy_fair');
        accColor = Colors.orange;
      } else {
        accLabel = l10n.get('gps_accuracy_poor');
        accColor = Colors.red;
      }
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📍 ${l10n.get('gps_current_location')}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_pos == null)
              Text(l10n.get('gps_no_location'))
            else ...[
              Text(
                '${l10n.get('gps_latitude')}: ${_pos!.latitude.toStringAsFixed(6)}',
              ),
              Text(
                '${l10n.get('gps_longitude')}: ${_pos!.longitude.toStringAsFixed(6)}',
              ),
              Row(
                children: [
                  Text(
                    '${l10n.get('gps_accuracy')}: ${_pos!.accuracy.toStringAsFixed(1)}m',
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: accColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      accLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accColor,
                      ),
                    ),
                  ),
                ],
              ),
              if (_lastGps != null)
                Text('${l10n.get('gps_updated_at')}: ${_fmtTime(_lastGps!)}'),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 2. LMS v3 서비스 상태 ───

  Widget _buildServiceCard() {
    final l10n = AppLocalizations.of(context);
    final lms = LocationMonitorService.instance;
    final ps = lms.placeStates;
    final outsideCnt = ps.values.where((s) => s == PlaceState.outside).length;
    final idleCnt = ps.values.where((s) => s == PlaceState.insideIdle).length;
    final movCnt = ps.values.where((s) => s == PlaceState.insideMoving).length;

    String mode;
    Color modeColor;
    if (!_lmsRunning) {
      mode = '⏸ ${l10n.get('gps_stopped')}';
      modeColor = Colors.grey;
    } else if (movCnt > 0) {
      mode = '🏃 ${l10n.get('gps_moving')} ($movCnt)';
      modeColor = Colors.amber.shade700;
    } else if (idleCnt > 0) {
      mode = '📍 ${l10n.get('gps_inside')} ($idleCnt)';
      modeColor = Colors.green.shade700;
    } else {
      mode = '💤 ${l10n.get('gps_outside')} ($outsideCnt)';
      modeColor = Colors.blue.shade700;
    }

    return Card(
      color: _lmsRunning ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _lmsRunning ? Icons.check_circle : Icons.error,
                  color: _lmsRunning ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.get('gps_alarm_status'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: modeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    mode,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: modeColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip(
                  l10n.get('gps_alarms'),
                  '$_alarmCount',
                  Colors.deepPurple,
                ),
                _chip(l10n.get('gps_outside'), '$outsideCnt', Colors.blue),
                _chip(l10n.get('gps_inside'), '$idleCnt', Colors.green),
                _chip(l10n.get('gps_moving'), '$movCnt', Colors.amber.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. 장소별 상태 ───

  Widget _buildPlaceStatesCard() {
    final l10n = AppLocalizations.of(context);
    final lms = LocationMonitorService.instance;
    final ps = lms.placeStates;
    final places = HiveHelper.getSavedLocations();
    final allAlarms = HiveHelper.getLocationAlarms();

    final infoMap = <String, Map<String, String>>{};
    for (final a in allAlarms) {
      final id = a['id'] as String?;
      if (id == null) continue;
      infoMap[id] = {
        'name': (a['name'] as String?) ?? '',
        'place':
            (a['place'] as String?) ?? (a['locationName'] as String?) ?? '',
        'trigger': (a['trigger'] as String?) ?? 'entry',
      };
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '🗺️ ${l10n.get('gps_place_status')}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                SizedBox(
                  height: 28,
                  width: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    tooltip: l10n.get('gps_place_status_refresh_tooltip'),
                    icon: const Icon(Icons.refresh, color: Colors.blueGrey),
                    onPressed: () async {
                      final lmsInst = LocationMonitorService.instance;
                      final savedPlaces = HiveHelper.getSavedLocations();
                      int updated = 0;
                      for (final p in savedPlaces) {
                        final pid = p['id']?.toString();
                        if (pid != null && pid.isNotEmpty) {
                          await lmsInst.resetPlaceState(pid);
                          updated++;
                        }
                      }
                      if (mounted) {
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              l10n
                                  .get('gps_place_status_updated')
                                  .replaceAll('{count}', '$updated'),
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (ps.isEmpty)
              Text(
                l10n.get('gps_no_tracked_places'),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              ...ps.entries.map((e) {
                final info = infoMap[e.key];
                final aName = info?['name'] ?? '';
                final pName = info?['place'] ?? '';
                final trig = info?['trigger'] ?? 'entry';
                final trigLabel =
                    trig == 'exit'
                        ? l10n.get('gps_exit')
                        : l10n.get('gps_entry');
                final shortId =
                    e.key.length > 8 ? e.key.substring(0, 8) : e.key;

                Color c;
                String stateLabel;
                IconData icon;
                switch (e.value) {
                  case PlaceState.outside:
                    c = Colors.blue;
                    stateLabel = l10n.get('gps_outside');
                    icon = Icons.location_off;
                  case PlaceState.insideIdle:
                    c = Colors.green;
                    stateLabel = l10n.get('gps_inside');
                    icon = Icons.place;
                  case PlaceState.insideMoving:
                    c = Colors.amber.shade700;
                    stateLabel = l10n.get('gps_moving');
                    icon = Icons.directions_walk;
                }

                String distText = '';
                if (_pos != null && pName.isNotEmpty) {
                  final place = places.firstWhere(
                    (p) => p['name'] == pName,
                    orElse: () => <String, dynamic>{},
                  );
                  if (place.isNotEmpty) {
                    final lat = (place['lat'] as num?)?.toDouble() ?? 0.0;
                    final lng = (place['lng'] as num?)?.toDouble() ?? 0.0;
                    if (lat != 0 || lng != 0) {
                      final d = Geolocator.distanceBetween(
                        _pos!.latitude,
                        _pos!.longitude,
                        lat,
                        lng,
                      );
                      final r = (place['radius'] as num?)?.toDouble() ?? 100;
                      distText = ' · ${_fmtDist(d)} (R=${r.toInt()}m)';
                    }
                  }
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: c, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              aName.isNotEmpty
                                  ? '$aName ($trigLabel)'
                                  : shortId,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: c,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '$pName$distText',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          stateLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  // ─── 4. 첫 번째 알람 강제 테스트 ───

  Widget _buildForceTestCard() {
    final alarm = _getFirstAlarm();

    return Card(
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '🧪 알람 강제 테스트',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '첫 번째 알람을 강제 발동 → 알람 종료 / 다시 울림 테스트',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),
            // ── 위치 알람 섹션 ──
            const Text(
              '📍 위치 알람',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
            ),
            const SizedBox(height: 6),
            if (alarm == null)
              const Text(
                '등록된 위치 알람이 없습니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              )
            else
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alarm['name'] ?? '이름 없음',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            children: [
                              _badge(
                                alarm['enabled'] == true ? 'ON' : 'OFF',
                                alarm['enabled'] == true
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                              _badge(
                                (alarm['trigger'] ?? 'entry') == 'exit'
                                    ? '진출'
                                    : '진입',
                                Colors.blue,
                              ),
                              if (alarm['snoozePending'] == true)
                                _badge('스누즈대기', Colors.amber),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${alarm['place'] ?? alarm['locationName'] ?? ''}'
                            ' · ${_shortId(alarm['id'])}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _onForceAlarmTrigger,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      child: const Text(
                        '🚨 발동',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _shortId(dynamic id) {
    final s = id?.toString() ?? '';
    return s.length > 8 ? 'ID: ${s.substring(0, 8)}…' : 'ID: $s';
  }

  // ─── 5. 로그 뷰어 ───

  Widget _buildLogCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.article, color: Colors.blueGrey, size: 18),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    '실시간 로그 (30분)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: _refreshLogs,
                  icon: const Icon(Icons.refresh, size: 16),
                  tooltip: '새로고침',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(8),
              ),
              child:
                  _logs.isEmpty
                      ? const Center(
                        child: Text(
                          '로그 없음',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                      : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(8),
                        itemCount: _logs.length,
                        itemBuilder: (_, i) {
                          final log = _logs[_logs.length - 1 - i];
                          Color c = Colors.white70;
                          if (log.contains('❌') || log.contains('ERROR')) {
                            c = Colors.red.shade300;
                          } else if (log.contains('🚨') || log.contains('🔔')) {
                            c = Colors.amber;
                          } else if (log.contains('✅')) {
                            c = Colors.green.shade300;
                          } else if (log.contains('⚡') || log.contains('🔥')) {
                            c = Colors.orange.shade300;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              log,
                              style: TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                color: c,
                              ),
                            ),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── 6. 버그 리포트 버튼 ───

  Widget _buildBugReportButton() {
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _bugReportSending ? null : _onBugReport,
        icon:
            _bugReportSending
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                : const Icon(Icons.bug_report, size: 18),
        label: Text(
          _bugReportSending
              ? l10n.get('gps_bug_report_sending')
              : l10n.get('gps_bug_report'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  Future<void> _onBugReport() async {
    final l10n = AppLocalizations.of(context);

    // ── 전송 제한 확인 ──
    final limitReason = ReportRateLimiter.canSend('bug_report');
    if (limitReason != null) {
      String msg;
      if (limitReason == 'daily_limit') {
        msg =
            '오늘 최대 ${ReportRateLimiter.maxPerDay}회까지 전송할 수 있습니다.\n'
            '서버 안정성 보호를 위한 조치입니다.';
      } else {
        // cooldown:MM:SS
        final parts = limitReason.split(':');
        msg =
            '${parts[1]}분 ${parts[2]}초 후에 다시 전송할 수 있습니다.\n'
            '서버 안정성 보호를 위해 30분 간격으로 제한됩니다.';
      }
      _showSnack('⏳ $msg');
      return;
    }

    final remaining = ReportRateLimiter.remainingToday('bug_report');

    // 메모 입력 다이얼로그 + 실시간 용량 표시
    final memoCtrl = TextEditingController();
    const int maxMemoBytes = 12 * 1024; // 12KB 메모 제한

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final currentBytes = memoCtrl.text.length * 2; // UTF-16 근사
            final sizeKb = (currentBytes / 1024).toStringAsFixed(1);
            final maxKb = (maxMemoBytes / 1024).toStringAsFixed(0);
            final isOverLimit = currentBytes > maxMemoBytes;

            return AlertDialog(
              title: Text(l10n.get('gps_bug_report_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${l10n.get('gps_bug_report_log_notice')}\n'
                    '${l10n.getWithArgs('report_remaining_count', {'remaining': '$remaining', 'max': '${ReportRateLimiter.maxPerDay}'})}',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Text(
                      l10n.get('gps_bug_report_guide'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: memoCtrl,
                    decoration: InputDecoration(
                      hintText: l10n.get('gps_bug_report_hint'),
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                    maxLines: 4,
                    maxLength: 500,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '메모 용량: ${sizeKb}KB / ${maxKb}KB',
                    style: TextStyle(
                      fontSize: 11,
                      color: isOverLimit ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('취소'),
                ),
                ElevatedButton(
                  onPressed:
                      isOverLimit ? null : () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  child: const Text('전송'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    await _sendBugReport(memoCtrl.text.trim());
  }

  Future<void> _sendBugReport(String memo) async {
    if (!mounted) return;
    setState(() => _bugReportSending = true);
    final l10n = AppLocalizations.of(context);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _showSnack('❌ 로그인이 필요합니다.');
        return;
      }

      final idToken = await user.getIdToken();
      final logs = AppLogBuffer.snapshot(window: const Duration(minutes: 30));

      // 로그를 문자열 리스트로 변환
      final logStrings =
          logs.map((e) {
            final t = e['time'] as String? ?? '';
            final tag = e['tag'] as String? ?? '';
            final msg = e['message'] as String? ?? '';
            return '$t [$tag] $msg';
          }).toList();

      if (logStrings.isEmpty) {
        _showSnack('⚠️ 전송할 로그가 없습니다.');
        return;
      }

      const serverUrl =
          'https://us-central1-ringgo-485705.cloudfunctions.net/submitBugReport';

      final response = await http.post(
        Uri.parse(serverUrl),
        headers: await SecureHttpHeaders.json(idToken: idToken),
        body: jsonEncode({
          'logs': logStrings,
          'deviceInfo': {
            'accuracy':
                _pos != null
                    ? '${_pos!.accuracy.toStringAsFixed(1)}m'
                    : 'unknown',
            'hasGpsSignal': _pos != null,
            'alarmCount': _alarmCount,
            'lmsRunning': _lmsRunning,
          },
          'appVersion': '1.0.0-beta',
          'memo': memo,
        }),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final reportId = body['reportId'] ?? '';
        await ReportRateLimiter.recordSent('bug_report');
        _showSnack(
          '✅ 버그 리포트 전송 완료 (ID: ${reportId.toString().substring(0, 8)}…)',
        );
      } else if (response.statusCode == 429) {
        if (mounted) {
          await showDialog(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('📋 접수 마감'),
                  content: Text(
                    l10n.get('bug_report_monthly_limit'),
                    style: const TextStyle(height: 1.6),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(l10n.get('ok')),
                    ),
                  ],
                ),
          );
        }
      } else {
        _showSnack('❌ 전송 실패: ${response.statusCode}');
      }
    } catch (e) {
      _showSnack('❌ 전송 실패: $e');
    } finally {
      if (mounted) setState(() => _bugReportSending = false);
    }
  }

  // ─── 공용 위젯 ───

  Widget _chip(String label, String value, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }

  Widget _badge(String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: c),
      ),
    );
  }
}
