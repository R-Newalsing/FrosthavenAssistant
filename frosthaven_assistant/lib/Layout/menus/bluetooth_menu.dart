import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
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
    var devices = _bluetooth.connectedDevices;

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
                if (devices.isEmpty) {
                  return const Center(
                    child: Text(
                      'No Bluetooth Standees',
                    ),
                  );
                }

                return Expanded(
                  child: ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: getTileTitle(index),
                        onTap: () => handleClick(index),
                        trailing: getTrailing(index),
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
                BluetoothMethods.hideNumbers();
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

  Text getTileTitle(int index) {
    var number = index + 1;
    var device = _bluetooth.connectedDevices[index];
    var standee = getIt<GameState>().bluetoothStandees.firstWhereOrNull(
          (element) => element.device.remoteId == device.remoteId,
        );

    if (standee == null) {
      var textColor = monsterIsConnected() ? Colors.grey : titleColor(index);

      return Text(
        "$number - Empty bluetooth Standee",
        style: TextStyle(color: textColor),
      );
    }

    return Text(
        "$number - ${standee.monsterInstance.name} (${standee.monsterInstance.standeeNr})",
        style: TextStyle(color: titleColor(index)));
  }

  Color titleColor(int index) {
    var device = _bluetooth.connectedDevices[index];
    var isElite = device.advName.contains("ELITE");

    return isElite ? Colors.yellow.shade700 : Colors.black54;
  }

  bool monsterIsConnected() {
    return _gameState.bluetoothStandees.firstWhereOrNull(
              (element) => element.monsterInstance == widget.monsterInstance,
            ) !=
            null
        ? true
        : false;
  }

  handleClick(int index) {
    var monster = widget.monster;
    var monsterInstance = widget.monsterInstance;
    var device = _bluetooth.connectedDevices[index];
    var standee = getIt<GameState>().bluetoothStandees.firstWhereOrNull(
          (element) => element.device.remoteId == device.remoteId,
        );

    if (device.servicesList.isEmpty ||
        monsterInstance == null ||
        monster == null ||
        monsterIsConnected() ||
        standee != null ||
        !_bluetooth.readyDevices.contains(device.remoteId)) {
      return;
    }

    BluetoothMethods.addBluetoothStandee(
      monster,
      monsterInstance,
      index,
    );
  }

  Widget getTrailing(int index) {
    var device = _bluetooth.connectedDevices[index];
    var standee = getIt<GameState>().bluetoothStandees.firstWhereOrNull(
          (element) => element.device.remoteId == device.remoteId,
        );

    if (standee == null || standee.monsterInstance != widget.monsterInstance) {
      return const SizedBox();
    }

    return IconButton(
      icon: const Icon(Icons.highlight_off),
      color: Colors.red,
      onPressed: () {
        BluetoothMethods.deleteBluetoothStandee(standee);
        BluetoothMethods.showNumbers();
      },
    );
  }
}
