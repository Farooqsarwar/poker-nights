import 'dart:async';

void main() async {
  final completer = Completer<void>();
  try {
    await completer.future.timeout(const Duration(seconds: 1), onTimeout: () {
      print('onTimeout executed');
    });
    print('Finished without exception');
  } catch (e) {
    print('Caught exception: ');
  }
}
