import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ringinout/services/app_log_buffer.dart';
import 'package:ringinout/services/hive_helper.dart';
import 'package:ringinout/services/location_monitor_service.dart';
import 'package:ringinout/services/smart_location_monitor.dart';

class GpsPage extends StatefulWidget {
  const GpsPage({super.key, this.showAppBar = true});
  final bool showAppBar;

  @override
  State<GpsPage> createState() => _GpsPageState();
}

class _GpsPageState extends State<GpsPage> {
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

  // ── 스누즈/패싱 상태 ──
  List<Map<String, dynamic>> _snoozeEntries = [];

  @override
  void initState() {
    super.initState();
    _startGpsStream();
    _fetchGps();
    _startAutoRefresh();
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
    await _refreshSnoozePassingStatus();
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
    final raw = AppLogBuffer.snapshot(window: const Duration(minutes: 10));
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

  Future<void> _refreshSnoozePassingStatus() async {
    try {
      final box = await Hive.openBox('snoozeSchedules');
      final now = DateTime.now().millisecondsSinceEpoch;
      final snooze = <Map<String, dynamic>>[];

      for (var key in box.keys) {
        final s = box.get(key);
        if (s == null) continue;
        final scheduled = s['scheduledTime'] as int? ?? 0;
        if (scheduled <= now) continue;
        final remainSec = ((scheduled - now) / 1000).round();
        snooze.add({
          'title': s['alarmTitle'] ?? '알람',
          'alarmId': s['alarmId'],
          'remainSec': remainSec,
          'scheduledTime': scheduled,
        });
      }

      if (!mounted) return;
      setState(() {
        _snoozeEntries = snooze;
      });
    } catch (_) {}
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

  String _fmtSec(int sec) {
    if (sec >= 60) {
      final m = sec ~/ 60;
      final s = sec % 60;
      return '$m분 ${s}초';
    }
    return '$sec초';
  }

  Map<String, dynamic>? _getFirstAlarm() {
    final all =
        HiveHelper.alarmBox.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
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
          if (cur != null) {
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
      if (refreshed != null) {
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
    return Scaffold(
      appBar:
          widget.showAppBar
              ? AppBar(
                title: const Text('GPS 디버그'),
                actions: [
                  IconButton(
                    onPressed: _gpsLoading ? null : _fetchGps,
                    icon: const Icon(Icons.my_location),
                    tooltip: 'GPS 갱신',
                  ),
                ],
              )
              : null,
      body: RefreshIndicator(
        onRefresh: _fetchGps,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _buildGpsCard(),
            const SizedBox(height: 12),
            _buildServiceCard(),
            const SizedBox(height: 12),
            _buildPlaceStatesCard(),
            const SizedBox(height: 12),
            _buildForceTestCard(),
            const SizedBox(height: 12),
            _buildSnoozePassingCard(),
            const SizedBox(height: 12),
            _buildLogCard(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ─── 1. 현재 위치 ───

  Widget _buildGpsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '📍 현재 위치',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_pos == null)
              const Text('위치 정보 없음')
            else ...[
              Text('위도: ${_pos!.latitude.toStringAsFixed(6)}'),
              Text('경도: ${_pos!.longitude.toStringAsFixed(6)}'),
              Text('정확도: ${_pos!.accuracy.toStringAsFixed(1)}m'),
              if (_lastGps != null) Text('갱신: ${_fmtTime(_lastGps!)}'),
            ],
          ],
        ),
      ),
    );
  }

  // ─── 2. LMS v3 서비스 상태 ───

  Widget _buildServiceCard() {
    final lms = LocationMonitorService.instance;
    final ps = lms.placeStates;
    final outsideCnt = ps.values.where((s) => s == PlaceState.outside).length;
    final idleCnt = ps.values.where((s) => s == PlaceState.insideIdle).length;
    final movCnt = ps.values.where((s) => s == PlaceState.insideMoving).length;

    String mode;
    Color modeColor;
    if (!_lmsRunning) {
      mode = '⏸ 중지';
      modeColor = Colors.grey;
    } else if (movCnt > 0) {
      mode = '🏃 MOVING ($movCnt)';
      modeColor = Colors.amber.shade700;
    } else if (idleCnt > 0) {
      mode = '📍 IDLE ($idleCnt)';
      modeColor = Colors.green.shade700;
    } else {
      mode = '💤 OUTSIDE ($outsideCnt)';
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
                const Expanded(
                  child: Text(
                    'LMS v3 상태',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                _chip('알람', '$_alarmCount개', Colors.deepPurple),
                _chip('OUTSIDE', '$outsideCnt', Colors.blue),
                _chip('IDLE', '$idleCnt', Colors.green),
                _chip('MOVING', '$movCnt', Colors.amber.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── 3. 장소별 상태 ───

  Widget _buildPlaceStatesCard() {
    final lms = LocationMonitorService.instance;
    final ps = lms.placeStates;
    final places = HiveHelper.getSavedLocations();
    final allAlarms =
        HiveHelper.alarmBox.values
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

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
            const Text(
              '🗺️ 장소별 상태',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            if (ps.isEmpty)
              Text(
                '추적 중인 장소 없음',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else
              ...ps.entries.map((e) {
                final info = infoMap[e.key];
                final aName = info?['name'] ?? '';
                final pName = info?['place'] ?? '';
                final trig = info?['trigger'] ?? 'entry';
                final trigLabel = trig == 'exit' ? '진출' : '진입';
                final shortId =
                    e.key.length > 8 ? e.key.substring(0, 8) : e.key;

                Color c;
                String stateLabel;
                IconData icon;
                switch (e.value) {
                  case PlaceState.outside:
                    c = Colors.blue;
                    stateLabel = 'OUTSIDE';
                    icon = Icons.location_off;
                  case PlaceState.insideIdle:
                    c = Colors.green;
                    stateLabel = 'IDLE';
                    icon = Icons.bedtime;
                  case PlaceState.insideMoving:
                    c = Colors.amber.shade700;
                    stateLabel = 'MOVING';
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
            if (alarm == null)
              const Text(
                '등록된 알람이 없습니다.',
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

  // ─── 5. 스누즈 상태 ───

  Widget _buildSnoozePassingCard() {
    final hasAny = _snoozeEntries.isNotEmpty;

    return Card(
      color: hasAny ? Colors.amber.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '⏰ 스누즈 상태',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await _refreshSnoozePassingStatus();
                    _showSnack('새로고침 완료');
                  },
                  icon: const Icon(Icons.refresh, size: 18),
                  tooltip: '새로고침',
                ),
              ],
            ),
            if (!hasAny)
              Text(
                '대기 중인 스누즈 없음',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            else ...[
              if (_snoozeEntries.isNotEmpty) ...[
                const SizedBox(height: 6),
                const Text(
                  '🔔 다시 울림 (스누즈)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 4),
                ..._snoozeEntries.map(
                  (e) => _scheduleRow(
                    e['title'] as String,
                    e['remainSec'] as int,
                    Colors.blue,
                    '다시 울림 예정',
                  ),
                ),
              ],
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('전체 삭제'),
                          content: const Text('모든 스누즈 스케줄을 삭제하고\n알람을 재활성화합니다.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('취소'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                              ),
                              child: const Text('전체 삭제'),
                            ),
                          ],
                        ),
                  );
                  if (ok == true) {
                    await LocationMonitorService.clearAllSnoozeSchedules();
                    final box = HiveHelper.alarmBox;
                    for (var key in box.keys) {
                      final a = box.get(key);
                      if (a != null && a['enabled'] != true) {
                        final upd = Map<String, dynamic>.from(a);
                        upd['enabled'] = true;
                        upd['snoozePending'] = false;
                        await box.put(key, upd);
                      }
                    }
                    await _refreshSnoozePassingStatus();
                    _showSnack('✅ 전체 삭제 + 알람 재활성화 완료');
                  }
                },
                icon: const Icon(Icons.delete_sweep, size: 16),
                label: const Text('전체 삭제'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleRow(String title, int remainSec, Color color, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: color,
                  ),
                ),
                Text(
                  '$desc · ${_fmtSec(remainSec)} 남음',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Icon(Icons.timer, color: color, size: 18),
        ],
      ),
    );
  }

  // ─── 6. 로그 뷰어 ───

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
                    '실시간 로그 (10분)',
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
