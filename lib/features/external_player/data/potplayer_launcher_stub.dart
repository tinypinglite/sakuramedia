/// 非 Web / 非 IO 环境（一般不会走到）的安全降级实现。
library;

bool isPotPlayerSupported() => false;

Future<bool> launchPotPlayerDeepLink(String url) async => false;
