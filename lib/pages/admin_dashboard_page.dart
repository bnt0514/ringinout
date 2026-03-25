// lib/pages/admin_dashboard_page.dart
// 어드민 전용: 맵 사용량 대시보드 + 킬스위치 관리

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:ringinout/config/app_config.dart';
import 'package:ringinout/services/map_provider_service.dart';
import 'package:ringinout/services/map_usage_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  MapUsageStats? _stats;
  bool _loading = true;
  String? _error;

  List<WeeklyMapStats> _weeklyHistory = [];
  bool _weeklyLoading = true;
  bool _forceUploadInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadWeeklyHistory();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('어드민  맵 사용량'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: () {
              _loadStats();
              _loadWeeklyHistory();
            },
          ),
          IconButton(
            icon: const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Firestore 강제 업로드',
            onPressed: _forceUpload,
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : _buildBody(),
    );
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
            onToggle: (enabled) => _toggleProvider('google', enabled),
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
            onToggle: (enabled) => _toggleProvider('naver', enabled),
          ),
          const SizedBox(height: 12),
          _OsmCard(osmCount: stats?.osm ?? 0, fmt: fmt),
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
          // 전체 강제 업로드 섹션
          _buildForceUploadSection(),
          const SizedBox(height: 24),
          // 주간 히스토리 테이블
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
                    activeColor: iconColor,
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
