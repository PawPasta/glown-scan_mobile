import 'package:flutter/foundation.dart';

class AuthRequestStatus extends ChangeNotifier {
  AuthRequestStatus._();

  static final instance = AuthRequestStatus._();

  int _refreshCount = 0;
  int _sessionExpirationVersion = 0;

  bool get isRefreshing => _refreshCount > 0;
  int get sessionExpirationVersion => _sessionExpirationVersion;

  void beginRefresh() {
    _refreshCount++;
    notifyListeners();
  }

  void endRefresh() {
    if (_refreshCount == 0) return;
    _refreshCount--;
    notifyListeners();
  }

  void expireSession() {
    _sessionExpirationVersion++;
    notifyListeners();
  }
}
