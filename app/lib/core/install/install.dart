// Installing the app on a phone or computer. On the web this talks to the small script in web/index.html;
// everywhere else (Android/iOS builds) there is nothing to install, so it reports "installed".
export 'install_stub.dart' if (dart.library.js_interop) 'install_web.dart';

enum InstallState { installed, ready, ios, none }
