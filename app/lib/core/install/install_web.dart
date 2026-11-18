import 'dart:js_interop';

import 'install.dart';

@JS('iconInstallState')
external JSString? _state();

@JS('iconInstallNow')
external JSPromise<JSString> _now();

InstallState installState() {
  try {
    return switch (_state()?.toDart) {
      'installed' => InstallState.installed,
      'ready' => InstallState.ready,
      'ios' => InstallState.ios,
      _ => InstallState.none,
    };
  } catch (_) {
    return InstallState.none;
  }
}

/// Shows the browser's own "Install" box. True when the person accepted.
Future<bool> installNow() async {
  try {
    return (await _now().toDart).toDart == 'accepted';
  } catch (_) {
    return false;
  }
}
