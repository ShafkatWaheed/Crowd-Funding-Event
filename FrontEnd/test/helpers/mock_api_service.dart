/// Mock ApiService for tests using mocktail.
library;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/services/api_service.dart';
import '../../lib/services/chat_socket_service.dart';

class MockApiService extends Mock implements ApiService {
  final MockDio mockDio = MockDio();

  @override
  Dio get dio => mockDio;
}

class MockDio extends Mock implements Dio {}

class MockChatSocketService extends Mock implements ChatSocketService {}
