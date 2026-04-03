import 'package:flutter/foundation.dart';

/// Global app state for broadcasting data change events.
/// When any screen saves/adds/deletes data, call [refresh()] to notify
/// all listening screens to reload from the database.
class AppState {
  static final AppState instance = AppState._();
  AppState._();

  final ValueNotifier<int> dataVersion = ValueNotifier<int>(0);

  /// Call this after inserting, updating or deleting any record.
  void refresh() {
    dataVersion.value++;
  }
}
