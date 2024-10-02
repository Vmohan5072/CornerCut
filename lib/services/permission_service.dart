import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // Request Location Permission
  static Future<bool> requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
    return status.isGranted;
  }
  // Request Bluetooth Permission
  static Future<bool> requestBluetoothPermission() async {
    var status = await Permission.bluetooth.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.bluetooth.request();
      return status.isGranted;
    }
    return status.isGranted;
  }
}