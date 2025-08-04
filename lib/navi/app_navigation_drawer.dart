import 'package:flutter/material.dart';

class AppNavigationDrawer extends StatelessWidget {
  final Map<String, dynamic> userInfo;
  final List<String> pageTitles;
  final int selectedIndex;
  final Function(int) onItemSelected;
  final Function() onToggleUserMenu;
  final Function() onToggleSettings;
  final Function() onLogout;
  final IconData Function(int) getIconForIndex;

  const AppNavigationDrawer({
    super.key,
    required this.userInfo,
    required this.pageTitles,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onToggleUserMenu,
    required this.onToggleSettings,
    required this.onLogout,
    required this.getIconForIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Column(
        children: [
          // 用户信息区域
          _buildUserInfo(context),
          
          // 菜单项区域
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 动态生成菜单项
                  for (int i = 0; i < pageTitles.length; i++)
                    _buildMenuItem(context, i),
                ],
              ),
            ),
          ),
          
          // 底部设置和退出按钮
          _buildFooterButtons(context),
        ],
      ),
    );
  }

  Widget _buildUserInfo(BuildContext context) {
    return GestureDetector(
      onTap: onToggleUserMenu,
      child: Column(
        children: [
          const SizedBox(height: 40),
          CircleAvatar(
            radius: 40,
            child: Icon(userInfo['avatar'], size: 40),
          ),
          const SizedBox(height: 10),
          Text(
            userInfo['name'],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            userInfo['email'],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            userInfo['role'],
            style: const TextStyle(
              fontSize: 14,
              color: Colors.blueGrey,
            ),
          ),
          const Divider(height: 30),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, int index) {
    return InkWell(
      onTap: () => onItemSelected(index),
      splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selectedIndex == index
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListTile(
          leading: Icon(
            getIconForIndex(index),
            color: selectedIndex == index
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).iconTheme.color,
          ),
          title: Text(
            pageTitles[index],
            style: TextStyle(
              color: selectedIndex == index
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: selectedIndex == index 
                  ? FontWeight.w600 
                  : FontWeight.normal,
            ),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButtons(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onToggleSettings,
          splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          highlightColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('设置'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        InkWell(
          onTap: onLogout,
          splashColor: Colors.red.withOpacity(0.2),
          highlightColor: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(Icons.logout, color: Colors.red[400]),
              title: Text('退出', style: TextStyle(color: Colors.red[400])),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}