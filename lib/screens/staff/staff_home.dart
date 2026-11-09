import 'package:flutter/material.dart';

import '../../api.dart';
import '../profile.dart';
import 'classes_tab.dart';
import 'exams_tab.dart';
import 'staff_tab.dart';
import 'students_tab.dart';

/// Home for ADMIN and TEACHER. Admins get an extra tab to manage the other teachers/admins.
class StaffHome extends StatefulWidget {
  const StaffHome({super.key, required this.api, required this.user, required this.onLoggedOut});

  final Api api;
  final Map<String, dynamic> user;
  final VoidCallback onLoggedOut;

  @override
  State<StaffHome> createState() => _StaffHomeState();
}

class _StaffHomeState extends State<StaffHome> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final isAdmin = widget.user['role'] == 'ADMIN';
    final pages = <Widget>[
      ExamsTab(api: widget.api),
      ClassesTab(api: widget.api),
      StudentsTab(api: widget.api),
      if (isAdmin) StaffTab(api: widget.api),
      ProfileView(api: widget.api, user: widget.user, onLoggedOut: widget.onLoggedOut),
    ];
    final destinations = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.assignment_outlined), label: 'পরীক্ষা'),
      const NavigationDestination(icon: Icon(Icons.class_outlined), label: 'শ্রেণি'),
      const NavigationDestination(icon: Icon(Icons.groups_outlined), label: 'শিক্ষার্থী'),
      if (isAdmin) const NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'শিক্ষক'),
      const NavigationDestination(icon: Icon(Icons.person_outline), label: 'প্রোফাইল'),
    ];
    return Scaffold(
      appBar: AppBar(title: Text('${widget.user['institution']['name']} · ${isAdmin ? 'অ্যাডমিন' : 'শিক্ষক'}')),
      body: SafeArea(child: IndexedStack(index: tab, children: pages)), // IndexedStack keeps each tab's loaded data
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (i) => setState(() => tab = i), destinations: destinations),
    );
  }
}
