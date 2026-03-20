import 'package:flutter/material.dart';

class UserMenu extends StatelessWidget {
  final String displayName;
  final VoidCallback onLogout;
  final VoidCallback onProfile;
  final VoidCallback onFriends;
  final VoidCallback onSettings;

  const UserMenu({
    super.key,
    required this.displayName,
    required this.onLogout,
    required this.onProfile,
    required this.onFriends,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.account_circle, size: 32),
      tooltip: 'User Menu',
      onSelected: (value) {
        switch (value) {
          case 'profile': onProfile(); break;
          case 'friends': onFriends(); break;
          case 'settings': onSettings(); break;
          case 'logout': onLogout(); break;
        }
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem(
          enabled: false,
          child: Text(
            'Signed in as $displayName',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'profile',
          child: ListWithIcon(icon: Icons.person, text: 'My Profile'),
        ),
        const PopupMenuItem(
          value: 'friends',
          child: ListWithIcon(icon: Icons.people, text: 'Friends'),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: ListWithIcon(icon: Icons.settings, text: 'Settings'),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'logout',
          child: ListWithIcon(icon: Icons.logout, text: 'Log out', color: Colors.red),
        ),
      ],
    );
  }
}

class ListWithIcon extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const ListWithIcon({super.key, required this.icon, required this.text, this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: color)),
      ],
    );
  }
}