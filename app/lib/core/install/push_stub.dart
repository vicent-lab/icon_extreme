import 'push.dart';

Future<PushState> pushState() async => PushState.unsupported;
Future<String> pushEnable(String publicKey) async => 'error:unsupported';
Future<String> pushDisable() async => '';
