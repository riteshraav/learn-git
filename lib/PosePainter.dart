import 'dart:math';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'coordinates_translator.dart';
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;
  PosePainter(this.poses, this.imageSize, this.rotation, this.cameraLensDirection,);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..color = Colors.green;

    final leftPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    final rightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.blueAccent;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
            Offset(
              translateX(
                landmark.x,
                size,
                imageSize,
                rotation,
                cameraLensDirection,
              ),
              translateY(
                landmark.y,
                size,
                imageSize,
                rotation,
                cameraLensDirection,
              ),
            ),
            1,
            paint);
      });

      void paintLine(
          PoseLandmarkType type1, PoseLandmarkType type2, Paint paintType) {
        final PoseLandmark joint1 = pose.landmarks[type1]!;
        final PoseLandmark joint2 = pose.landmarks[type2]!;
        canvas.drawLine(
            Offset(
                translateX(
                  joint1.x,
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                ),
                translateY(
                  joint1.y,
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                )),
            Offset(
                translateX(
                  joint2.x,
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                ),
                translateY(
                  joint2.y,
                  size,
                  imageSize,
                  rotation,
                  cameraLensDirection,
                )),
            paintType);
      }

      //Draw arms
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow, leftPaint);
      paintLine(
          PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow,
          rightPaint);
      paintLine(
          PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist, rightPaint);

      //Draw Body
      paintLine(
          PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip, leftPaint);
      paintLine(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip,
          rightPaint);
      //
      // //Draw legs
      // paintLine(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee, leftPaint);
      // paintLine(
      //     PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle, leftPaint);
      // paintLine(
      //     PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee, rightPaint);
      // paintLine(
      //     PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle, rightPaint);
      double _getAngle(PoseLandmark first, PoseLandmark mid, PoseLandmark last) {
        final x1 = first.x, y1 = first.y;
        final x2 = mid.x, y2 = mid.y;
        final x3 = last.x, y3 = last.y;

        double radians = atan2(y3 - y2, x3 - x2) - atan2(y1 - y2, x1 - x2);
        double angle = radians * (180 / pi);
        angle = angle.abs();
        if (angle > 180) angle = 360 - angle;
        return angle;
      }
      void paintAngleWithLines({
        required Canvas canvas,
        required Pose pose,
        required PoseLandmarkType first,
        required PoseLandmarkType mid,
        required PoseLandmarkType last,
        required Size size,
        required Size imageSize,
        required InputImageRotation rotation,
        required CameraLensDirection cameraLensDirection,
        required Paint linePaint,
        required TextPainter textPainter,
        required TextStyle textStyle,
      }) {
        final joint1 = pose.landmarks[first]!;
        final joint2 = pose.landmarks[mid]!;
        final joint3 = pose.landmarks[last]!;

        final Offset p1 = Offset(
          translateX(joint1.x, size, imageSize, rotation, cameraLensDirection),
          translateY(joint1.y, size, imageSize, rotation, cameraLensDirection),
        );

        final Offset p2 = Offset(
          translateX(joint2.x, size, imageSize, rotation, cameraLensDirection),
          translateY(joint2.y, size, imageSize, rotation, cameraLensDirection),
        );

        final Offset p3 = Offset(
          translateX(joint3.x, size, imageSize, rotation, cameraLensDirection),
          translateY(joint3.y, size, imageSize, rotation, cameraLensDirection),
        );

        // Draw lines: p1 → p2 and p2 → p3
        canvas.drawLine(p1, p2, linePaint);
        canvas.drawLine(p2, p3, linePaint);

        // Calculate angle at p2
        double angle = _getAngle(joint1, joint2, joint3);
        String angleText = '${angle.toStringAsFixed(1)}°';

        // Draw angle as text near p2
        textPainter.text = TextSpan(
          text: angleText,
          style: textStyle,
        );
        textPainter.layout();
        textPainter.paint(canvas, p2.translate(10, -10)); // position offset
      }
      final TextPainter leftTextPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      final TextStyle leftTextStyle = TextStyle(
        color: Colors.yellow,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );
      final TextPainter rightTextPainter = TextPainter(
        textDirection: TextDirection.ltr,
      );

      final TextStyle rightTextStyle = TextStyle(
        color: Colors.blueAccent,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      );
      paintAngleWithLines(canvas: canvas, pose: pose, first: PoseLandmarkType.leftHip, mid: PoseLandmarkType.leftKnee, last: PoseLandmarkType.leftHeel, size: size, imageSize: imageSize, rotation: rotation, cameraLensDirection: cameraLensDirection, linePaint: leftPaint, textPainter: leftTextPainter, textStyle: leftTextStyle);
      paintAngleWithLines(canvas: canvas, pose: pose, first: PoseLandmarkType.rightHip, mid: PoseLandmarkType.rightKnee, last: PoseLandmarkType.rightHeel, size: size, imageSize: imageSize, rotation: rotation, cameraLensDirection: cameraLensDirection, linePaint: rightPaint, textPainter: rightTextPainter, textStyle: rightTextStyle);



    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) {
    return oldDelegate.imageSize != imageSize || oldDelegate.poses != poses;
  }

}