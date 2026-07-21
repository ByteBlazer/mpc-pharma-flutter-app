import 'web_tab_visibility_stub.dart'
    if (dart.library.html) 'web_tab_visibility_web.dart';

bool get isMobileWebViewport => isMobileWebViewportImpl();

Stream<bool> webTabVisibilityStream() => webTabVisibilityStreamImpl();
