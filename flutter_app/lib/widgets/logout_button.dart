import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';
import '../screens/auth/login_screen.dart';

Future<void> showLogoutDialog(BuildContext context) async {
  final confirm = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: const [
          Icon(Icons.logout_rounded, color: AppColors.error),
          SizedBox(width: 8),
          Text('Log Out', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: const Text(
        'Are you sure you want to log out of PharmaLink?',
        style: TextStyle(fontSize: 14, color: AppColors.textDark),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.textGrey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Log Out'),
        ),
      ],
    ),
  );

  if (confirm == true && context.mounted) {
    await context.read<AuthService>().logout();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }
}

class HeaderLogoutButton extends StatelessWidget {
  const HeaderLogoutButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Log Out',
      child: GestureDetector(
        onTap: () => showLogoutDialog(context),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white24,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.logout_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}
