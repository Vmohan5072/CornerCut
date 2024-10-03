import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class SpeedometerGauge extends StatelessWidget {
  final double speed;

  const SpeedometerGauge({super.key, required this.speed});

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 200,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 200, color: Colors.blue),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: speed),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '${speed.toStringAsFixed(0)} mph',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.7,
            ),
          ],
        ),
      ],
    );
  }
}

class TachometerGauge extends StatelessWidget {
  final double rpm;

  const TachometerGauge({super.key, required this.rpm});

  @override
  Widget build(BuildContext context) {
    return SfRadialGauge(
      axes: <RadialAxis>[
        RadialAxis(
          minimum: 0,
          maximum: 8000,
          ranges: <GaugeRange>[
            GaugeRange(startValue: 0, endValue: 8000, color: Colors.red),
          ],
          pointers: <GaugePointer>[
            NeedlePointer(value: rpm),
          ],
          annotations: <GaugeAnnotation>[
            GaugeAnnotation(
              widget: Text(
                '${rpm.toStringAsFixed(0)} RPM',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              angle: 90,
              positionFactor: 0.7,
            ),
          ],
        ),
      ],
    );
  }
}

class ThrottleBrakeIndicator extends StatelessWidget {
  final double throttle;
  final double brake;

  const ThrottleBrakeIndicator({
    super.key,
    required this.throttle,
    required this.brake,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Throttle Indicator
        Column(
          children: [
            const Text(
              'Throttle',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(
              height: 100,
              width: 20,
              child: RotatedBox(
                quarterTurns: -1,
                child: LinearProgressIndicator(
                  value: throttle / 100,
                  backgroundColor: Colors.white24,
                  color: Colors.green,
                ),
              ),
            ),
            Text(
              '${throttle.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        // Brake Indicator
        Column(
          children: [
            const Text(
              'Brake',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            SizedBox(
              height: 100,
              width: 20,
              child: RotatedBox(
                quarterTurns: -1,
                child: LinearProgressIndicator(
                  value: brake / 100,
                  backgroundColor: Colors.white24,
                  color: Colors.red,
                ),
              ),
            ),
            Text(
              '${brake.toStringAsFixed(0)}%',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ],
    );
  }
}