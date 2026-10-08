{{flutter_js}}
{{flutter_build_config}}

// Sin service worker: así el navegador siempre pide la versión más reciente del juego
// (el service worker de Flutter dejaba a los dispositivos con versiones viejas guardadas).
_flutter.loader.load();
