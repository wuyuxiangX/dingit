import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/env/env_config.dart';

class SettingsState {
  final String serverUrl;
  final String apiKey;
  final bool isLoaded;

  const SettingsState({
    this.serverUrl = '',
    this.apiKey = '',
    this.isLoaded = false,
  });

  SettingsState copyWith({
    String? serverUrl,
    String? apiKey,
    bool? isLoaded,
  }) {
    return SettingsState(
      serverUrl: serverUrl ?? this.serverUrl,
      apiKey: apiKey ?? this.apiKey,
      isLoaded: isLoaded ?? this.isLoaded,
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
}

const _serverUrlKey = 'server_url';
const _apiKeyStorageKey = 'api_key';

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
    state = SettingsState(
      serverUrl: serverUrl,
      apiKey: apiKey,
      isLoaded: true,
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

  Future<void> saveAll({required String serverUrl, required String apiKey}) async {
    final oldWsUrl = state.wsUrl;
    await setServerUrl(serverUrl);
    await setApiKey(apiKey);
    final newWsUrl = state.wsUrl;

    // Notify listeners that URL changed so WebSocket can reconnect
    if (oldWsUrl != newWsUrl) {
      ref.notifyListeners();
    }
  }
}
