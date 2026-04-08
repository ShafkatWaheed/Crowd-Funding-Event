/// Mock payment repository and shared test mocks using mocktail.
library;

import 'package:dio/dio.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crowd_funding_app/repositories/payment_repository.dart';
class MockPaymentRepository extends Mock implements PaymentRepository {}

class MockDio extends Mock implements Dio {}
