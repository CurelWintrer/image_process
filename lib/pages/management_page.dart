import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:image_process/user_session.dart';

class ManagementPage extends StatefulWidget {
  const ManagementPage({super.key});

  @override
  State<ManagementPage> createState() => _ManagementPageState();
}

class _ManagementPageState extends State<ManagementPage> {
  List<User> users = [];
  Set<int> selectedUserIds = {}; // 存储选中的用户ID
  bool isLoading = true;
  String? errorMessage;

  final String _baseUrl = UserSession().baseUrl;
  final String _token = UserSession().token ?? '';
  final int nowUserID = UserSession().id ?? 0;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  // 获取用户列表
  Future<void> _fetchUsers() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/api/user/list'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<User> fetchedUsers = (data['users'] as List)
            .map((userJson) => User.fromJson(userJson))
            .where((user) => user.userID != nowUserID) // 过滤掉当前用户
            .toList();

        setState(() {
          users = fetchedUsers;
          selectedUserIds.clear(); // 清除上次选择
        });
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '网络请求异常: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleErrorResponse(http.Response response) {
    setState(() {
      switch (response.statusCode) {
        case 403:
          errorMessage = '权限不足';
          break;
        default:
          errorMessage = '服务器错误: ${response.statusCode}';
      }
    });
  }

  // 修改角色
  Future<void> _updateUserRole(int userId, int newRole) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/$userId/role'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'role': newRole}),
      );

      print(response.body);

      if (response.statusCode == 200) {
        _fetchUsers(); // 刷新数据
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '更新角色失败: $e';
      });
    }
  }

  // 修改状态（单个）
  Future<void> _updateUserState(int userId, int newState) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/$userId/state'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'state': newState}),
      );

      // print(response.body);

      if (response.statusCode == 200) {
        _fetchUsers(); // 刷新数据
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '更新状态失败: $e';
      });
    }
  }

  // 批量修改状态
  Future<void> _batchUpdateUserState(int newState) async {
    if (selectedUserIds.isEmpty) {
      setState(() {
        errorMessage = '请至少选择一个用户';
      });
      return;
    }

    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/api/user/batch-state'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'userIDs': selectedUserIds.toList(),
          'state': newState,
        }),
      );
      print('now User$nowUserID');

      print(response.body);

      if (response.statusCode == 200) {
        _fetchUsers(); // 刷新数据
      } else {
        _handleErrorResponse(response);
      }
    } catch (e) {
      setState(() {
        errorMessage = '批量更新失败: $e';
      });
    }
  }

  // 角色显示文字转换
  String _roleText(int role) {
    return role == 1 ? '管理员' : '普通用户';
  }

  // 状态显示文字转换
  String _stateText(int state) {
    return state == 1 ? '正常' : '禁用';
  }

  // 状态显示颜色
  Color _stateColor(int state) {
    return state == 1 ? Colors.green : Colors.red;
  }

  // 切换用户选择
  void _toggleUserSelection(int userId) {
    setState(() {
      if (selectedUserIds.contains(userId)) {
        selectedUserIds.remove(userId);
      } else {
        selectedUserIds.add(userId);
      }
    });
  }

  // 显示角色修改对话框
  void _showRoleDialog(BuildContext context, User user) {
    // 使用状态管理对话框内部的选中值
    showDialog(
      context: context,
      builder: (context) {
        int selectedRole = user.role;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('修改角色'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('普通用户'),
                    value: 0,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('管理员'),
                    value: 1,
                    groupValue: selectedRole,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUserRole(user.userID, selectedRole);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 显示状态修改对话框
  void _showStateDialog(BuildContext context, User user) {
    // 使用状态管理对话框内部的选中值
    showDialog(
      context: context,
      builder: (context) {
        int selectedState = user.state;
        print(user.userID);
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('修改状态'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<int>(
                    title: const Text('正常'),
                    value: 1,
                    groupValue: selectedState,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedState = value);
                      }
                    },
                  ),
                  RadioListTile<int>(
                    title: const Text('禁用'),
                    value: 0,
                    groupValue: selectedState,
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedState = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _updateUserState(user.userID, selectedState);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 构建批量操作按钮
  Widget _buildBatchActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (selectedUserIds.isNotEmpty) ...[
            OutlinedButton(
              onPressed: () => _batchUpdateUserState(1),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
              child: const Text('设为正常'),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: () => _batchUpdateUserState(0),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('设为禁用'),
            ),
          ],
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchUsers,
            tooltip: '刷新',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('用户管理'), centerTitle: true),
      body: Column(
        children: [
          // 错误消息显示
          if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // 批量操作区域
          _buildBatchActions(),

          // 用户列表
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : users.isEmpty
                    ? const Center(child: Text('没有可管理的用户'))
                    : ListView.builder(
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _buildUserListItem(user);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // 构建用户列表项
  Widget _buildUserListItem(User user) {
    final isSelected = selectedUserIds.contains(user.userID);

    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: (_) => _toggleUserSelection(user.userID),
      ),
      title: Text(user.name),
      subtitle: Text(user.email),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 角色显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _roleText(user.role),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 10),

          // 状态显示
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _stateColor(user.state).withOpacity(0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _stateText(user.state),
              style: TextStyle(fontSize: 12, color: _stateColor(user.state)),
            ),
          ),
          const SizedBox(width: 10),

          // 操作按钮
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'role',
                child: ListTile(
                  leading: Icon(Icons.admin_panel_settings),
                  title: Text('修改角色'),
                ),
              ),
              const PopupMenuItem(
                value: 'state',
                child: ListTile(
                  leading: Icon(Icons.switch_account),
                  title: Text('修改状态'),
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'role') {
                _showRoleDialog(context, user);
              } else if (value == 'state') {
                _showStateDialog(context, user);
              }
            },
          ),
        ],
      ),
      onTap: () => _toggleUserSelection(user.userID),
      onLongPress: () => _showStateDialog(context, user),
    );
  }
}

class User {
  final int userID;
  final String name;
  final String email;
  final int role;
  final int state;

  User({
    required this.userID,
    required this.name,
    required this.email,
    required this.role,
    required this.state,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: json['userID'] as int? ?? 0,
      name: json['name'] as String? ?? '未知用户',
      email: json['email'] as String? ?? '无邮箱',
      role: json['role'] as int? ?? 0,
      state: json['state'] as int? ?? 0,
    );
  }
}