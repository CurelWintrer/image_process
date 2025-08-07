import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  static final UserSession _instance = UserSession._internal();

  factory UserSession() => _instance;

  UserSession._internal();

  String? token;
  String? name;
  String? email;
  int? role;
  int? id;
  String baseUrl = 'http://10.1.5.103:3000';
  String apiUrl = 'https://api.shubiaobiao.com/v1/chat/completions';
  String apiKey = 'sk-D6lEXIuoNQ1aK6OWf0WD5jwKkhabovIyfxkHYVKPRqveGdj4';
  String modelName='gemini-2.5-pro';
  String getRepetPath = '';
  String version='0.0.1';

  /// 保存设置的键值常量
  static const String _baseUrlKey = 'system_baseUrl';
  static const String _apiUrlKey = 'system_apiUrl';
  static const String _apiKeyKey = 'system_apiKey';
  static const String _getRepetPath = 'systemRepetPath';
  static const String _modelName='system_modelName';

  bool get isLoggedIn => token != null;

  /// 初始化时从 SharedPreferences 加载用户信息
  Future<void> loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    //  prefs.clear();

    token = prefs.getString('token');
    name = prefs.getString('name');
    email = prefs.getString('email');
    role = prefs.getInt('role');
    id = prefs.getInt('userID');

    // 加载系统设置
    baseUrl = prefs.getString(_baseUrlKey) ?? baseUrl; // 保持默认值
    apiUrl = prefs.getString(_apiUrlKey) ?? apiUrl;
    apiKey = prefs.getString(_apiKeyKey) ?? apiKey;
    getRepetPath = prefs.getString(_getRepetPath) ?? getRepetPath;
    modelName=prefs.getString(_modelName) ?? modelName;
  }

  /// 新增：专用方法保存系统设置
  Future<void> saveSystemSettings({
    required String newBaseUrl,
    required String newApiUrl,
    required String newApiKey,
    required String newGetRepetPath,
    required String newModelName,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_baseUrlKey, newBaseUrl);
    await prefs.setString(_apiUrlKey, newApiUrl);
    await prefs.setString(_apiKeyKey, newApiKey);
    await prefs.setString(_getRepetPath, newGetRepetPath);
    await prefs.setString(_modelName, newModelName);

    baseUrl = newBaseUrl;
    apiUrl = newApiUrl;
    apiKey = newApiKey;
    getRepetPath=newGetRepetPath;
    modelName=newModelName;
    UserSession().loadFromPrefs();
  }

  /// 登录时保存用户信息
  Future<void> saveToPrefs({
    required String token,
    required String name,
    required String email,
    required int role, // 修改为int类型
    required int id,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
    await prefs.setString('name', name);
    await prefs.setString('email', email);
    await prefs.setInt('role', role); // 修改为setInt
    await prefs.setInt('userID', id);

    // 更新内存中的值
    token = token;
    name = name;
    email = email;
    role = role;
  }

  /// 登出时清空所有缓存
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
