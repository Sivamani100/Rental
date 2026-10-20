import 'web_preloader_stub.dart'
    if (dart.library.html) 'web_preloader_web.dart';

Map<String, dynamic>? findWebPreloadedProperty(String propertyId) {
  return getWebPreloadedProperty(propertyId);
}
