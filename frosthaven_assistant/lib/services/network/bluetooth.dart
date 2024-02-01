import 'dart:io';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class Bluetooth {
  final showNumberUuid = Guid("cd9cd58a-0f46-4d5f-bc54-2d8a25eb90bb");
  final hideNumberUuid = Guid("fba2078b-bd52-4cae-9609-1c244b79ef3e");
  final serviceUuid = Guid("19b10000-e8f2-537e-4f6c-d104768a1214");
  final setNumberUuid = Guid("c82c1f2f-4d7b-4cb0-b09a-3dfc7ac3b661");

  List<BluetoothDevice> connectedDevices = [];

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
    // Setup Listener for scan results
    var subscription = FlutterBluePlus.onScanResults.listen(scanListener);

    // cleanup: cancel subscription when scanning stops
    FlutterBluePlus.cancelWhenScanComplete(subscription);

    // Wait for Bluetooth enabled & permission granted
    // In your real app you should use `FlutterBluePlus.adapterState.listen` to handle all states
    await FlutterBluePlus.adapterState
        .where((val) => val == BluetoothAdapterState.on)
        .first;

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
  }

  void scanListener(List<ScanResult> results) {
    for (ScanResult r in results) {
      if (!isBluetoothDevice(r.device)) continue;
      if (isAlreadyConnected(r.device)) continue;

      r.device.connectionState.listen((BluetoothConnectionState state) async {
        switch (state) {
          case BluetoothConnectionState.connected:
            if (!connectedDevices.contains(r.device)) {
              connectedDevices.add(r.device);
              getIt<GameState>().updateBluetoothContent.value++;
              discoverServices(r.device);
            }
            break;
          case BluetoothConnectionState.disconnected:
            if (connectedDevices.contains(r.device)) {
              connectedDevices.remove(r.device);
              removeBluetoothStandee(r.device);
              getIt<GameState>().updateBluetoothContent.value++;
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

  bool isBluetoothDevice(BluetoothDevice device) {
    return device.advName.contains("BLUETOOTH-STANDEE");
  }

  bool isAlreadyConnected(BluetoothDevice device) {
    if (getDeviceById(device.remoteId) == null) return false;
    return true;
  }

  BluetoothDevice? getDeviceById(DeviceIdentifier remoteId) {
    var index = connectedDevices.indexWhere((d) => d.remoteId == remoteId);
    if (index == -1) return null;
    return connectedDevices[index];
  }

  void discoverServices(BluetoothDevice device) async {
    await device.discoverServices();
    setNumber(device);
    getIt<GameState>().updateBluetoothContent.value++;
  }

  void removeBluetoothStandee(BluetoothDevice device) {
    var gameState = getIt<GameState>();
    var standee = gameState.bluetoothStandees.firstWhereOrNull(
      (element) => element.device.remoteId == device.remoteId,
    );

    if (standee == null) return;

    gameState.bluetoothStandees.remove(standee);
  }

  void setNumber(BluetoothDevice device) {
    var index =
        connectedDevices.indexWhere((d) => d.remoteId == device.remoteId);

    getCharacteristic(setNumberUuid, device).write([index + 1]);
  }

  void showNumber(BluetoothDevice device) {
    getCharacteristic(showNumberUuid, device).write([0x01]);
  }

  void hideNumber(BluetoothDevice device) {
    getCharacteristic(hideNumberUuid, device).write([0x01]);
  }

  BluetoothCharacteristic getCharacteristic(Guid uuid, BluetoothDevice device) {
    return getService(device)
        .characteristics
        .firstWhere((element) => element.uuid == uuid);
  }

  BluetoothService getService(BluetoothDevice device) {
    return device.servicesList.firstWhere((element) {
      return element.uuid == serviceUuid;
    });
  }
}
