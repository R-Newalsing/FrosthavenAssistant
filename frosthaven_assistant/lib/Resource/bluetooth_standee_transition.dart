import 'package:flutter/widgets.dart';
import 'package:frosthaven_assistant/Layout/menus/bluetooth_menu.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/ui_utils.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

final GameState _gameState = getIt<GameState>();

class BluetoothStandeeTransition {
  static BuildContext? context;
  static Monster? monster;
  static MonsterInstance? monsterInstance;

  static void showMenu() {
    if (_gameState.bluetoothStandees
        .every((standee) => standee.monster != null)) {
      return;
    }

    openDialogWithDismissOption(
      context!,
      BluetoothMenu(
        monster: monster,
        monsterInstance: monsterInstance,
      ),
      false,
    );
  }
}
