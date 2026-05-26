class AppSession {
  AppSession._();

  static final AppSession instance = AppSession._();

  String? token;
  String? fullName;
  String? email;
  bool showGuideAfterLogin = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  void clear() {
    token = null;
    fullName = null;
    email = null;
    showGuideAfterLogin = false;
  }
}
