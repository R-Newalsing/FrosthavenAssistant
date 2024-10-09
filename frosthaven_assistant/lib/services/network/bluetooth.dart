import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frosthaven_assistant/Model/bluetooth_standee.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class Bluetooth {
  final serviceUuid = Guid("19b10000-e8f2-537e-4f6c-d104768a1214");

  final chainUuid = Guid("59a21f61-9f7a-4774-b41e-290c589c61e2");
  final toggleNumberUuid = Guid("cd9cd58a-0f46-4d5f-bc54-2d8a25eb90bb");
  final hideNumberUuid = Guid("fba2078b-bd52-4cae-9609-1c244b79ef3e");
  final setNumberUuid = Guid("c82c1f2f-4d7b-4cb0-b09a-3dfc7ac3b661");
  final changeHealthUuid = Guid("6b061bdc-9bc1-4952-a96f-c6ed551b2c3e");
  final toggleConditionUuid = Guid("97bada80-d0a4-4f36-80cf-d23d2eb2f81c");
  final cardStatsUuid = Guid("af01172b-6892-4d76-a25b-147ab558a3fc");
  final initValuesUuid = Guid("f5628575-fb78-462c-b1fa-d2e5edcd6389");
  final initConditionsUuid = Guid("03958fe6-1777-401b-a815-f50971456caa");
  final resetUuid = Guid("a808d258-da4f-41be-b350-4b171a9487db");

  bool hasDisconnected = false;
  int standeesAmount = 0;
  List<List<int>> macAddresses = [];

  BluetoothDevice device = BluetoothDevice(remoteId: DeviceIdentifier(''));

  Bluetooth() {
    _init();
  }

  void _init() async {
    // first, check if bluetooth is supported by your hardware
    // Note: The platform is initialized on the first call to any FlutterBluePlus method.
    if (await FlutterBluePlus.isSupported == false) {
      print("Bluetooth not supported by this device");
      return;
    }

    // if the platform is android, turn on bluetooth
    if (Platform.isAndroid) await FlutterBluePlus.turnOn();
  }

  void searchAndConnect() async {
    if (device.isConnected) {
      getCharacteristic(chainUuid).write([0]);
      return;
    }

    // isScanning = true;
    // Setup Listener for scan results
    var subscription = FlutterBluePlus.onScanResults.listen(scanListener);

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    FlutterBluePlus.startScan(
      timeout: const Duration(seconds: 6),
      withNames: ["BLUETOOTH-STANDEE"],
    );
  }

  void scanListener(List<ScanResult> results) {
    for (ScanResult r in results) {
      r.device.connectionState.listen((BluetoothConnectionState state) async {
        switch (state) {
          case BluetoothConnectionState.connected:
            if (!device.isConnected) {
              hasDisconnected = false;
              device = r.device;
              discoverServices();
            }
            break;
          case BluetoothConnectionState.disconnected:
            if (!hasDisconnected) {
              device = BluetoothDevice(remoteId: DeviceIdentifier(''));
              hasDisconnected = true;
              searchAndConnect();
            }
            break;
          default:
            print('Connection state changed: $state');
            break;
        }
      });

      r.device.connect(mtu: null);
    }
  }

  void discoverServices() async {
    await device.discoverServices();

    subscribe();
  }

  void receivedChainData(List<int> data) {
    if (data.length == 1) {
      macAddresses.clear();
      standeesAmount = data[0];
      getCharacteristic(chainUuid).write([0x01]);
      return;
    }

    var macAddress = data.sublist(0, 6);
    macAddresses.add(macAddress);
    var existingStandee = getIt<GameState>().bluetoothStandees.firstWhereOrNull(
          (standee) => ListEquality().equals(standee.macAddress, macAddress),
        );

    if (existingStandee == null) {
      getIt<GameState>().bluetoothStandees.add(
            BluetoothStandee(
              macAddress: macAddress,
              elite: data[6] == 1,
            ),
          );
    } else {
      existingStandee.connected = true;
    }

    if (macAddresses.length == standeesAmount) {
      for (var standee in getIt<GameState>().bluetoothStandees) {
        if (!macAddresses
            .any((mac) => ListEquality().equals(mac, standee.macAddress))) {
          standee.connected = false;
        }
      }
    }

    getIt<GameState>().updateBluetoothContent.value++;
  }

  void setNumbers() {
    getCharacteristic(setNumberUuid).write([0x01]);
  }

  void showNumber() {
    if (!device.isConnected) {
      return;
    }

    getCharacteristic(toggleNumberUuid).write([0x01]);
  }

  void startSearchDevices() {
    getCharacteristic(chainUuid).write([0x01]);
  }

  void hideNumber() {
    if (!device.isConnected) {
      return;
    }
    getCharacteristic(toggleNumberUuid).write([0x00]);
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

  void subscribe() {
    print("Subscribing to characteristics");
    var characteristic = getCharacteristic(changeHealthUuid);
    characteristic.setNotifyValue(true);

    device
        .cancelWhenDisconnected(characteristic.onValueReceived.listen((value) {
      var macAddress = value.sublist(0, 6);
      int val = value[6] == 1 ? 1 : -1;

      var standee = getIt<GameState>().bluetoothStandees.firstWhereOrNull(
            (standee) => listEquals(standee.macAddress, macAddress),
          );

      if (standee == null) {
        return;
      }

      standee.handleHealthChange(val);
    }));

    var char = getCharacteristic(chainUuid);
    char.setNotifyValue(true);

    device
        .cancelWhenDisconnected(char.onValueReceived.listen(receivedChainData));

    print("Subscribed to characteristics");
    char.write([0]);
  }

  void init(List<int> macAddress, List<int> data) {
    data.insertAll(0, macAddress);

    getCharacteristic(initValuesUuid).write(data);
  }

  void reset(List<int> macAddress) {
    var data = [0x01];
    data.insertAll(0, macAddress);

    getCharacteristic(resetUuid).write(data);
  }

  void card(List<int> macAddress, List<int> data) {
    data.insertAll(0, macAddress);

    getCharacteristic(cardStatsUuid).write(data);
  }

  void changeHealth(List<int> macAddress, List<int> data) {
    data.insertAll(0, macAddress);

    getCharacteristic(changeHealthUuid).write(data);
  }

  void toggleCondition(List<int> macAddress, List<int> data) {
    data.insertAll(0, macAddress);

    getCharacteristic(toggleConditionUuid).write(data);
  }
}
