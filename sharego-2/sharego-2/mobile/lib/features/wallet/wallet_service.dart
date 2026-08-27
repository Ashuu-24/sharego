import 'package:dio/dio.dart';

class WalletService {
  WalletService(this._dio);

  final Dio _dio;

  Future<Map<String, dynamic>> getWallet({int limit = 20, int offset = 0}) async {
    final response = await _dio.get(
      '/users/me/wallet',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> topUp(double amount) async {
    final response = await _dio.post(
      '/users/me/wallet/topup',
      data: {'amount': amount},
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<List<dynamic>> getBankAccounts() async {
    final response = await _dio.get('/users/me/bank-accounts');
    return response.data as List;
  }

  Future<Map<String, dynamic>> addBankAccount({
    required String bankName,
    required String accountTitle,
    required String accountNumber,
  }) async {
    final response = await _dio.post(
      '/users/me/bank-accounts',
      data: {
        'bank_name': bankName,
        'account_title': accountTitle,
        'account_number': accountNumber,
      },
    );
    return (response.data as Map).cast<String, dynamic>();
  }

  Future<void> deleteBankAccount(int accountId) async {
    await _dio.delete('/users/me/bank-accounts/$accountId');
  }

  Future<Map<String, dynamic>> withdraw({
    required int bankAccountId,
    required double amount,
  }) async {
    final response = await _dio.post(
      '/users/me/wallet/withdraw',
      data: {'bank_account_id': bankAccountId, 'amount': amount},
    );
    return (response.data as Map).cast<String, dynamic>();
  }
}