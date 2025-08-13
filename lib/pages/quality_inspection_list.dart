import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:image_process/user_session.dart';

class QualityInspectionList extends StatefulWidget {
  const QualityInspectionList({super.key});

  @override
  _QualityInspectionListState createState() => _QualityInspectionListState();
}

class _QualityInspectionListState extends State<QualityInspectionList> {
  List<dynamic> allTasks = []; // 存储所有加载的任务
  List<dynamic> displayedTasks = []; // 当前页显示的任务
  int totalTasks = 0;
  int currentPage = 1;
  int totalPages = 1;
  final int itemsPerPage = 6; // 每页显示6条数据
  bool isLoading = false;
  String? token;
  String? errorMessage;
  bool allDataLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadTokenAndFetchTasks();
  }

  Future<void> _loadTokenAndFetchTasks() async {
    token =UserSession().token;
    if (token == null) {
      setState(() {
        errorMessage = '未登录或登录已过期';
      });
      return;
    }
    _fetchAllTasks();
  }

  Future<void> _fetchAllTasks() async {
    if (token == null || isLoading) return;
    setState(() {
      isLoading = true;
      errorMessage = null;
      allTasks = []; // 重置任务列表
      allDataLoaded = false; // 重置加载状态
      currentPage = 1; // 重置到第一页
    });

    try {
      int page = 1;
      List<dynamic> loadedTasks = [];
      bool hasMore = true;

      // 循环加载所有数据
      while (hasMore && !allDataLoaded) {
        final response = await http.get(
          Uri.parse(
            '${UserSession().baseUrl}/api/check-tasks/user?page=$page&limit=100', // 一次加载较多数据以减少请求次数
          ),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          loadedTasks.addAll(data['tasks']);
          totalTasks = data['total'];

          if (loadedTasks.length >= data['total'] || data['tasks'].isEmpty) {
            hasMore = false;
            allDataLoaded = true;
          }

          page++;
        } else {
          hasMore = false;
          if (response.statusCode == 401) {
            setState(() {
              errorMessage = '未授权或token无效';
            });
          } else {
            setState(() {
              errorMessage = '服务器错误: ${response.statusCode}';
            });
          }
        }
      }

      setState(() {
        allTasks = loadedTasks;
        totalPages = (allTasks.length / itemsPerPage).ceil();
        _updateDisplayedTasks();
      });
    } catch (e) {
      setState(() {
        errorMessage = '网络错误: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
        _updateDisplayedTasks(); // 确保更新显示的任务
      });
    }
  }

  void _updateDisplayedTasks() {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;
    setState(() {
      displayedTasks = allTasks.sublist(
        startIndex,
        endIndex > allTasks.length ? allTasks.length : endIndex,
      );
    });
  }

  void _goToPage(int page) {
    if (page < 1 || page > totalPages || page == currentPage) return;

    setState(() {
      currentPage = page;
      _updateDisplayedTasks();
    });
  }

  String _getStateText(int state) {
    switch (state) {
      case 0:
        return '待检查';
      case 1:
        return '检查中';
      case 2:
        return '已完成';
      default:
        return '未知状态';
    }
  }

  Color _getStateColor(int state) {
    switch (state) {
      case 0:
        return Colors.orange;
      case 1:
        return Colors.blue;
      case 2:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _navigateToDetailPage(int taskId) {
    Navigator.pushNamed(
      context,
      '/quality-inspection/detail',
      arguments: taskId,
    );
  }

  // 添加以下方法到 _QualityInspectionListState 类中
  void _showPullTaskDialog() {
    final formKey = GlobalKey<FormState>();
    final firstController = TextEditingController();
    final secondController = TextEditingController();
    final thirdController = TextEditingController();
    final fourthController = TextEditingController();
    final fifthController = TextEditingController();
    final countController = TextEditingController(text: '10');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('拉取新任务'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: firstController,
                    decoration: const InputDecoration(labelText: '一级标题（可选）'),
                  ),
                  TextFormField(
                    controller: secondController,
                    decoration: const InputDecoration(labelText: '二级标题（可选）'),
                  ),
                  TextFormField(
                    controller: thirdController,
                    decoration: const InputDecoration(labelText: '三级标题（可选）'),
                  ),
                  TextFormField(
                    controller: fourthController,
                    decoration: const InputDecoration(labelText: '四级标题（可选）'),
                  ),
                  TextFormField(
                    controller: fifthController,
                    decoration: const InputDecoration(labelText: '五级标题（可选）'),
                  ),
                  TextFormField(
                    controller: countController,
                    decoration: const InputDecoration(labelText: '数量'),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入数量';
                      }
                      if (int.tryParse(value) == null ||
                          int.parse(value) <= 0) {
                        return '请输入有效的正数';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // 检查至少提供了一个标题
                  if (firstController.text.isEmpty &&
                      secondController.text.isEmpty &&
                      thirdController.text.isEmpty &&
                      fourthController.text.isEmpty &&
                      fifthController.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('至少需要提供一个标题参数')),
                    );
                    return;
                  }

                  Navigator.pop(context);
                  await _pullTasks(
                    first: firstController.text.isEmpty
                        ? null
                        : firstController.text,
                    second: secondController.text.isEmpty
                        ? null
                        : secondController.text,
                    third: thirdController.text.isEmpty
                        ? null
                        : thirdController.text,
                    fourth: fourthController.text.isEmpty
                        ? null
                        : fourthController.text,
                    fifth: fifthController.text.isEmpty
                        ? null
                        : fifthController.text,
                    count: int.parse(countController.text),
                  );
                }
              },
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pullTasks({
    String? first,
    String? second,
    String? third,
    String? fourth,
    String? fifth,
    required int count,
  }) async {
    if (token == null) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('${UserSession().baseUrl}/api/check-tasks'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          if (first != null) 'First': first,
          if (second != null) 'Second': second,
          if (third != null) 'Third': third,
          if (fourth != null) 'Fourth': fourth,
          if (fifth != null) 'Fifth': fifth,
          'count': count,
        }),
      );

      if (response.statusCode == 201) {
        // 拉取成功，重置并刷新任务列表
        setState(() {
          allTasks = [];
          currentPage = 1;
          isLoading = false;
        });
        await _fetchAllTasks(); // 重新加载所有任务
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('成功拉取新任务')));
        // await _fetchAllTasks(); // 重新加载所有任务
      } else {
        String errorMsg = '拉取任务失败';
        if (response.statusCode == 400) {
          errorMsg = '参数错误：至少需要一个标题且数量必须为正数';
        } else if (response.statusCode == 401) {
          errorMsg = '未授权或token无效';
        } else if (response.statusCode == 404) {
          errorMsg = '没有找到符合条件的图片';
        } else if (response.statusCode == 500) {
          errorMsg = '服务器内部错误';
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMsg)));
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('网络错误: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDateTime(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return date.toIso8601String();
    } catch (e) {
      return dateString; // 解析失败时返回原字符串
    }
  }

  //更新质检任务状态
  Future<void> _updataCheckListState(int taskID, int state) async {
    if (token == null) return;
    try {
      final response = await http.put(
        Uri.parse('${UserSession().baseUrl}/api/check-tasks/$taskID/state'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json', // 确保添加这个header
        },
        body: jsonEncode({"state": state}),
      );

      print('Sending state: ${state.toString()}'); // 调试输出

      if (response.statusCode != 200) {
        errorMessage = '任务列表更新失败: ${response.body}';
      }
      print(response.body);
    } catch (e) {
      errorMessage = '网络错误$e';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // 顶部任务总览
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildSummaryCard(
                        '总任务数',
                        totalTasks.toString(),
                        Icons.list,
                      ),
                      _buildSummaryCard(
                        '待检查',
                        allTasks
                            .where((t) => t['state'] == 0)
                            .length
                            .toString(),
                        Icons.pending_actions,
                      ),
                      _buildSummaryCard(
                        '检查中',
                        allTasks
                            .where((t) => t['state'] == 1)
                            .length
                            .toString(),
                        Icons.hourglass_top,
                      ),
                      _buildSummaryCard(
                        '已完成',
                        allTasks
                            .where((t) => t['state'] == 2)
                            .length
                            .toString(),
                        Icons.check_circle,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 20,),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _showPullTaskDialog,
                  tooltip: '拉取新任务',
                ),
                SizedBox(width: 20,),
                IconButton(onPressed: _fetchAllTasks, icon: const Icon(Icons.refresh),tooltip: '刷新列表',)
                
              ],
            ),
          ),

          // 任务列表
          Expanded(
            child: isLoading && allTasks.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                ? Center(child: Text(errorMessage!))
                : ListView.builder(
                    itemCount: displayedTasks.length,
                    itemBuilder: (context, index) {
                      final task = displayedTasks[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              // 第一部分：左侧任务信息
                              Expanded(
                                flex: 3, // 设置权重比例
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.list_alt,
                                          size: 18,
                                          color: Colors.blue,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '任务 ${task['checkImageListID']}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.photo_library,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${task['imageCount']}张图片',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                        const SizedBox(width: 20),
                                        const Icon(
                                          Icons.check_circle,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '已检 ${task['checked_count']}张',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // 第二部分：中间日期信息 - 新增位置
                              Expanded(
                                flex: 2, // 小于左侧比例
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.create,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDateTime(task['created_at']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.update,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDateTime(task['updated_at']),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.folder,
                                          size: 14,
                                          color: Colors.grey,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatDateTime(task['path'] ?? '未知'),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // 第三部分：右侧状态/按钮
                              Expanded(
                                flex: 2, // 与日期区域相同比例
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // 状态标签
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getStateColor(
                                          task['state'],
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _getStateColor(task['state']),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _getStateText(task['state']),
                                        style: TextStyle(
                                          color: _getStateColor(task['state']),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),

                                    // 质检按钮
                                    // if (task['state'] != 2) ...[
                                      const SizedBox(height: 12),
                                      ElevatedButton(
                                        onPressed: () => {
                                          _navigateToDetailPage(
                                            task['checkImageListID'],
                                          ),
                                          if (task['state'] == 0)
                                            {
                                              _updataCheckListState(
                                                task['checkImageListID'],
                                                1,
                                              ),
                                            },
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          '质检',
                                          style: TextStyle(fontSize: 14),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: ()=>_confirmAbandonTask(task['checkImageListID']), 
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red,
                                        ),
                                        child: const Text('放弃',style: TextStyle(fontSize: 14),),
                                      )
                                    // ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // 分页控制
          _buildPaginationControls(),
        ],
      ),
    );
  }

   void _confirmAbandonTask(int taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认放弃任务'),
        content: const Text('确定要放弃此任务吗？放弃后任务将重新进入待分配状态。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // 关闭对话框
              _abandonTask(taskId); // 调用放弃任务方法
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 添加放弃任务的方法
  Future<void> _abandonTask(int taskId) async {
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('未登录或登录已过期')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.delete(
        Uri.parse('${UserSession().baseUrl}/api/check-tasks/$taskId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('任务 $taskId 已放弃')));
        // 刷新任务列表
        await _fetchAllTasks();
      } else {
        String errorMessage = '放弃任务失败';
        if (response.statusCode == 401) {
          errorMessage = '未授权或token无效';
        } else if (response.statusCode == 404) {
          errorMessage = '任务不存在或不属于当前用户';
        } else {
          errorMessage = '服务器错误: ${response.statusCode}';
        }
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('网络错误: $e')));
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildPaginationControls() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.first_page),
            onPressed: currentPage > 1 ? () => _goToPage(1) : null,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => _goToPage(currentPage - 1)
                : null,
          ),
          Text('第 $currentPage 页 / 共 $totalPages 页'),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => _goToPage(currentPage + 1)
                : null,
          ),
          IconButton(
            icon: const Icon(Icons.last_page),
            onPressed: currentPage < totalPages
                ? () => _goToPage(totalPages)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
