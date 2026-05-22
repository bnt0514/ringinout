import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ringinout/services/wifi_service.dart';
import 'package:ringinout/utils/alarm_detection_mode.dart';

class AlarmActivationNotice {
  static Future<void> showIfNeeded(
    BuildContext context,
    Map<String, dynamic> alarm,
    Map<String, dynamic>? place,
  ) async {
    if (!context.mounted || place == null) return;

    final trigger = (alarm['trigger'] ?? 'entry').toString();
    final mode = AlarmDetectionMode.resolve(alarm, place: place);
    final isInside = await _isCurrentlyInside(place, mode);
    if (isInside == null || !context.mounted) return;

    if (trigger == 'entry' && isInside) {
      await _show(
        context,
        title: '현재 장소 내부입니다',
        body:
            '현재 ${place['name'] ?? '선택한 장소'} 내부입니다. 이 알람은 장소에서 진출한 뒤 다시 진입할 때 울립니다.',
      );
    } else if (trigger == 'exit' && !isInside) {
      await _show(
        context,
        title: '현재 장소 외부입니다',
        body:
            '현재 ${place['name'] ?? '선택한 장소'} 외부입니다. 이 알람은 장소 내부에 들어간 뒤 진출할 때 울립니다.',
      );
    }
  }

  static Future<bool?> _isCurrentlyInside(
    Map<String, dynamic> place,
    String detectionMode,
  ) async {
    if (detectionMode == AlarmDetectionMode.wifi) {
      final networks = _wifiNetworks(place);
      final connected = await WifiService.getConnectedWifi();
      return AlarmDetectionMode.wifiMatches(connected, networks);
    }

    try {
      final lat = _toDouble(place['latitude'] ?? place['lat']);
      final lng = _toDouble(place['longitude'] ?? place['lng']);
      final radius = _toDouble(
        place['radius'] ?? place['geofenceRadius'] ?? 100,
      );
      if (lat == null || lng == null || radius == null) return null;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(const Duration(seconds: 8));

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        lat,
        lng,
      );
      return distance <= radius;
    } catch (_) {
      return null;
    }
  }

  static List<Map<String, dynamic>> _wifiNetworks(Map<String, dynamic> place) {
    final networks = place['wifiNetworks'];
    if (networks is! List) return [];
    return networks
        .map((network) => Map<String, dynamic>.from(network as Map))
        .toList();
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static Future<void> _show(
    BuildContext context, {
    required String title,
    required String body,
  }) {
    return showDialog<void>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(body),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('확인'),
              ),
            ],
          ),
    );
  }
}
