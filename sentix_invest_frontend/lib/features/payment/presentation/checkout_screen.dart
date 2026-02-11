// Conditional export: uses web implementation on web, stub on native platforms.
export 'checkout_screen_stub.dart'
    if (dart.library.html) 'checkout_screen_web.dart';
