import 'package:flutter/foundation.dart';
import 'session.dart';

class SessionModel with ChangeNotifier {
  List<Session> sessions = [];

  void addSession(Session session) {
    sessions.add(session);
    notifyListeners();
  }
}