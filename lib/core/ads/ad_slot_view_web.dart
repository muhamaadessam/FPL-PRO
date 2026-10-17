import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'ad_config.dart';

final _registeredViewTypes = <String>{};
var _scriptAdded = false;

/// An AdSense unit drawn as an HTML element over the Flutter canvas.
Widget buildAdSlotView(String slot, AdSize size) {
  final viewType = 'adsense-$slot-${size.name}';
  if (_registeredViewTypes.add(viewType)) {
    _ensureScript();
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) => _createUnit(slot, size),
    );
  }
  return HtmlElementView(viewType: viewType);
}

void _ensureScript() {
  if (_scriptAdded) return;
  _scriptAdded = true;
  final script = web.HTMLScriptElement()
    ..async = true
    ..crossOrigin = 'anonymous'
    ..src =
        'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js'
        '?client=${AdConfig.client}';
  web.document.head!.append(script);
}

web.HTMLElement _createUnit(String slot, AdSize size) {
  final ins = web.document.createElement('ins') as web.HTMLElement
    ..className = 'adsbygoogle'
    ..setAttribute('data-ad-client', AdConfig.client)
    ..setAttribute('data-ad-slot', slot);
  if (AdConfig.testMode) ins.setAttribute('data-adtest', 'on');
  ins.style
    ..display = 'inline-block'
    ..width = '${size.width.toInt()}px'
    ..height = '${size.height.toInt()}px';

  final host = web.HTMLDivElement();
  host.style
    ..width = '100%'
    ..height = '100%'
    ..display = 'flex'
    ..justifyContent = 'center'
    ..alignItems = 'center';
  host.append(ins);

  _requestAdWhenAttached(ins);
  return host;
}

/// AdSense needs the unit in the page with a real width before it is filled,
/// and Flutter attaches platform views a moment after creating them.
void _requestAdWhenAttached(web.HTMLElement ins) {
  var attempts = 0;
  Timer.periodic(const Duration(milliseconds: 100), (timer) {
    attempts++;
    if (ins.isConnected && ins.offsetWidth > 0) {
      timer.cancel();
      _push();
    } else if (attempts >= 50) {
      timer.cancel();
    }
  });
}

void _push() {
  final window = web.window as JSObject;
  var queue = window['adsbygoogle'];
  if (queue == null) {
    queue = JSArray<JSAny>();
    window['adsbygoogle'] = queue;
  }
  try {
    (queue as JSObject).callMethod('push'.toJS, JSObject());
  } catch (_) {
    // A unit that is already filled throws; nothing to do.
  }
}
