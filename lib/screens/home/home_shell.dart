import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../goals/goals_screen.dart';
import '../skills/skill_tree_screen.dart';
import '../../theme/app_theme.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  final _screens = const [
    DashboardScreen(),
    GoalsScreen(),
    SkillTreeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withOpacity(0.2),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'امروز'),
          NavigationDestination(icon: Icon(Icons.flag_outlined), label: 'اهداف'),
          NavigationDestination(icon: Icon(Icons.auto_graph_outlined), label: 'مهارت‌ها'),
        ],
      ),
    );
  }
}
