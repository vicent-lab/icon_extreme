// Phone alerts on the web (through web/index.html). Other platforms report "unsupported".
export 'push_stub.dart' if (dart.library.js_interop) 'push_web.dart';

enum PushState { on, off, blocked, needsInstall, unsupported }
