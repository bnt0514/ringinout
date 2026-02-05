import 'package:flutter/material.dart';
import 'package:ringinout/services/location_simulator_service.dart';

class LocationSimulatorPanel extends StatefulWidget {
  const LocationSimulatorPanel({Key? key}) : super(key: key);

  @override
  State<LocationSimulatorPanel> createState() => _LocationSimulatorPanelState();
}

class _LocationSimulatorPanelState extends State<LocationSimulatorPanel> {
  bool _isRunning = false;

  Future<void> _runScenario(Future<void> Function() startFn) async {
    setState(() => _isRunning = true);
    await startFn();
  }

  Future<void> _stop() async {
    await LocationSimulationService.stop();
    if (mounted) {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.route, color: Colors.deepPurple),
                SizedBox(width: 8),
                Text(
                  '🧭 이동 시뮬레이터',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '실제 이동 없이 경로를 재생해 테스트합니다.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed:
                  _isRunning
                      ? null
                      : () => _runScenario(
                        LocationSimulationService.startScenarioCompanyToSiheung,
                      ),
              icon: const Icon(Icons.directions_walk),
              label: const Text('1) 회사 → 주차장 → 시흥집 출발'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed:
                  _isRunning
                      ? null
                      : () => _runScenario(
                        LocationSimulationService
                            .startScenarioDriveToSiheungParking,
                      ),
              icon: const Icon(Icons.directions_car),
              label: const Text('2) 시흥집 주차장 도착 → 도보 진입'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed:
                  _isRunning
                      ? null
                      : () => _runScenario(
                        LocationSimulationService.startScenarioExitSiheung,
                      ),
              icon: const Icon(Icons.logout),
              label: const Text('3) 시흥집 → 엘리베이터 → 차량 출발'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isRunning ? _stop : null,
              icon: const Icon(Icons.stop),
              label: const Text('시뮬레이션 중지'),
            ),
          ],
        ),
      ),
    );
  }
}
