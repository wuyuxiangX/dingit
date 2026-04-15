import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/env/env_config.dart';

class SettingsState {
  final String serverUrl;
  final String apiKey;
  final bool isLoaded;

  /// Do Not Disturb window. Local wall-clock bounds; cross-midnight
  /// windows (e.g. 22:00 → 08:00) are supported.
  final bool dndEnabled;
  final TimeOfDay dndStart;
  final TimeOfDay dndEnd;

  const SettingsState({
    this.serverUrl = '',
    this.apiKey = '',
    this.isLoaded = false,
    this.dndEnabled = false,
    this.dndStart = const TimeOfDay(hour: 22, minute: 0),
    this.dndEnd = const TimeOfDay(hour: 8, minute: 0),
  });

  SettingsState copyWith({
    String? serverUrl,
    String? apiKey,
    bool? isLoaded,
    bool? dndEnabled,
    TimeOfDay? dndStart,
    TimeOfDay? dndEnd,
  }) {
    return SettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      isLoaded: isLoaded ?? this.isLoaded,
      dndEnabled: dndEnabled ?? this.dndEnabled,
      dndStart: dndStart ?? this.dndStart,
      dndEnd: dndEnd ?? this.dndEnd,
    );
  }

  /// Derive WebSocket URL from server URL.
  /// e.g. http://localhost:8080 -> ws://localhost:8080/ws
  String get wsUrl {
    if (serverUrl.isEmpty) return EnvConfig.wsUrl;
    final uri = Uri.tryParse(serverUrl);
    if (uri == null) return EnvConfig.wsUrl;
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$scheme://${uri.host}:${uri.port}/ws';
  }

  /// Derive API URL from server URL.
  String get apiUrl {
    if (serverUrl.isEmpty) return EnvConfig.apiUrl;
    return serverUrl;
  }

  /// Wire format the server expects: zero-padded "HH:MM", or empty when
  /// DND is off (server treats empty as "not set").
  String get dndStartWire => dndEnabled ? _formatTimeOfDay(dndStart) : '';
  String get dndEndWire => dndEnabled ? _formatTimeOfDay(dndEnd) : '';
}

String _formatTimeOfDay(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

TimeOfDay? _parseTimeOfDay(String? s) {
  if (s == null || s.isEmpty) return null;
  final parts = s.split(':');
  if (parts.length != 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

const _serverUrlKey = 'server_url';
const _apiKeyStorageKey = 'api_key';
const _dndEnabledKey = 'dnd_enabled';
const _dndStartKey = 'dnd_start';
const _dndEndKey = 'dnd_end';

final settingsProvider =
    NotifierProvider<SettingsNotifier, SettingsState>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<SettingsState> {
  static const _secureStorage = FlutterSecureStorage();

  @override
  SettingsState build() {
    _loadSettings();
    return const SettingsState();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final serverUrl = prefs.getString(_serverUrlKey) ?? EnvConfig.apiUrl;
    final apiKey = await _secureStorage.read(key: _apiKeyStorageKey) ?? '';
    final dndEnabled = prefs.getBool(_dndEnabledKey) ?? false;
    final dndStart = _parseTimeOfDay(prefs.getString(_dndStartKey)) ??
        const TimeOfDay(hour: 22, minute: 0);
    final dndEnd = _parseTimeOfDay(prefs.getString(_dndEndKey)) ??
        const TimeOfDay(hour: 8, minute: 0);
    state = SettingsState(
      serverUrl: serverUrl,
      apiKey: apiKey,
      isLoaded: true,
      dndEnabled: dndEnabled,
      dndStart: dndStart,
      dndEnd: dndEnd,
    );
  }

  Future<void> setServerUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverUrlKey, url);
    state = state.copyWith(serverUrl: url);
  }

  Future<void> setApiKey(String key) async {
    await _secureStorage.write(key: _apiKeyStorageKey, value: key);
    state = state.copyWith(apiKey: key);
  }

  Future<void> saveAll({
    required String serverUrl,
    required String apiKey,
    required bool dndEnabled,
    required TimeOfDay dndStart,
    required TimeOfDay dndEnd,
  }) async {
    final oldWsUrl = state.wsUrl;
    await setServerUrl(serverUrl);
    await setApiKey(apiKey);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dndEnabledKey, dndEnabled);
    await prefs.setString(_dndStartKey, _formatTimeOfDay(dndStart));
    await prefs.setString(_dndEndKey, _formatTimeOfDay(dndEnd));
    state = state.copyWith(
      dndEnabled: dndEnabled,
      dndStart: dndStart,
      dndEnd: dndEnd,
    );

    // Notify listeners that URL changed so WebSocket can reconnect
    if (oldWsUrl != state.wsUrl) {
      ref.notifyListeners();
    }
  }

  /// Sign out: clear persisted server URL + API key and reset the in-memory
  /// state. The caller is responsible for disconnecting the active WebSocket
  /// and clearing any notification caches.
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverUrlKey);
    await prefs.remove(_dndEnabledKey);
    await prefs.remove(_dndStartKey);
    await prefs.remove(_dndEndKey);
    await _secureStorage.delete(key: _apiKeyStorageKey);
    state = const SettingsState(
      serverUrl: '',
      apiKey: '',
      isLoaded: true,
    );
  }
}
