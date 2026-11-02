class ApiEndpoints {
  ApiEndpoints._();

  static const register = '/auth/register';
  static const loginMobile = '/auth/mobile/login';
  static const resendEmailVerification = '/auth/verify-email/resend';
  static const checkEmailVerification = '/auth/verify-email/check';
  static const requestPasswordReset = '/auth/password/reset/request';
  static const resendPasswordReset = '/auth/password/reset/resend';
  static const checkPasswordReset = '/auth/password/reset/check';
  static const confirmPasswordReset = '/auth/password/reset/confirm';
  static const changePassword = '/auth/password/change';
  static const refresh = '/auth/refresh';
  static const logout = '/auth/logout';
  static const firebaseLogin = '/auth/firebase/mobile/login';
  static const profile = '/auth/profile';
  static const avatarUploadIntent = '/auth/profile/avatar/upload-intent';
  static const avatarConfirm = '/auth/profile/avatar/confirm';
}
