import 'package:frosthaven_assistant/Resource/bluetooth_methods.dart';

import '../../../services/service_locator.dart';
import '../../state/game_state.dart';
import 'change_stat_command.dart';

class ChangeHealthCommand extends ChangeStatCommand {
  ChangeHealthCommand(super.change, super.figureId, super.ownerId);

  @override
  void execute() {
    FigureState figure = GameMethods.getFigure(ownerId, figureId)!;

    int previousValue = figure.health.value;
    if (figure.health.value + change < 0) {
      //no negative values
      figure.setHealth(stateAccess, 0);
    } else {
      figure.setHealth(stateAccess, figure.health.value + change);
    }
    if (previousValue <= 0 && figure.health.value > 0) {
      //un death
      getIt<GameState>().updateList.value++;
    }

    if (figure.health.value <= 0) {
      handleDeath();
    }

    /// Buetooth stuff
    BluetoothMethods.changeHealth(ownerId, figureId, figure.health.value);
  }

  @override
  void undo() {
    //stat.value -= change;
    getIt<GameState>().updateList.value++;
  }

  @override
  String describe() {
    if (change > 0) {
      //TODO: looks bad
      return "Increase $figureId's health by $change";
    }
    FigureState? figure = GameMethods.getFigure(ownerId, figureId);
    if (figure == null || figure.health.value <= 0) {
      return "Kill $ownerId";
    }
    //TODO: incorrect for character summons
    return "Decrease $ownerId's health by ${-change}";
  }
}
