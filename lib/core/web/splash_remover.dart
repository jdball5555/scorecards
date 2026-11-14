// Removes the HTML loading splash (web/index.html) once Flutter has drawn its
// first frame. No-op on mobile/desktop.
export 'splash_remover_stub.dart'
    if (dart.library.js_interop) 'splash_remover_web.dart';
