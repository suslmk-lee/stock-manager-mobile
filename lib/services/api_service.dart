import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/constants.dart';
import '../models/account.dart';
import '../models/asset.dart';
import '../models/dividend.dart';
import '../models/transaction.dart';

final apiServiceProvider = Provider<ApiService>((ref) => ApiService());

class ApiService {
  late final Dio _dio;

  ApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        if (ApiConstants.apiKey.isNotEmpty)
          'Authorization': 'Bearer ${ApiConstants.apiKey}',
      },
    ));

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Fail early with a clear message when API_KEY is not injected.
          if (ApiConstants.apiKey.isEmpty) {
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 401,
                  statusMessage: 'API_KEY_MISSING',
                ),
                message:
                    'API_KEY가 설정되지 않았습니다. flutter run --dart-define-from-file=.env.json 으로 실행하세요.',
                error:
                    'API_KEY가 설정되지 않았습니다. flutter run --dart-define-from-file=.env.json 으로 실행하세요.',
              ),
            );
          }
          handler.next(options);
        },
        onError: (error, handler) {
          final userMessage = _toUserMessage(error);
          handler.reject(
            error.copyWith(
              message: userMessage,
              error: userMessage,
            ),
          );
        },
      ),
    );
  }

  String _toUserMessage(DioException e) {
    if (ApiConstants.apiKey.isEmpty) {
      return 'API_KEY가 설정되지 않았습니다. .env.json을 만든 뒤 --dart-define-from-file=.env.json 옵션으로 실행하세요.';
    }

    final statusCode = e.response?.statusCode;
    if (statusCode == 401) {
      return '인증 실패(401): API_KEY가 없거나 올바르지 않습니다.';
    }
    if (statusCode != null) {
      return '서버 요청 실패($statusCode): 잠시 후 다시 시도해 주세요.';
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return '요청 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.';
      case DioExceptionType.connectionError:
        return '네트워크 연결 오류가 발생했습니다.';
      default:
        return '서버 연결 중 오류가 발생했습니다.';
    }
  }

  // Accounts
  Future<List<Account>> getAccounts() async {
    final res = await _dio.get('/accounts');
    return (res.data as List).map((e) => Account.fromJson(e)).toList();
  }

  Future<Account> createAccount(Map<String, dynamic> data) async {
    final res = await _dio.post('/accounts', data: data);
    return Account.fromJson(res.data);
  }

  Future<void> updateAccount(int id, Map<String, dynamic> data) async {
    await _dio.put('/accounts/$id', data: data);
  }

  Future<void> deleteAccount(int id) async {
    await _dio.delete('/accounts/$id');
  }

  // Assets
  Future<List<Asset>> getAssets() async {
    final res = await _dio.get('/assets');
    return (res.data as List).map((e) => Asset.fromJson(e)).toList();
  }

  Future<Asset> createAsset(Map<String, dynamic> data) async {
    final res = await _dio.post('/assets', data: data);
    return Asset.fromJson(res.data);
  }

  Future<void> updateAsset(int id, Map<String, dynamic> data) async {
    await _dio.put('/assets/$id', data: data);
  }

  Future<void> deleteAsset(int id) async {
    await _dio.delete('/assets/$id');
  }

  // Holdings
  Future<void> updateHolding(int id, Map<String, dynamic> data) async {
    await _dio.put('/holdings/$id', data: data);
  }

  Future<void> deleteHolding(int id) async {
    await _dio.delete('/holdings/$id');
  }

  // Transactions
  Future<List<Transaction>> getAccountTransactions(int accountId) async {
    final res = await _dio.get('/accounts/$accountId/transactions');
    return (res.data as List).map((e) => Transaction.fromJson(e)).toList();
  }

  Future<Transaction> createTransaction(Map<String, dynamic> data) async {
    final res = await _dio.post('/transactions', data: data);
    return Transaction.fromJson(res.data);
  }

  // Dividends
  Future<DividendStats> getDividendStats() async {
    final res = await _dio.get('/dividends/stats');
    return DividendStats.fromJson(res.data);
  }

  Future<List<Dividend>> getAccountDividends(int accountId) async {
    final res = await _dio.get('/accounts/$accountId/dividends');
    return (res.data as List).map((e) => Dividend.fromJson(e)).toList();
  }

  Future<List<MonthlyDividend>> getMonthlyDividends({
    String? startDate,
    String? endDate,
  }) async {
    final res = await _dio.get('/dividends/monthly', queryParameters: {
      'startDate': startDate,
      'endDate': endDate,
    }..removeWhere((_, v) => v == null));
    return (res.data as List).map((e) => MonthlyDividend.fromJson(e)).toList();
  }

  Future<Dividend> createDividend(Map<String, dynamic> data) async {
    final res = await _dio.post('/dividends', data: data);
    return Dividend.fromJson(res.data);
  }

  Future<Dividend> updateDividend(int id, Map<String, dynamic> data) async {
    final res = await _dio.put('/dividends/$id', data: data);
    return Dividend.fromJson(res.data);
  }

  Future<void> deleteDividend(int id) async {
    await _dio.delete('/dividends/$id');
  }

  // Utilities
  Future<double> getExchangeRate() async {
    final res = await _dio.get('/exchange-rate/usd-krw');
    return (res.data as num).toDouble();
  }

  Future<Map<String, dynamic>> getTickerInfo(String ticker) async {
    final res = await _dio.get('/ticker/info', queryParameters: {'ticker': ticker});
    return res.data;
  }

  Future<Map<String, dynamic>> getTickerPrice(String ticker) async {
    final res = await _dio.get('/ticker/price', queryParameters: {'ticker': ticker});
    return res.data;
  }
}
