import 'package:collection/collection.dart';
import 'package:frosthaven_assistant/Model/bluetooth_standee.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/bluetooth.dart';
import 'package:frosthaven_assistant/services/network/communication.dart';
import 'package:frosthaven_assistant/services/network/network.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

GameState _gameState = getIt<GameState>();
Bluetooth _bluetooth = getIt<Bluetooth>();

class BluetoothMethods {
  static void addBluetoothStandee(
    Monster monster,
    MonsterInstance monsterInstance,
    BluetoothStandee standee,
  ) {
    standee.monster = monster;
    standee.monsterInstance = monsterInstance;
    standee.initStats();

    _gameState.updateBluetoothContent.value++;
  }

  static int getNumberByMonsterInstane(MonsterInstance instance) {
    for (int i = 0; i < _gameState.bluetoothStandees.length; i++) {
      if (_gameState.bluetoothStandees[i].monsterInstance == null) {
        continue;
      }

      if (_gameState.bluetoothStandees[i].monsterInstance!.getId() ==
          instance.getId()) {
        return i + 1;
      }
    }

    return 0;
  }

  static bool isVisibile(MonsterInstance instance) {
    for (var standee in _gameState.bluetoothStandees) {
      if (standee.monsterInstance == null) {
        continue;
      }

      if (standee.monsterInstance!.getId() == instance.getId()) {
        return standee.connected;
      }
    }
    return false;
  }

  static BluetoothStandee? getBluetoothStandeeByFigureId(String figureId) {
    for (var device in _gameState.bluetoothStandees) {
      if (device.monsterInstance == null) {
        continue;
      }

      if (device.monsterInstance!.getId() == figureId) {
        return device;
      }
    }

    return null;
  }

  static void deleteBluetoothStandee(BluetoothStandee standee) {
    standee.reset();
    // _gameState.bluetoothStandees.remove(standee);
    _gameState.updateBluetoothContent.value++;
  }

  static void toggleCondition(Condition condition, String figureId) {
    toggelingCondition(condition, figureId);
    notifyChanges("BLE:toggleConditionConditionData:$condition,$figureId");
  }

  static void toggelingCondition(Condition condition, String figureId) {
    for (var device in getIt<GameState>().bluetoothStandees) {
      if (device.monsterInstance == null) {
        continue;
      }

      if (device.monsterInstance!.getId() == figureId) {
        device.toggleCondition(condition);
      }
    }
  }

  static void changeHealth(String ownerId, String figureId, int health) {
    changingHealth(ownerId, figureId, health);
    notifyChanges("BLE:changeHealthData:$ownerId,$figureId,$health");
  }

  static void changingHealth(String ownerId, String figureId, int health) {
    var standee = BluetoothMethods.getBluetoothStandeeByFigureId(figureId);

    if (standee == null) {
      return;
    }

    if (health <= 0) {
      BluetoothMethods.deleteBluetoothStandee(standee);
    } else {
      standee.changeHealth(health);
    }
  }

  static void notifyChanges(String message) {
    bool isServer = getIt<Settings>().server.value;
    bool isClient = getIt<Settings>().client.value == ClientState.connected;

    if (isServer) {
      getIt<Network>().server.send(message);
      return;
    }

    if (isClient) {
      getIt<Communication>().sendToAll(message);
      return;
    }
  }

  static void handleMessage(String message) {
    List<String> messageParts = message.split("Data:");
    String method = messageParts[0].substring("BLE:".length);
    List<String> data = messageParts[1].split(',');

    switch (method) {
      case "toggleConditionCondition":
        var condition = Condition.values.firstWhereOrNull(
          (e) => e.toString() == data[0],
        );
        var figureId = data[1];
        if (condition == null) break;
        toggelingCondition(condition, figureId);
        break;
      case "changeHealth":
        var ownerId = data[0];
        var figureId = data[1];
        var health = int.parse(data[2]);
        changingHealth(ownerId, figureId, health);
        break;
    }
  }
}
