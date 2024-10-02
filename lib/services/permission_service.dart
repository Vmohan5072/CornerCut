import 'package:permission_handler/permission_handler.dart';
//request location permission
class PermissionService {
  static Future<bool> requestLocationPermission() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      status = await Permission.locationWhenInUse.request();
      return status.isGranted;
    }
    return status.isGranted;
  }
//request bluetooth permission
  static Future<bool> requestBluetoothPermission() async {
  var status = await Permission.bluetoothScan.status;
  if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
    status = await Permission.bluetoothScan.request();
    return status.isGranted;
  }
  return status.isGranted;
  }
}