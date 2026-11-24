import 'dart:io';

/// Binds a local helper port, reporting instead of throwing when it is taken.
///
/// A hot restart can leave the previous isolate still holding the port, and a
/// debug helper is never worth crashing the app over: the caller gets `null`
/// and a warning, and everything else keeps working.
Future<HttpServer?> bindOptional(
  InternetAddress address,
  int port, {
  bool shared = false,
  void Function(Object error)? onWarning,
}) async {
  try {
    return await HttpServer.bind(address, port, shared: shared);
  } on SocketException catch (error) {
    onWarning?.call(error);
    return null;
  }
}
