import 'package:flutter_test/flutter_test.dart';
import 'package:sakuramedia/core/network/network_proxy.dart';

void main() {
  const config = NetworkProxyConfig(host: '127.0.0.1', port: 7890);

  group('parseNetworkProxyAddress', () {
    test('accepts host:port and http URLs', () {
      expect(
        parseNetworkProxyAddress('127.0.0.1:7890'),
        const NetworkProxyConfig(host: '127.0.0.1', port: 7890),
      );
      expect(
        parseNetworkProxyAddress('http://127.0.0.1:7890'),
        const NetworkProxyConfig(host: '127.0.0.1', port: 7890),
      );
      expect(
        parseNetworkProxyAddress('  http://127.0.0.1:7890/  '),
        const NetworkProxyConfig(host: '127.0.0.1', port: 7890),
      );
    });

    test('accepts IPv6 hosts', () {
      expect(
        parseNetworkProxyAddress('http://[::1]:7890'),
        const NetworkProxyConfig(host: '::1', port: 7890),
      );
      expect(
        parseNetworkProxyAddress('[::1]:7890'),
        const NetworkProxyConfig(host: '::1', port: 7890),
      );
    });

    test('empty input means unset', () {
      expect(parseNetworkProxyAddress(''), isNull);
      expect(parseNetworkProxyAddress('   '), isNull);
    });

    test('rejects unsupported schemes', () {
      expect(parseNetworkProxyAddress('socks5://127.0.0.1:7890'), isNull);
      expect(parseNetworkProxyAddress('https://127.0.0.1:7890'), isNull);
    });

    test('requires an explicit valid port', () {
      expect(parseNetworkProxyAddress('127.0.0.1'), isNull);
      expect(parseNetworkProxyAddress('http://127.0.0.1'), isNull);
      expect(parseNetworkProxyAddress('http://127.0.0.1:0'), isNull);
      expect(parseNetworkProxyAddress('http://127.0.0.1:70000'), isNull);
    });

    test('rejects credentials, paths, queries and fragments', () {
      expect(
        parseNetworkProxyAddress('http://user:pass@127.0.0.1:7890'),
        isNull,
      );
      expect(parseNetworkProxyAddress('http://127.0.0.1:7890/path'), isNull);
      expect(parseNetworkProxyAddress('http://127.0.0.1:7890?x=1'), isNull);
      expect(parseNetworkProxyAddress('http://127.0.0.1:7890#frag'), isNull);
      expect(parseNetworkProxyAddress('http://:7890'), isNull);
    });

    test('formats display address and findProxy directive', () {
      expect(config.displayAddress, '127.0.0.1:7890');
      expect(config.findProxyDirective, 'PROXY 127.0.0.1:7890');
      const ipv6 = NetworkProxyConfig(host: '::1', port: 7890);
      expect(ipv6.displayAddress, '[::1]:7890');
      expect(ipv6.findProxyDirective, 'PROXY [::1]:7890');
    });
  });

  group('resolveProxyDirective', () {
    String resolve(String url, [NetworkProxyConfig? proxy = config]) {
      return resolveProxyDirective(Uri.parse(url), proxy);
    }

    test('returns DIRECT without config', () {
      expect(resolve('https://github.com', null), 'DIRECT');
      expect(resolve('http://192.168.1.10:38000', null), 'DIRECT');
    });

    test('keeps loopback targets direct', () {
      expect(resolve('http://localhost:38000'), 'DIRECT');
      expect(resolve('http://app.localhost:38000'), 'DIRECT');
      expect(resolve('http://127.0.0.1:38000'), 'DIRECT');
      expect(resolve('http://127.8.9.10:38000'), 'DIRECT');
      expect(resolve('http://[::1]:38000'), 'DIRECT');
    });

    test('proxies private ranges, backend and public hosts', () {
      expect(resolve('http://192.168.1.10:38000'), 'PROXY 127.0.0.1:7890');
      expect(resolve('http://10.0.0.5:38000'), 'PROXY 127.0.0.1:7890');
      expect(resolve('https://github.com/a/b'), 'PROXY 127.0.0.1:7890');
      expect(
        resolve('https://api.github.com/repos/a/b'),
        'PROXY 127.0.0.1:7890',
      );
    });
  });

  group('isLoopbackHost', () {
    test('recognizes loopback aliases and addresses', () {
      expect(isLoopbackHost('localhost'), isTrue);
      expect(isLoopbackHost('LOCALHOST'), isTrue);
      expect(isLoopbackHost('media.localhost'), isTrue);
      expect(isLoopbackHost('127.0.0.1'), isTrue);
      expect(isLoopbackHost('127.255.255.255'), isTrue);
      expect(isLoopbackHost('::1'), isTrue);
    });

    test('rejects non-loopback hosts', () {
      expect(isLoopbackHost('192.168.1.10'), isFalse);
      expect(isLoopbackHost('10.0.0.5'), isFalse);
      expect(isLoopbackHost('github.com'), isFalse);
      expect(isLoopbackHost(''), isFalse);
    });
  });
}
