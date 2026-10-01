abstract class ITtsService {
  Future<void> speak(String text);
  Future<void> stop();
  void dispose();
}
