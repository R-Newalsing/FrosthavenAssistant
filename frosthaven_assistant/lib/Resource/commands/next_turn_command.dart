import 'package:frosthaven_assistant/Resource/game_methods.dart';

import '../../services/service_locator.dart';
import '../action_handler.dart';
import '../game_state.dart';

class TurnDoneCommand extends Command {
  late int index;
  TurnDoneCommand(String id){
    index = 0;
    for (int i = 0; i < getIt<GameState>().currentList.length; i++) {
      if(id == getIt<GameState>().currentList[i].id) {
        index = i;
      }
    }
    getIt<GameState>().updateList.value++;
  }

  @override
  void execute() {
    GameMethods.setTurnDone(index);
  }

  @override
  void undo() {
    getIt<GameState>().updateList.value++;
  }

  @override
  String toString() {
    return "Set Turn";
  }
}