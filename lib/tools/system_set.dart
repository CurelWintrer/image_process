import 'package:flutter/material.dart';
import 'package:image_process/user_session.dart';

class SystemSet extends StatefulWidget {
  const SystemSet({super.key});

  @override
  State<SystemSet> createState() => _SystemSetState();
}

class _SystemSetState extends State<SystemSet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _baseUrlController;
  late TextEditingController _apiUrlController;
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    // 从UserSession初始化当前值
    final session = UserSession();
    _baseUrlController = TextEditingController(text: session.baseUrl);
    _apiUrlController = TextEditingController(text: session.apiUrl);
    _apiKeyController = TextEditingController(text: session.apiKey);
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiUrlController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _saveSettings() async {
    if (_formKey.currentState!.validate()) {
      try {
        await UserSession().saveSystemSettings(
          newBaseUrl: _baseUrlController.text,
          newApiUrl: _apiUrlController.text,
          newApiKey: _apiKeyController.text,
        );
        await UserSession().loadFromPrefs();

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('设置保存成功！')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('保存失败: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('系统设置')),
      body: Center(
        // 使用Center使内容居中
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500), // 最大宽度限制在500px
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0), // 水平内边距
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true, // 使ListView适应内容高度
                children: [
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _baseUrlController,
                    label: 'API 基础地址',
                    hint: 'http://your-server.com',
                    icon: Icons.http,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _apiUrlController,
                    label: '大模型地址',
                    hint: 'https://api.provider.com/v1/chat',
                    icon: Icons.chat,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _apiKeyController,
                    label: 'API 密钥',
                    hint: 'sk-xxxxxxxxxxxxxxxx',
                    icon: Icons.vpn_key,
                    obscureText: true,
                  ),
                  const SizedBox(height: 30),
                  _buildSaveButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool obscureText = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 16,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return '请填写$label';
        }
        return null;
      },
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.save),
      label: const Text('保存设置'),
      onPressed: _saveSettings,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
    );
  }
}
