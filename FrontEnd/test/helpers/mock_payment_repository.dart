/// Mock payment repository and shared test mocks using mocktail.
library;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import '../../lib/repositories/payment_repository.dart';
import '../../lib/services/chat_socket_service.dart';

class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockDio extends Mock implements Dio {}

class MockChatSocketService extends Mock implements ChatSocketService {}
