import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestPermissions() async {
    // Request Bluetooth and Location permissions
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetooth,
      Permission.location,
    ].request();

    // Check if all permissions are granted
    bool allGranted = statuses.values.every((status) => status.isGranted);
    return allGranted;
  }
}