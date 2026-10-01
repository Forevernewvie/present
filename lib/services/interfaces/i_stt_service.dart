abstract class ISttService {
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(dynamic) onError,
  });

  void listen({
    required void Function(String) onResult,
    required Duration pauseFor,
    required void Function() onEmulatorDone,
  });

  Future<void> stop();
  
  void dispose();
}
