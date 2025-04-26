// Flutter imports:
import 'package:flutter/material.dart';

// Package imports:
import 'package:hive_flutter/hive_flutter.dart';

// Project imports:
import 'package:ringinout/services/hive_helper.dart';

// ✨ 수정페이지 임포트

class LocationAlarmList extends StatefulWidget {
  const LocationAlarmList({super.key});

  @override
  State<LocationAlarmList> createState() => _LocationAlarmListState();
}

class _LocationAlarmListState extends State<LocationAlarmList> {
  bool isSelectionMode = false;
  Set<int> selectedIndexes = {};

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Offset>(
      future: HiveHelper.getFabPosition(),
      builder: (context, snapshot) {
        Offset fabPosition = snapshot.data ?? const Offset(160, 580);

        return WillPopScope(
          onWillPop: () async {
            if (isSelectionMode) {
              setState(() {
                isSelectionMode = false;
                selectedIndexes.clear();
              });
              return false;
            }
            return true;
          },
          child: StatefulBuilder(
            builder: (context, setInnerState) {
              return Stack(
                children: [
                  ValueListenableBuilder(
                    valueListenable: Hive.box('locationAlarms').listenable(),
                    builder: (context, Box box, _) {
                      final alarms = box.values.toList();

                      if (alarms.isEmpty) {
                        return const Center(child: Text('저장된 알람이 없습니다.'));
                      }

                      return ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: alarms.length,
                        itemBuilder: (context, index) {
                          final alarm = Map<String, dynamic>.from(
                            alarms[index],
                          );
                          final name = alarm['name'] ?? '이름 없음';
                          final repeat = alarm['repeat'];
                          String subtitle;

                          if (repeat is String) {
                            subtitle = repeat;
                          } else if (repeat is List && repeat.isNotEmpty) {
                            subtitle = '매주 ${repeat.join(', ')}';
                          } else {
                            subtitle =
                                alarm['trigger'] == 'entry'
                                    ? '알람 설정 후 최초 진입 시'
                                    : '알람 설정 후 최초 진출 시';
                          }

                          final isSelected = selectedIndexes.contains(index);

                          return GestureDetector(
                            onLongPress: () {
                              setState(() {
                                isSelectionMode = true;
                                selectedIndexes.add(index);
                              });
                            },

                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              transform:
                                  isSelectionMode
                                      ? Matrix4.translationValues(20, 0, 0)
                                      : Matrix4.identity(),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      if (isSelectionMode)
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (bool? checked) {
                                            setState(() {
                                              if (checked == true) {
                                                selectedIndexes.add(index);
                                              } else {
                                                selectedIndexes.remove(index);
                                              }
                                            });
                                          },
                                        ),
                                      Expanded(
                                        child: ListTile(
                                          leading: const Icon(Icons.place),
                                          title: Text(name),
                                          subtitle: Text(subtitle),
                                          onTap: () {
                                            if (isSelectionMode) {
                                              setState(() {
                                                if (isSelected) {
                                                  selectedIndexes.remove(index);
                                                } else {
                                                  selectedIndexes.add(index);
                                                }
                                              });
                                            } else {
                                              Navigator.pushNamed(
                                                context,
                                                '/edit_location_alarm',
                                                arguments: {
                                                  'alarm':
                                                      Map<String, dynamic>.from(
                                                        alarm,
                                                      ),
                                                  'index': index,
                                                },
                                              );
                                            }
                                          },
                                        ),
                                      ),

                                      if (!isSelectionMode)
                                        Container(
                                          width: 48,
                                          alignment: Alignment.center,
                                          decoration: const BoxDecoration(
                                            border: Border(
                                              left: BorderSide(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onTap: () async {
                                              final updatedAlarm =
                                                  Map<String, dynamic>.from(
                                                    alarm,
                                                  );
                                              updatedAlarm['enabled'] =
                                                  !(alarm['enabled'] ?? false);
                                              await HiveHelper.updateLocationAlarm(
                                                index,
                                                updatedAlarm,
                                              );
                                            },
                                            child: AnimatedContainer(
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color:
                                                    (alarm['enabled'] ?? false)
                                                        ? Colors.blue
                                                        : Colors.grey[300],
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 200,
                                                  ),
                                                  width:
                                                      (alarm['enabled'] ??
                                                              false)
                                                          ? 20
                                                          : 12,
                                                  height:
                                                      (alarm['enabled'] ??
                                                              false)
                                                          ? 20
                                                          : 12,
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.white,
                                                        shape: BoxShape.circle,
                                                      ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  Divider(
                                    color: Colors.grey.shade300,
                                    height: 1,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  if (isSelectionMode)
                    Positioned(
                      top: 0,
                      left: -10,
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (selectedIndexes.length ==
                                    Hive.box('locationAlarms').length) {
                                  selectedIndexes.clear();
                                } else {
                                  selectedIndexes = Set<int>.from(
                                    List.generate(
                                      Hive.box('locationAlarms').length,
                                      (index) => index,
                                    ),
                                  );
                                }
                              });
                            },
                            child: Row(
                              children: [
                                Checkbox(
                                  value:
                                      selectedIndexes.length ==
                                      Hive.box('locationAlarms').length,
                                  onChanged: (bool? value) {
                                    setState(() {
                                      if (value == true) {
                                        selectedIndexes = Set<int>.from(
                                          List.generate(
                                            Hive.box('locationAlarms').length,
                                            (index) => index,
                                          ),
                                        );
                                      } else {
                                        selectedIndexes.clear();
                                      }
                                    });
                                  },
                                ),
                                const Text('전체'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (isSelectionMode)
                    Positioned(
                      bottom: 20,
                      right: 20,
                      child: FloatingActionButton(
                        backgroundColor: Colors.grey[500],
                        onPressed: () async {
                          final box = Hive.box('locationAlarms');
                          final keys = box.keys.toList();
                          for (int i in selectedIndexes) {
                            await box.delete(keys[i]);
                          }
                          setState(() {
                            selectedIndexes.clear();
                            isSelectionMode = false;
                          });
                        },
                        child: const Icon(Icons.delete),
                      ),
                    ),
                  if (!isSelectionMode)
                    Positioned(
                      left: fabPosition.dx,
                      top: fabPosition.dy,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setInnerState(() {
                            fabPosition += details.delta;
                          });
                        },
                        onPanEnd: (details) async {
                          await HiveHelper.saveFabPosition(
                            fabPosition.dx,
                            fabPosition.dy,
                          );
                        },
                        child: FloatingActionButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/add_location_alarm');
                          },
                          backgroundColor: Colors.blue,
                          tooltip: '알람 추가',
                          child: const Icon(Icons.alarm_add),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
