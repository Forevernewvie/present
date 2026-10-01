import '../cancellation_token.dart';

abstract class IOpenAiService {
  Future<String> getAiReply({
    required String userMessage,
    List<dynamic> history = const [],
    String persona = 'child',
    CancellationToken? cancelToken,
  });
}
