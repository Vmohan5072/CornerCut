import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'dart:typed_data';

class BluetoothService {
  BluetoothConnection? connection;

  Future<void> connectToDevice(String address) async {
    try {
      connection = await BluetoothConnection.toAddress(address);
      print('Connected to the device');
      connection!.input!.listen((Uint8List data) {
        String receivedData = String.fromCharCodes(data);
        print('Data received: $receivedData');
        // Parse OBD-II data here
      }).onDone(() {
        print('Disconnected from the device');
      });
    } catch (e) {
      print('Error connecting to device: $e');
    }
  }

  void disconnect() {
    connection?.close();
    connection = null;
  }

  void sendData(String data) {
    connection?.output.add(Uint8List.fromList(data.codeUnits));
  }
}