import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Model/bluetooth_standee.dart';
import 'package:frosthaven_assistant/Resource/bluetooth_methods.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/network/bluetooth.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class BluetoothMenu extends StatefulWidget {
  final MonsterInstance? monsterInstance;
  final Monster? monster;

  const BluetoothMenu({
    super.key,
    this.monsterInstance,
    this.monster,
  });

  @override
  BluetoothMenuState createState() => BluetoothMenuState();
}

class BluetoothMenuState extends State<BluetoothMenu> {
  final Bluetooth _bluetooth = getIt<Bluetooth>();
  final GameState _gameState = getIt<GameState>();

  @override
  Widget build(BuildContext context) {
    var standees = _gameState.bluetoothStandees;

    return Container(
      constraints: const BoxConstraints(maxWidth: 450),
      child: Card(
        margin: const EdgeInsets.all(2),
        child: Stack(children: [
          Column(children: [
            const SizedBox(
              height: 20,
            ),
            Container(
              margin: const EdgeInsets.only(left: 10, right: 10),
              child: TextButton(
                onPressed: () => searchAndConnect(),
                child: const Text(
                  'Search for Bluetooth Standees',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            ValueListenableBuilder<int>(
              valueListenable: getIt<GameState>().updateBluetoothContent,
              builder: (context, value, child) {
                var connectedStandees =
                    standees.where((s) => s.connected).toList();
                if (connectedStandees.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Bluetooth Standees',
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: connectedStandees.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: getTileTitle(connectedStandees[index]),
                        onTap: () => handleClick(connectedStandees[index]),
                        trailing: getTrailing(connectedStandees[index]),
                      );
                    },
                  ),
                );
              },
            ),
          ]),
          Positioned(
            width: 100,
            height: 40,
            right: 0,
            bottom: 10,
            child: TextButton(
              child: const Text('Close', style: TextStyle(fontSize: 20)),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
          ),
        ]),
      ),
    );
  }

  searchAndConnect() {
    _bluetooth.searchAndConnect();
  }

  Text getTileTitle(BluetoothStandee standee) {
    var number = standee.address.toRadixString(16).toUpperCase();

    if (standee.monsterInstance != null) {
      return Text(
          "$number - ${standee.monsterInstance!.name} (${standee.monsterInstance!.standeeNr})",
          style: TextStyle(color: titleColor(standee)));
    }

    var textColor = monsterIsConnected() ? Colors.grey : titleColor(standee);

    return Text(
      "$number - Empty bluetooth Standee",
      style: TextStyle(color: textColor),
    );
  }

  Color titleColor(BluetoothStandee standee) {
    return standee.elite ? Colors.yellow.shade700 : Colors.black54;
  }

  bool monsterIsConnected() {
    return _gameState.bluetoothStandees.firstWhereOrNull(
              (element) =>
                  element.monsterInstance != null &&
                  element.monsterInstance == widget.monsterInstance,
            ) !=
            null
        ? true
        : false;
  }

  handleClick(BluetoothStandee standee) {
    var monster = widget.monster;
    var monsterInstance = widget.monsterInstance;

    if (standee.monster != null ||
        monsterInstance == null ||
        monster == null ||
        !standee.connected ||
        monsterIsConnected()) {
      return;
    }

    BluetoothMethods.addBluetoothStandee(monster, monsterInstance, standee);
  }

  Widget getTrailing(BluetoothStandee standee) {
    if (standee.monsterInstance == null ||
        standee.monsterInstance != widget.monsterInstance) {
      return const SizedBox();
    }

    return IconButton(
      icon: const Icon(Icons.highlight_off),
      color: Colors.red,
      onPressed: () {
        BluetoothMethods.deleteBluetoothStandee(standee);
      },
    );
  }
}
