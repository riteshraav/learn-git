import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';


void sendPoseToBackend(List<PoseLandmark> landmarks) async {
  final uri = Uri.parse("http://192.168.43.55:8080/pose");

  final List<Map<String, dynamic>> points = landmarks.map((landmark) {
    return {
      'type': landmark.type.name,
      'x': landmark.x,
      'y': landmark.y,
      'z': landmark.z,
    };
  }).toList();

  final body = json.encode({'landmarks': points});

  try {
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    print('Backend Response: ${response.body}');
  } catch (e) {
    print('Error sending pose data: $e');
  }
}