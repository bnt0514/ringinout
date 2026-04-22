// lib/pages/admin_dashboard_page.dart
// 어드민 전용: 탭 네비게이션 Shell (Maps | 버그리포트 | ...)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';

// ── 버그 리포트 데이터 모델 ──────────────────────────────────────────
class _BugReport {
  final String id;
  final String memo;
  final String severity; // 'error' | 'warn' | 'info'
  final int errorCount;
  final int warnCount;
  final int logCount;
  final List<String> logs;
  final Map<String, dynamic> deviceInfo;
  final String appVersion;
  final DateTime? createdAt;

  const _BugReport({
    required this.id,
    required this.memo,
    required this.severity,
    required this.errorCount,
    required this.warnCount,
    required this.logCount,
    required this.logs,
    required this.deviceInfo,
    required this.appVersion,
    this.createdAt,
  });

  factory _BugReport.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return _BugReport(
      id: doc.id,
      memo: d['memo'] as String? ?? '',
      severity: d['severity'] as String? ?? 'info',
      errorCount: (d['errorCount'] as num?)?.toInt() ?? 0,
      warnCount: (d['warnCount'] as num?)?.toInt() ?? 0,
      logCount: (d['logCount'] as num?)?.toInt() ?? 0,
      logs:
          (d['logs'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      deviceInfo: (d['deviceInfo'] as Map<String, dynamic>?) ?? {},
      appVersion: d['appVersion'] as String? ?? 'unknown',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

// ── 탭 정의 (나중에 탭 추가 시 여기만 수정) ─────────────────────────
class _TabItem {
  final String label;
  final IconData icon;
  const _TabItem(this.label, this.icon);
}

const _kTabs = [
  _TabItem('Maps', Icons.map_outlined),
  _TabItem('버그리포트', Icons.bug_report_outlined),
  _TabItem('설정', Icons.settings_outlined),
];

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedTab = 0;

  // 탭별 GlobalKey — 각 탭 State의 새로고침 메서드 호출용
  final _mapsKey = GlobalKey<_MapsDashboardTabState>();
  final _bugKey = GlobalKey<_BugReportsTabState>();
  final _settingsKey = GlobalKey<_AdminSettingsTabState>();

  void _refreshCurrentTab() {
    switch (_selectedTab) {
      case 0:
        _mapsKey.currentState?.refresh();
        break;
      case 1:
        _bugKey.currentState?.refresh();
        break;
      case 2:
        _settingsKey.currentState?.refresh();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('어드민'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: _refreshCurrentTab,
          ),
        ],
      ),
      // ── 탭 네비게이션 바 ──
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        backgroundColor: Colors.red.shade50,
        indicatorColor: Colors.red.shade200,
        height: 60,
        destinations:
            _kTabs
                .map(
                  (t) =>
                      NavigationDestination(icon: Icon(t.icon), label: t.label),
                )
                .toList(),
      ),
      // ── 탭 콘텐츠 (IndexedStack: 전환 시 상태 유지) ──
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _MapsDashboardTab(key: _mapsKey),
          _BugReportsTab(key: _bugKey),
          _AdminSettingsTab(key: _settingsKey),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 탭 1: Maps 대시보드
// ═══════════════════════════════════════════════════════════════════════
class _MapsDashboardTab extends StatefulWidget {
  const _MapsDashboardTab({super.key});
  @override
  State<_MapsDashboardTab> createState() => _MapsDashboardTabState();
}

class _MapsDashboardTabState extends State<_MapsDashboardTab> {
  MapUsageStats? _stats;
  bool _loading = true;
  String? _error;
  List<WeeklyMapStats> _weeklyHistory = [];
  bool _weeklyLoading = true;
  bool _forceUploadInProgress = false;
  Map<String, int> _geoCounts = {};
  bool _geoLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWeeklyHistory();
    _loadGeoCounts();
  }

  void refresh() {
    _loadStats();
    _loadWeeklyHistory();
    _loadGeoCounts();
  }

  Future<void> _loadGeoCounts() async {
    if (mounted) setState(() => _geoLoading = true);
    final counts = await MapUsageService.getLocalGeocodingCounts();
    if (mounted)
      setState(() {
        _geoCounts = counts;
        _geoLoading = false;
      });
  }

  Future<void> _loadStats() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stats = await MapUsageService.getGlobalStats(forceRefresh: true);
      if (mounted) setState(() => _stats = stats);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleProvider(String provider, bool enabled) async {
    try {
      await MapUsageService.setProviderEnabled(provider, enabled);
      if (mounted) {
        context.read<MapProviderService>().applyKillSwitch();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$provider ${enabled ? "활성화" : "비활성화"} 완료',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: enabled ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      await _loadStats();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _toggleGeocoding(bool enabled) async {
    try {
      await MapUsageService.setGeocodingEnabled(enabled);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '지오코딩 ${enabled ? "활성화 ✅" : "비활성화 🚫"}',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: enabled ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('오류: $e')));
      }
    }
  }

  Future<void> _forceUpload() async {
    try {
      await MapUsageService.forceUpload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firestore 업로드 완료'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('업로드 실패: $e')));
      }
    }
  }

