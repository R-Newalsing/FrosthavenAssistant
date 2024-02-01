import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Resource/bluetooth_methods.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class BluetoothStandee {
  final callUuid = Guid("a808d258-da4f-41be-b350-4b171a9487db");
  final serviceUuid = Guid("19b10000-e8f2-537e-4f6c-d104768a1214");
  final changeHealthUuid = Guid("6b061bdc-9bc1-4952-a96f-c6ed551b2c3e");
  final toggleConditionUuid = Guid("97bada80-d0a4-4f36-80cf-d23d2eb2f81c");
  final cardStatsUuid = Guid("af01172b-6892-4d76-a25b-147ab558a3fc");
  final initValuesUuid = Guid("f5628575-fb78-462c-b1fa-d2e5edcd6389");

  Monster monster;
  MonsterInstance monsterInstance;
  BluetoothDevice device;
  List<BluetoothService> services = [];
  final GameState _gameState = getIt<GameState>();

  BluetoothStandee({
    required this.monster,
    required this.monsterInstance,
    required this.device,
  }) {
    subscribe();
    initStats();
  }

  void subscribe() {
    var characteristic = getCharacteristic(changeHealthUuid);

    characteristic.setNotifyValue(true);

    var subscription = characteristic.onValueReceived.listen((value) {
      int val = int.parse(String.fromCharCodes(value));
      val = val == 1 ? 1 : -1;
      String name = monsterInstance.name;
      String id = monsterInstance.getId();

      getIt<GameState>().action(ChangeHealthCommand(val, id, name));
    });

    device.cancelWhenDisconnected(subscription);
  }

  void initStats() async {
    var maxHealth = monsterInstance.maxHealth.value;
    var health = monsterInstance.health.value;
    var shield = getShield();
    var flying = monster.type.flying ? 1 : 0;
    var bonusShield = getBonusShield();
    var data = "$maxHealth,$health,$shield,$flying,$bonusShield";

    for (var condition in monsterInstance.conditions.value) {
      data += ",${condition.index}";
    }

    getCharacteristic(initValuesUuid).write(utf8.encode(data));
  }

  void reset() {
    getCharacteristic(initValuesUuid).write(utf8.encode("0,0,0,0,0"));
  }

  int getShield() {
    var shieldLine = getMonsterShield();
    if (shieldLine == null) return 0;
    return getShieldFromString(shieldLine);
  }

  BluetoothCharacteristic getCharacteristic(Guid uuid) {
    return getService()
        .characteristics
        .firstWhere((element) => element.uuid == uuid);
  }

  BluetoothService getService() {
    return device.servicesList.firstWhere((element) {
      return element.uuid == serviceUuid;
    });
  }

  void handleMonsterCard(List<String> lines) {
    var shield = getShieldFromLines(lines);
    var data = "$shield";
    getCharacteristic(cardStatsUuid).write(utf8.encode(data));
  }

  void changeHealth(int health) {
    getCharacteristic(changeHealthUuid).write([health]);
  }

  void toggleCondition(Condition condition) {
    getCharacteristic(toggleConditionUuid).write([condition.index]);
  }

  int getShieldFromLines(List<String> lines) {
    String? shieldLine = lines.firstWhereOrNull((line) {
      return line.contains('%shield%');
    });

    if (shieldLine == null) return 0;

    return getShieldFromString(shieldLine);
  }

  int getShieldFromString(String line) {
    if (line.contains('%shield% +')) {
      return int.parse(line.replaceAll('%shield% +', ''));
    }

    if (line.contains('%shield% ')) {
      return int.parse(line.replaceAll('%shield% ', ''));
    }

    return 0;
  }

  String? getMonsterShield() {
    if (monsterInstance.type == MonsterType.normal) {
      if (monster
          .type.levels[monster.level.value].normal!.attributes.isNotEmpty) {
        return monster.type.levels[monster.level.value].normal!.attributes
            .firstWhere((element) => element.contains("%shield%"),
                orElse: () => '');
      }
    }

    if (monsterInstance.type == MonsterType.elite) {
      if (monster
          .type.levels[monster.level.value].elite!.attributes.isNotEmpty) {
        return monster.type.levels[monster.level.value].elite!.attributes
            .firstWhere((element) => element.contains("%shield%"),
                orElse: () => '');
      }
    }

    return null;
  }

  int getBonusShield() {
    var card = getLastDrawnCard();
    if (card == null) return 0;
    return getShieldFromLines(card.lines);
  }

  MonsterAbilityCardModel? getLastDrawnCard() {
    for (MonsterAbilityState deck in _gameState.currentAbilityDecks) {
      for (var item in _gameState.currentList) {
        if (item is Monster && item.id == monster.id) {
          if (item.type.deck == deck.name && deck.discardPile.isNotEmpty) {
            return deck.discardPile.peek;
          }
        }
      }
    }

    return null;
  }
}
