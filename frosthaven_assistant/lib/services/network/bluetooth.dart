import 'dart:io';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:frosthaven_assistant/Model/bluetooth_standee.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/services/service_locator.dart';

class Bluetooth {
  final serviceUuid = Guid("19b10000-e8f2-537e-4f6c-d104768a1214");

  final messageUuid = Guid("6b061bdc-9bc1-4952-a96f-c6ed551b2c3e");
  final handshakeUuid = Guid("998ff920-81af-42a9-a915-f88025f9647d");
  final indentityUuid = Guid("14128a76-04d1-6c4f-537e-e8f219b10000");

  static const DATA_TYPE_INDEX = 0;
  static const DATA_CACHE_INDEX = 1;
  static const DATA_ADDR_INDEX = 2;

  static const MESH_MESSAGE_CHANGE_HEALTH = 0;
  static const MESH_MESSAGE_CONDITIONS = 1;
  static const MESH_MESSAGE_SHIELDS = 2;
  static const MESH_MESSAGE_FLYING = 3;
  static const MESH_MESSAGE_INIT = 4;
  static const MESH_MESSAGE_RESET = 5;

  static const MESH_HANDSHAKE_NODES = 0;
  static const MESH_HANDSHAKE_LOST_NODE = 1;
  static const MESH_HANDSHAKE_FLOOD_NODES = 2;

  bool hasDisconnected = false;
  List<int> macAddresses = [];
  List<int> messageCache = [];
  List<int> handshakeCache = [];

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
      getCharacteristic(handshakeUuid).write([MESH_HANDSHAKE_FLOOD_NODES]);
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
      withServices: [indentityUuid],
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
              removeDeviceFromList();
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

      r.device.connect();
    }
  }

  void removeDeviceFromList() {}

  void discoverServices() async {
    await device.discoverServices();

    subscribe();
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

  void subscribe() async {
    var messageChar = getCharacteristic(messageUuid);
    var handshakeChar = getCharacteristic(handshakeUuid);

    await messageChar.setNotifyValue(true);
    await handshakeChar.setNotifyValue(true);

    var messageSub = messageChar.onValueReceived.listen(handleMessage);
    var handshakeSub = handshakeChar.onValueReceived.listen(handleHandshake);

    device.cancelWhenDisconnected(messageSub);
    device.cancelWhenDisconnected(handshakeSub);

    handshakeChar.write([MESH_HANDSHAKE_FLOOD_NODES]);
  }

  void handleMessage(List<int> data) {
    print(data);

    var type = data[DATA_TYPE_INDEX];

    if (messageCache.contains(data[DATA_CACHE_INDEX])) {
      return;
    }

    messageCache.insert(0, data[DATA_CACHE_INDEX]);
    var addr = data[DATA_ADDR_INDEX];
    var standee = getIt<GameState>()
        .bluetoothStandees
        .firstWhere((standee) => standee.address == addr);

    switch (type) {
      case MESH_MESSAGE_CHANGE_HEALTH:
        var health = data[DATA_ADDR_INDEX + 2];
        standee.handleHealthChange(health);
        break;
    }
  }

  void handleHandshake(List<int> data) {
    print(data);
    var type = data[DATA_TYPE_INDEX];

    if (handshakeCache.contains(data[DATA_CACHE_INDEX])) {
      return;
    }

    handshakeCache.insert(0, data[DATA_CACHE_INDEX]);

    if (type == MESH_HANDSHAKE_NODES) {
      for (int i = 4; i < data.length; i++) {
        var address = data[i];

        if (!macAddresses.any((mac) => mac == address)) {
          macAddresses.add(address);
        }

        var existingStandee = getIt<GameState>()
            .bluetoothStandees
            .firstWhereOrNull((standee) => standee.address == address);

        if (existingStandee == null) {
          getIt<GameState>().bluetoothStandees.add(
                BluetoothStandee(
                  address: address,
                  elite: (address & 0x80) != 0,
                ),
              );
        } else {
          existingStandee.connected = true;
          existingStandee.initStats();
        }
      }

      for (var standee in getIt<GameState>().bluetoothStandees) {
        if (!macAddresses.any((mac) => mac == standee.address)) {
          standee.connected = false;
        }
      }

      getIt<GameState>().updateBluetoothContent.value++;
    }

    if (type == MESH_HANDSHAKE_LOST_NODE) {
      var address = data[DATA_ADDR_INDEX];
      var existingStandee = getIt<GameState>()
          .bluetoothStandees
          .firstWhereOrNull((standee) => standee.address == address);

      if (existingStandee != null) {
        existingStandee.connected = false;
      }

      if (macAddresses.any((mac) => mac == address)) {
        macAddresses.remove(address);
      }

      getIt<GameState>().updateBluetoothContent.value++;
    }
  }

  void sendMessage(int type, int address, List<int> data) {
    int num;

    do {
      num = new Random().nextInt(256);
    } while (messageCache.any((numInCache) => numInCache == num));

    messageCache.insert(0, num);

    if (messageCache.length > 20) {
      messageCache = messageCache.sublist(0, 20);
    }

    data.insert(0, 10);
    data.insert(0, address);
    data.insert(0, num);
    data.insert(0, type);
    print("Sending: $data");

    getCharacteristic(messageUuid).write(data);
  }

  void sendHandshake(List<int> data) {}

  void init(int address, List<int> data) {
    sendMessage(MESH_MESSAGE_INIT, address, data);
  }

  void reset(int address) {
    var data = [address, 0x01];

    sendMessage(MESH_MESSAGE_RESET, address, data);
  }

  void card(int address, List<int> data) {
    sendMessage(MESH_MESSAGE_SHIELDS, address, data);
  }

  void changeHealth(int address, List<int> data) {
    sendMessage(MESH_MESSAGE_CHANGE_HEALTH, address, data);
  }

  void toggleCondition(int address, List<int> data) {
    sendMessage(MESH_MESSAGE_CONDITIONS, address, data);
  }
}
