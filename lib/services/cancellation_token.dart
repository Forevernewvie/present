/// 비동기 네트워크 요청 및 작업을 안전하게 취소하기 위한 토큰
class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  final List<void Function()> _listeners = [];

  /// 작업을 취소하고 등록된 모든 리스너(소켓 닫기 등)를 즉각 트리거합니다.
  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (_) {}
    }
    _listeners.clear();
  }

  /// 취소 발생 시 실행할 콜백 등록
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }
}

class CancelledException implements Exception {
  final String message;
  CancelledException([this.message = '작업이 취소되었습니다.']);

  @override
  String toString() => message;
}