  Future<void> _loadWeeklyHistory() async {
    if (mounted) setState(() => _weeklyLoading = true);
    try {
      final history = await MapUsageService.getWeeklyHistory();
      if (mounted) setState(() => _weeklyHistory = history);
    } finally {
      if (mounted) setState(() => _weeklyLoading = false);
    }
  }

  Future<void> _requestAllUsersUpload() async {
    setState(() => _forceUploadInProgress = true);
    try {
      await MapUsageService.requestAllUsersUpload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 전체 업로드 요청 완료! 5초 후 새로고침합니다...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        await Future.delayed(const Duration(seconds: 5));
        if (mounted) {
          await _loadStats();
          await _loadWeeklyHistory();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _forceUploadInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _buildError();
    return _buildBody();
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _loadStats, child: const Text('재시도')),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final stats = _stats;
    final fmt = NumberFormat('#,###');
    final now = DateTime.now();
    final monthLabel = '${now.year}년 ${now.month.toString().padLeft(2, '0')}월';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 어드민 배너
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withAlpha(25),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: Colors.red),
                const SizedBox(width: 8),
                Text(
                  '어드민 전용  $monthLabel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _forceUpload,
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    color: Colors.red.shade300,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _ProviderCard(
            provider: 'google',
            displayName: 'Google Maps',
            iconColor: const Color(0xFF4285F4),
            icon: Icons.map,
            isEnabled: AppConfig.isGoogleMapsEnabled,
            currentCount: stats?.google ?? 0,
            freeLimit: MapUsageStats.googleFreeLimit,
            fmt: fmt,
            onToggle: (e) => _toggleProvider('google', e),
          ),
          const SizedBox(height: 12),
          _ProviderCard(
            provider: 'naver',
            displayName: 'Naver Maps',
            iconColor: const Color(0xFF03C75A),
            icon: Icons.map_outlined,
            isEnabled: AppConfig.isNaverMapsEnabled,
            currentCount: stats?.naver ?? 0,
            freeLimit: MapUsageStats.naverFreeLimit,
            fmt: fmt,
            onToggle: (e) => _toggleProvider('naver', e),
          ),
          const SizedBox(height: 12),
          _OsmCard(osmCount: stats?.osm ?? 0, fmt: fmt),
          const SizedBox(height: 24),

          // ── 지오코딩 섹션 ──
          _SectionHeader(title: '지오코딩 & 검색 API (이 기기, 이번 달)'),
          const SizedBox(height: 8),
          _GeocodingSection(
            geoCounts: _geoCounts,
            isLoading: _geoLoading,
            isGeocodingEnabled: AppConfig.isGeocodingEnabled,
            fmt: fmt,
            onToggle: _toggleGeocoding,
          ),
          const SizedBox(height: 24),

          _SectionHeader(title: '로컬 누적 (이번 달)'),
          const SizedBox(height: 8),
          _LocalCountRow(provider: 'google', label: 'Google', fmt: fmt),
          const SizedBox(height: 4),
          _LocalCountRow(provider: 'naver', label: 'Naver', fmt: fmt),
          const SizedBox(height: 4),
          _LocalCountRow(provider: 'osm', label: 'OSM', fmt: fmt),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 8),
          Text(
            'Firestore 마지막 조회: ${stats != null ? DateFormat('MM/dd HH:mm').format(stats.fetchedAt.toLocal()) : "없음"}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const Text(
            '캐시 만료: 30분 / Firestore 업로드 주기: 7일',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 24),
          _buildForceUploadSection(),
          const SizedBox(height: 24),
          _buildWeeklyHistorySection(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildForceUploadSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync, color: Colors.orange.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                '전체 사용자 강제 업로드',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '온라인 상태인 모든 기기에게 기록 즉시 업로드를 요청합니다.\n앱 재실행 시 또는 포그라운드 복귀 시 지움이 자동 실행됩니다.',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _forceUploadInProgress ? null : _requestAllUsersUpload,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon:
                  _forceUploadInProgress
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.upload_rounded, size: 20),
              label: Text(
                _forceUploadInProgress
                    ? '요청 중... (5초 후 새로고침)'
                    : '📤 전체 강제 업로드 요청',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyHistorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: '주간 사용량 히스토리'),
        const SizedBox(height: 10),
        if (_weeklyLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else if (_weeklyHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: const Text(
              '주간 데이터 없음 (7일마다 자동 업로드 또는 강제 업로드 후 표시)',
              style: TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          )
        else
          _WeeklyHistoryTable(history: _weeklyHistory),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 탭 2: 버그 리포트
// ═══════════════════════════════════════════════════════════════════════
class _BugReportsTab extends StatefulWidget {
  const _BugReportsTab({super.key});
  @override
  State<_BugReportsTab> createState() => _BugReportsTabState();
}

class _BugReportsTabState extends State<_BugReportsTab> {
  List<_BugReport> _reports = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  DocumentSnapshot? _cursor;

  String? _filter; // null | 'today' | '7d' | '30d'
  DateTime? _filterStart;
  String _filterLabel = '전체';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void refresh() => _load();

  void _applyFilter(String? filter) {
    setState(() {
      _filter = filter;
      switch (filter) {
        case 'today':
          final now = DateTime.now();
          _filterStart = DateTime(now.year, now.month, now.day);
          _filterLabel = '오늘';
          break;
        case '7d':
          _filterStart = DateTime.now().subtract(const Duration(days: 7));
          _filterLabel = '7일';
          break;
        case '30d':
          _filterStart = DateTime.now().subtract(const Duration(days: 30));
          _filterLabel = '30일';
          break;
        default:
          _filterStart = null;
          _filterLabel = '전체';
      }
    });
    _load();
  }

  Query<Map<String, dynamic>> _buildQuery() {
    var q = FirebaseFirestore.instance
        .collection('bug_reports')
        .orderBy('createdAt', descending: true);
    if (_filterStart != null) {
      q = q.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(_filterStart!),
      );
    }
    return q;
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _reports = [];
        _cursor = null;
        _hasMore = true;
      });
    }
    try {
      final snap = await _buildQuery().limit(20).get();
      if (mounted) {
        setState(() {
          _reports = snap.docs.map((d) => _BugReport.fromDoc(d)).toList();
          _cursor = snap.docs.isNotEmpty ? snap.docs.last : null;
          _hasMore = snap.docs.length == 20;
        });
      }
    } catch (e) {
      debugPrint('버그 리포트 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == null) return;
    if (mounted) setState(() => _loadingMore = true);
    try {
      final snap =
          await _buildQuery().startAfterDocument(_cursor!).limit(20).get();
      if (mounted) {
        setState(() {
          _reports.addAll(snap.docs.map((d) => _BugReport.fromDoc(d)));
          _cursor = snap.docs.isNotEmpty ? snap.docs.last : _cursor;
          _hasMore = snap.docs.length == 20;
        });
      }
    } catch (e) {
      debugPrint('버그 리포트 추가 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterOptions = [
      (null, '전체'),
      ('today', '오늘'),
      ('7d', '7일'),
      ('30d', '30일'),
    ];

    return Column(
      children: [
        // ── 필터 바 ──
        Container(
          color: Colors.grey.shade50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Text(
                '기간:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  spacing: 6,
                  children:
                      filterOptions.map((opt) {
                        final (key, label) = opt;
                        final sel = _filter == key;
                        return GestureDetector(
                          onTap: () => _applyFilter(key),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: sel ? Colors.teal : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: sel ? Colors.teal : Colors.grey.shade400,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight:
                                    sel ? FontWeight.bold : FontWeight.normal,
                                color:
                                    sel ? Colors.white : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // ── 리스트 ──
        Expanded(
          child:
              _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _reports.isEmpty
                  ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.bug_report_outlined,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '버그 리포트 없음 ($_filterLabel)',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                  : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _reports.length + 1, // +1 for footer
                    itemBuilder: (ctx, i) {
                      if (i < _reports.length) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _BugReportCard(
                            report: _reports[i],
                            onTap: () => _showLogDialog(_reports[i]),
                          ),
                        );
                      }
                      // Footer
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '$_filterLabel  |  ${_reports.length}건 로드됨${_hasMore ? "  (더 있음 →)" : "  (전체)"}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          if (_hasMore)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _loadingMore ? null : _loadMore,
                                icon:
                                    _loadingMore
                                        ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                        : const Icon(
                                          Icons.expand_more,
                                          size: 18,
                                        ),
                                label: Text(
                                  _loadingMore ? '로딩 중…' : '다음 20개 보기',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                          else
                            Text(
                              '— 모두 불러왔습니다 —',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),
        ),
      ],
    );
  }

  void _showLogDialog(_BugReport r) {
    final timeStr =
        r.createdAt != null
            ? DateFormat('MM/dd HH:mm:ss').format(r.createdAt!.toLocal())
            : '시간 없음';
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Row(
              children: [
                _SeverityBadge(severity: r.severity),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '로그 뷰어  $timeStr',
                    style: const TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child:
                  r.logs.isEmpty
                      ? const Center(child: Text('로그 없음'))
                      : ListView.builder(
                        itemCount: r.logs.length,
                        itemBuilder: (_, i) {
                          final line = r.logs[i];
                          final isError =
                              line.contains('❌') ||
                              line.toLowerCase().contains('[error]') ||
                              line.toLowerCase().contains('fatal');
                          final isWarn =
                              line.contains('⚠️') ||
                              line.toLowerCase().contains('[warn]');
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 1),
                            child: Text(
                              line,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontFamily: 'monospace',
                                color:
                                    isError
                                        ? Colors.red.shade700
                                        : isWarn
                                        ? Colors.orange.shade700
                                        : Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('닫기'),
              ),
            ],
          ),
    );
  }
}

class _WeeklyHistoryTable extends StatelessWidget {
  final List<WeeklyMapStats> history;
  const _WeeklyHistoryTable({required this.history});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,###');
    final currentWeek = _currentWeekKey();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          // 헤더
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(9),
                topRight: Radius.circular(9),
              ),
            ),
            child: const Row(
              children: [
                _WeekCell(text: '주차', isHeader: true, flex: 3),
                _WeekCell(
                  text: 'Google',
                  isHeader: true,
                  color: Color(0xFF4285F4),
                ),
                _WeekCell(
                  text: 'Naver',
                  isHeader: true,
                  color: Color(0xFF03C75A),
                ),
                _WeekCell(
                  text: 'OSM',
                  isHeader: true,
                  color: Color(0xFFFF6B35),
                ),
                _WeekCell(text: '합계', isHeader: true),
              ],
            ),
          ),
          const Divider(height: 1),
          // 데이터 행
          ...history.asMap().entries.map((entry) {
            final i = entry.key;
            final w = entry.value;
            final isCurrent = w.week == currentWeek;
            return Container(
              decoration: BoxDecoration(
                color: isCurrent ? Colors.blue.shade50 : Colors.white,
                borderRadius:
                    i == history.length - 1
                        ? const BorderRadius.only(
                          bottomLeft: Radius.circular(9),
                          bottomRight: Radius.circular(9),
                        )
                        : null,
              ),
              child: Column(
                children: [
                  if (i > 0) const Divider(height: 1),
                  Row(
                    children: [
                      _WeekCell(
                        text: isCurrent ? '${w.week} ★' : w.week,
                        flex: 3,
                        bold: isCurrent,
                      ),
                      _WeekCell(text: fmt.format(w.google)),
                      _WeekCell(text: fmt.format(w.naver)),
                      _WeekCell(text: fmt.format(w.osm)),
                      _WeekCell(text: fmt.format(w.total), bold: true),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static String _currentWeekKey() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final startOfYear = DateTime(monday.year, 1, 1);
    final dayOfYear = monday.difference(startOfYear).inDays + 1;
    final weekNum = ((dayOfYear - 1) ~/ 7) + 1;
    return '${monday.year}-W${weekNum.toString().padLeft(2, '0')}';
  }
}

class _WeekCell extends StatelessWidget {
  final String text;
  final int flex;
  final bool isHeader;
  final bool bold;
  final Color? color;

  const _WeekCell({
    required this.text,
    this.flex = 2,
    this.isHeader = false,
    this.bold = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: isHeader ? 11 : 12,
            fontWeight:
                (isHeader || bold) ? FontWeight.bold : FontWeight.normal,
            color: color ?? (isHeader ? Colors.grey.shade600 : null),
            fontFamily: isHeader ? null : 'monospace',
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  final String provider;
  final String displayName;
  final Color iconColor;
  final IconData icon;
  final bool isEnabled;
  final int currentCount;
  final int freeLimit;
  final NumberFormat fmt;
  final void Function(bool) onToggle;

  const _ProviderCard({
    required this.provider,
    required this.displayName,
    required this.iconColor,
    required this.icon,
    required this.isEnabled,
    required this.currentCount,
    required this.freeLimit,
    required this.fmt,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ratio =
        freeLimit > 0 ? (currentCount / freeLimit).clamp(0.0, 1.0) : 0.0;
    final percent = (ratio * 100).toStringAsFixed(1);
    final is95 = ratio >= 0.95;
    final barColor =
        is95 ? Colors.red : (ratio >= 0.7 ? Colors.orange : Colors.green);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEnabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: is95 ? Colors.red.shade300 : Colors.grey.shade300,
          width: is95 ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      '${fmt.format(currentCount)} / ${fmt.format(freeLimit)} ($percent%)',
                      style: TextStyle(
                        color: barColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Switch(
                    value: isEnabled,
                    onChanged: onToggle,
                    activeThumbColor: iconColor,
                  ),
                  Text(
                    isEnabled ? '활성' : '비활성',
                    style: TextStyle(
                      fontSize: 11,
                      color: isEnabled ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              backgroundColor: Colors.grey.shade200,
              color: barColor,
              minHeight: 8,
            ),
          ),
          if (is95)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: const [
                  Icon(Icons.warning_amber, color: Colors.red, size: 14),
                  SizedBox(width: 4),
                  Text(
                    '95% 초과  자동 비활성화 임박',
                    style: TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _OsmCard extends StatelessWidget {
  final int osmCount;
  final NumberFormat fmt;
  const _OsmCard({required this.osmCount, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B35).withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.public, color: Color(0xFFFF6B35), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OSM (OpenStreetMap)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                Text(
                  '무제한 무료  ${fmt.format(osmCount)}건 (이번 달)',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '항상 ON',
              style: TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalCountRow extends StatefulWidget {
  final String provider;
  final String label;
  final NumberFormat fmt;
  const _LocalCountRow({
    required this.provider,
    required this.label,
    required this.fmt,
  });

  @override
  State<_LocalCountRow> createState() => _LocalCountRowState();
}

class _LocalCountRowState extends State<_LocalCountRow> {
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final c = await MapUsageService.getLocalMonthlyCount(widget.provider);
    if (mounted) setState(() => _count = c);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          '${widget.fmt.format(_count)}건',
          style: const TextStyle(fontFamily: 'monospace'),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade600,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── 버그 리포트 severity 배지 ─────────────────────────────────────────
class _SeverityBadge extends StatelessWidget {
  final String severity;
  const _SeverityBadge({required this.severity});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (severity) {
      'error' => ('ERROR', Colors.red),
      'warn' => ('WARN', Colors.orange),
      _ => ('INFO', Colors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withAlpha(120)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color.shade700,
        ),
      ),
    );
  }
}

// ── 버그 리포트 카드 ───────────────────────────────────────────────────
class _BugReportCard extends StatelessWidget {
  final _BugReport report;
  final VoidCallback onTap;
  const _BugReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final r = report;
    final timeStr =
        r.createdAt != null
            ? DateFormat('MM/dd HH:mm').format(r.createdAt!.toLocal())
            : '--:--';
    final borderColor = switch (r.severity) {
      'error' => Colors.red.shade300,
      'warn' => Colors.orange.shade300,
      _ => Colors.grey.shade300,
    };
    final bgColor = switch (r.severity) {
      'error' => Colors.red.shade50,
      'warn' => Colors.orange.shade50,
      _ => Colors.white,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 상단 행: severity + 시간 + 로그 수
            Row(
              children: [
                _SeverityBadge(severity: r.severity),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (r.errorCount > 0)
                  _CountChip(label: '❌ ${r.errorCount}', color: Colors.red),
                if (r.warnCount > 0) ...[
                  const SizedBox(width: 4),
                  _CountChip(label: '⚠️ ${r.warnCount}', color: Colors.orange),
                ],
                const SizedBox(width: 4),
                _CountChip(label: '📋 ${r.logCount}줄', color: Colors.grey),
              ],
            ),
            // 사용자 메모
            if (r.memo.isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.chat_bubble_outline,
                    size: 13,
                    color: Colors.teal,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      r.memo,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.teal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            // 디바이스 정보 요약
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (r.deviceInfo['gps'] != null)
                  _InfoChip(
                    icon: Icons.location_on,
                    label: 'GPS: ${r.deviceInfo['gps']}',
                  ),
                if (r.deviceInfo['accuracy'] != null)
                  _InfoChip(
                    icon: Icons.radar,
                    label: '정확도: ${r.deviceInfo['accuracy']}m',
                  ),
                if (r.deviceInfo['alarmCount'] != null)
                  _InfoChip(
                    icon: Icons.alarm,
                    label: '알람: ${r.deviceInfo['alarmCount']}개',
                  ),
                if (r.deviceInfo['lmsRunning'] != null)
                  _InfoChip(
                    icon: Icons.monitor_heart,
                    label:
                        'LMS: ${r.deviceInfo['lmsRunning'] == true ? "ON" : "OFF"}',
                    highlight: r.deviceInfo['lmsRunning'] != true,
                  ),
                _InfoChip(icon: Icons.app_settings_alt, label: r.appVersion),
              ],
            ),
            // 탭 안내
            const SizedBox(height: 4),
            const Text(
              '탭하여 전체 로그 보기 →',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CountChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  const _InfoChip({
    required this.icon,
    required this.label,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlight ? Colors.red.shade400 : Colors.grey.shade600;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 탭 3: 어드민 설정
// ═══════════════════════════════════════════════════════════════════════
class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab({super.key});
  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  bool _testLoginEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void refresh() => _loadSettings();

  Future<void> _loadSettings() async {
    setState(() => _loading = true);
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('admin_config')
              .doc('dev_settings')
              .get();
      if (doc.exists && mounted) {
        setState(() {
          _testLoginEnabled = doc.data()?['testLoginEnabled'] == true;
        });
      }
    } catch (e) {
      debugPrint('❌ 설정 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleTestLogin(bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('admin_config')
          .doc('dev_settings')
          .set({'testLoginEnabled': value}, SetOptions(merge: true));
      setState(() => _testLoginEnabled = value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('테스트 로그인: ${value ? "ON ✅" : "OFF 🔒"}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ 설정 저장 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 섹션 헤더
        Text(
          '🔧 개발자 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.red.shade900,
          ),
        ),
        const SizedBox(height: 16),

        // 테스트 로그인 토글
        Card(
          child: SwitchListTile(
            title: const Text('테스트 로그인 허용'),
            subtitle: Text(
              _testLoginEnabled
                  ? '로그인 화면에서 로고 10탭 → 테스트 계정 로그인 가능'
                  : '테스트 로그인 비활성화 (로고 10탭 무시)',
              style: TextStyle(
                color: _testLoginEnabled ? Colors.green : Colors.grey,
                fontSize: 13,
              ),
            ),
            value: _testLoginEnabled,
            onChanged: _toggleTestLogin,
            secondary: Icon(
              _testLoginEnabled ? Icons.lock_open : Icons.lock,
              color: _testLoginEnabled ? Colors.green : Colors.grey,
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 안내 텍스트
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 안내',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                '• 테스트 로그인 OFF 시: 로고 10탭해도 테스트 패널이 나오지 않습니다.\n'
                '• 개발자 기능(GPS 디버그, LMS 상태, 강제 트리거 등)은 Firestore '
                'admin_config/special_users에 등록된 UID만 접근 가능합니다.\n'
                '• 구글 플레이 배포 전 OFF로 설정해주세요.',
                style: TextStyle(fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// 지오코딩 사용량 + 비용 + 킬스위치 섹션
// ═══════════════════════════════════════════════════════════════════════
class _GeocodingSection extends StatelessWidget {
  final Map<String, int> geoCounts;
  final bool isLoading;
  final bool isGeocodingEnabled;
  final NumberFormat fmt;
  final void Function(bool) onToggle;

  const _GeocodingSection({
    required this.geoCounts,
    required this.isLoading,
    required this.isGeocodingEnabled,
    required this.fmt,
    required this.onToggle,
  });

  // 단가 (원/건, USD→KRW 1400 환율 기준 보수적 추정)
  // Google Geocoding API: $5/1K → ₩7/건
  // Google Places Text Search Legacy: $32/1K → ₩45/건
  // Naver Geocoding: ₩4/건 (3K/일 무료 초과분)
  // Naver Reverse Geocoding: ₩4/건 (1K/일 무료 초과분)
  static const double _wonGFwd = 7.0;
  static const double _wonGPlace = 45.0;
  static const double _wonNFwd = 4.0;
  static const double _wonNRev = 4.0;

  @override
  Widget build(BuildContext context) {
    final gFwd = geoCounts['google_fwd'] ?? 0;
    final gPlace = geoCounts['google_place'] ?? 0;
    final nFwd = geoCounts['naver_fwd'] ?? 0;
    final nRev = geoCounts['naver_rev'] ?? 0;

    final costGFwd = gFwd * _wonGFwd;
    final costGPlace = gPlace * _wonGPlace;
    final costNFwd = nFwd * _wonNFwd;
    final costNRev = nRev * _wonNRev;
    final costGoogle = costGFwd + costGPlace;
    final costNaver = costNFwd + costNRev;
    final costTotal = costGoogle + costNaver;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isGeocodingEnabled ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 킬스위치
          Row(
            children: [
              const Icon(Icons.api, color: Colors.purple, size: 22),
              const SizedBox(width: 8),
              const Text(
                '지오코딩 API',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Spacer(),
              Switch(
                value: isGeocodingEnabled,
                onChanged: onToggle,
                activeThumbColor: Colors.purple,
              ),
              Text(
                isGeocodingEnabled ? '활성' : '차단',
                style: TextStyle(
                  fontSize: 11,
                  color: isGeocodingEnabled ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isGeocodingEnabled
                ? '주소/장소 검색 활성 — Google/Naver API 호출됨'
                : '🚫 모든 유료 지오코딩 차단됨 — OSM Nominatim 폴백 사용',
            style: TextStyle(
              fontSize: 11,
              color: isGeocodingEnabled ? Colors.grey : Colors.red,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            _GeoRow(
              label: 'Google Geocoding',
              count: gFwd,
              cost: costGFwd,
              color: const Color(0xFF4285F4),
              fmt: fmt,
              unit: '\$5/1K → ₩7/건',
            ),
            _GeoRow(
              label: 'Google Places Search',
              count: gPlace,
              cost: costGPlace,
              color: const Color(0xFF4285F4),
              fmt: fmt,
              unit: '\$32/1K → ₩45/건',
            ),
            _GeoRow(
              label: 'Naver Geocoding',
              count: nFwd,
              cost: costNFwd,
              color: const Color(0xFF03C75A),
              fmt: fmt,
              unit: '₩4/건 (3K/일 초과분)',
            ),
            _GeoRow(
              label: 'Naver Reverse Geocoding',
              count: nRev,
              cost: costNRev,
              color: const Color(0xFF03C75A),
              fmt: fmt,
              unit: '₩4/건 (1K/일 초과분)',
            ),
            const Divider(height: 20),
            _CostSummaryRow(
              label: 'Google 합계',
              cost: costGoogle,
              color: const Color(0xFF4285F4),
              fmt: fmt,
            ),
            _CostSummaryRow(
              label: 'Naver 합계',
              cost: costNaver,
              color: const Color(0xFF03C75A),
              fmt: fmt,
            ),
            const SizedBox(height: 4),
            _CostSummaryRow(
              label: '🧾 전체 추정 비용',
              cost: costTotal,
              color: Colors.red.shade700,
              fmt: fmt,
              bold: true,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '※ 이 기기에서 발생한 단순 카운트 × 단가 추정치 (실제 청구액과 차이 있을 수 있음)',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class _GeoRow extends StatelessWidget {
  final String label;
  final int count;
  final double cost;
  final Color color;
  final NumberFormat fmt;
  final String unit;
  const _GeoRow({
    required this.label,
    required this.count,
    required this.cost,
    required this.color,
    required this.fmt,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 4, height: 28, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 13)),
                Text(
                  unit,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Text(
            '${fmt.format(count)}건',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              '₩${fmt.format(cost.round())}',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: cost > 0 ? Colors.red.shade700 : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CostSummaryRow extends StatelessWidget {
  final String label;
  final double cost;
  final Color color;
  final NumberFormat fmt;
  final bool bold;
  const _CostSummaryRow({
    required this.label,
    required this.cost,
    required this.color,
    required this.fmt,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: bold ? 14 : 12,
      fontWeight: bold ? FontWeight.bold : FontWeight.w500,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(
            '₩${fmt.format(cost.round())}',
            style: style.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}
