import 'package:sakuramedia/core/network/api_client.dart';
import 'package:sakuramedia/features/account/data/account_dto.dart';

class AccountApi {
  const AccountApi({required ApiClient apiClient}) : _apiClient = apiClient;

  final ApiClient _apiClient;

  Future<AccountDto> getAccount() async {
    final response = await _apiClient.get('/account');
    return AccountDto.fromJson(response);
  }

  Future<AccountDto> updateUsername(String username) async {
    final response = await _apiClient.patch(
      '/account',
      data: <String, dynamic>{'username': username},
    );
    return AccountDto.fromJson(response);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _apiClient.postNoContent(
      '/account/password',
      data: <String, dynamic>{
        'current_password': currentPassword,
        'new_password': newPassword,
      },
    );
  }
}
