import 'package:flutter/material.dart';
import 'package:frosthaven_assistant/Resource/state/game_state.dart';
import 'package:frosthaven_assistant/Resource/settings.dart';
import 'package:frosthaven_assistant/services/network/bluetooth.dart';
import 'package:frosthaven_assistant/services/network/client.dart';
import 'package:frosthaven_assistant/services/network/connection.dart';
import 'package:get_it/get_it.dart';

import '../Resource/game_data.dart';
import 'network/communication.dart';
import 'network/network.dart';

final getIt = GetIt.instance;

void setupGetIt() {
  getIt.registerLazySingleton<GameData>(() => GameData());
  getIt.registerLazySingleton<Settings>(() => Settings());
  getIt.registerLazySingleton<GameState>(() => GameState());
  getIt.registerLazySingleton<Communication>(() => Communication());
  getIt.registerLazySingleton<Network>(() => Network());
  getIt.registerLazySingleton<Connection>(() => Connection());
  getIt.registerLazySingleton<Client>(() => Client());
  getIt.registerLazySingleton<Bluetooth>(() => Bluetooth());
}

void setupMoreGetIt(BuildContext context) {
  getIt.allowReassignment = true;
  getIt.registerLazySingleton<BuildContext>(() => context);
}
