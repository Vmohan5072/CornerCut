import 'package:hive/hive.dart';
import '../models/lap_model.dart';
import '../models/telemetry_model.dart';

class DataStorageService {
  Future<void> saveLapData(LapModel lapModel) async {
    var box = await Hive.openBox('laps');
    await box.put('lapTimes', lapModel.lapTimes.map((e) => e.inMilliseconds).toList());
  }

  Future<void> saveTelemetryData(TelemetryModel telemetryModel) async {
    var box = await Hive.openBox('telemetry');
    await box.put('dataPoints', telemetryModel.dataPoints.map((e) => e.toMap()).toList());
  }
}