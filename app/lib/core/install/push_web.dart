import 'dart:js_interop';

import 'push.dart';

@JS('iconPushState')
external JSPromise<JSString> _state();
@JS('iconPushEnable')
external JSPromise<JSString> _enable(JSString key);
@JS('iconPushDisable')
external JSPromise<JSString> _disable();

Future<PushState> pushState() async {
  try {
    return switch ((await _state().toDart).toDart) {
      'on' => PushState.on,
      'blocked' => PushState.blocked,
      'needs-install' => PushState.needsInstall,
      'unsupported' => PushState.unsupported,
      _ => PushState.off,
    };
  } catch (_) {
    return PushState.unsupported;
  }
}

/// The device's subscription as JSON text, or `error:reason`.
Future<String> pushEnable(String publicKey) async {
  try {
    return (await _enable(publicKey.toJS).toDart).toDart;
  } catch (e) {
    return 'error:$e';
  }
}

/// The endpoint that was switched off ('' when there was none).
Future<String> pushDisable() async {
  try {
    return (await _disable().toDart).toDart;
  } catch (_) {
    return '';
  }
}
