import 'dart:js_interop';

@JS('removeSplashFromWeb')
external JSFunction? get _removeSplashFn;

@JS('removeSplashFromWeb')
external void _removeSplashFromWeb();

void removeWebSplash() {
  if (_removeSplashFn != null) _removeSplashFromWeb();
}
