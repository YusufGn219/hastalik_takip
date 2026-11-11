import 'package:permission_handler/permission_handler.dart';

import '../../domain/step_permission.dart';

/// Android'in `ACTIVITY_RECOGNITION` izni (Android 10 ve üstünde çalışma anında
/// istenir; daha eski sürümlerde izin otomatik verilmiş sayılır).
class AndroidStepPermission implements StepPermission {
  const AndroidStepPermission();

  @override
  Future<StepPermissionState> status() async =>
      _map(await Permission.activityRecognition.status);

  @override
  Future<StepPermissionState> request() async =>
      _map(await Permission.activityRecognition.request());

  @override
  Future<void> openSettings() async {
    await openAppSettings();
  }

  StepPermissionState _map(PermissionStatus s) {
    if (s.isGranted || s.isLimited) return StepPermissionState.granted;
    if (s.isPermanentlyDenied || s.isRestricted) {
      return StepPermissionState.permanentlyDenied;
    }
    return StepPermissionState.denied;
  }
}
