import 'package:collection/collection.dart';
import 'package:frosthaven_assistant/Model/MonsterAbility.dart';
import 'package:frosthaven_assistant/Resource/commands/change_stat_commands/change_health_command.dart';
import 'package:frosthaven_assistant/Resource/enums.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/bluetooth.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class BluetoothStandee {
  Monster? monster = null;
  MonsterInstance? monsterInstance = null;

  int address = 0;
  bool elite = false;
  bool connected = true;

  final GameState _gameState = getIt<GameState>();
  final Bluetooth _bluetooth = getIt<Bluetooth>();

  BluetoothStandee({
    required this.address,
    required this.elite,
  }) {}

  void initStats() async {
    if (monsterInstance == null) {
      return;
    }

    var maxHealth = monsterInstance!.maxHealth.value;
    var health = monsterInstance!.health.value;
    var shield = getShield();
    var flying = monster!.type.flying ? 1 : 0;
    var bonusShield = getBonusShield();
    List<int> data = [maxHealth, health, shield, flying, bonusShield];

    for (var condition in monsterInstance!.conditions.value) {
      data.add(condition.index);
    }

    _bluetooth.init(address, data);
  }

  void reset() {
    monster = null;
    monsterInstance = null;
    _bluetooth.reset(address);
  }

  int getShield() {
    var shieldLine = getMonsterShield();
    if (shieldLine == null) return 0;
    return getShieldFromString(shieldLine);
  }

  void handleMonsterCard(List<String> lines) {
    _bluetooth.card(address, [getShieldFromLines(lines)]);
  }

  void changeHealth(int health) {
    _bluetooth.changeHealth(address, [health]);
  }

  void handleHealthChange(int health) {
    String name = monsterInstance!.name;
    String id = monsterInstance!.getId();
    FigureState figure = GameMethods.getFigure(name, id)!;
    int change = health - figure.health.value;

    _gameState.action(ChangeHealthCommand(change, id, name));
  }

  void toggleCondition(Condition condition) {
    _bluetooth.toggleCondition(address, [condition.index]);
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
    if (monsterInstance!.type == MonsterType.normal) {
      if (monster!
          .type.levels[monster!.level.value].normal!.attributes.isNotEmpty) {
        return monster!.type.levels[monster!.level.value].normal!.attributes
            .firstWhere((element) => element.contains("%shield%"),
                orElse: () => '');
      }
    }

    if (monsterInstance!.type == MonsterType.elite) {
      if (monster!
          .type.levels[monster!.level.value].elite!.attributes.isNotEmpty) {
        return monster!.type.levels[monster!.level.value].elite!.attributes
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
        if (item is Monster && item.id == monster!.id) {
          if (item.type.deck == deck.name && deck.discardPile.isNotEmpty) {
            return deck.discardPile.peek;
          }
        }
      }
    }

    return null;
  }
}
