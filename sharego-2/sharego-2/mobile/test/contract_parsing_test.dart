import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyro/core/kyc_error_handler.dart';
import 'package:flyro/features/booking/feature_a_service.dart';

void main() {
  group('matching contract parser', () {
    test('accepts object payload from /matching/suggest', () {
      final parsed = parseMatchingSuggestResponse({
        'requestId': 1,
        'tripId': null,
        'trips': [],
        'requests': [],
      });

      expect(parsed['requestId'], 1);
      expect(parsed['trips'], isA<List>());
      expect(parsed['requests'], isA<List>());
    });

    test('rejects legacy list payload', () {
      expect(
        () => parseMatchingSuggestResponse([]),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('kyc error parser', () {
    DioException dio403(dynamic data) {
      final request = RequestOptions(path: '/trips');
      return DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 403,
          data: data,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    test('detects legacy detail style', () {
      final err = dio403({'detail': 'KYC verification required'});
      expect(isKycError(err), isTrue);
    });

    test('detects unified error envelope style', () {
      final err = dio403({
        'error': {'code': 'http_403', 'message': 'KYC verification required'},
      });
      expect(isKycError(err), isTrue);
    });

    test('does not flag non-kyc 403 errors', () {
      final err = dio403({
        'error': {'code': 'http_403', 'message': 'Not owner'},
      });
      expect(isKycError(err), isFalse);
    });
  });
}
