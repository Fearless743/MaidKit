import 'caddy_web_server_adapter.dart';
import 'nginx_web_server_adapter.dart';
import 'web_server_adapter.dart';

/// Built-in web server adapters. Order is the preferred UI listing order.
const List<WebServerAdapter> builtInWebServerAdapters = [
  NginxWebServerAdapter(),
  CaddyWebServerAdapter(),
];

WebServerAdapter? webServerAdapterById(String id) {
  for (final adapter in builtInWebServerAdapters) {
    if (adapter.id == id) return adapter;
  }
  return null;
}
