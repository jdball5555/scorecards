import 'dart:js_interop';

@JS('clearInviteFromUrl')
external JSFunction? get _clearFn;

@JS('clearInviteFromUrl')
external void _clearInviteFromUrl();

void clearInviteFromUrl() {
  if (_clearFn != null) _clearInviteFromUrl();
}
