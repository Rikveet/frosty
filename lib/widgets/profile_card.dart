import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:frosty/stores/auth_store.dart';

class ProfileCard extends StatelessWidget {
  final AuthStore authStore;
  const ProfileCard({Key? key, required this.authStore}) : super(key: key);

  Future<void> _showDialog(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to log out?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                authStore.logout();
                Navigator.of(context).pop();
              },
              child: const Text('Yes'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Observer(
        builder: (context) {
          if (authStore.isLoggedIn) {
            return ListTile(
              leading: CircleAvatar(
                foregroundImage: NetworkImage(
                  authStore.user!.profileImageUrl,
                ),
              ),
              title: Text(authStore.user!.displayName),
              onTap: () => _showDialog(context),
            );
          }
          return ElevatedButton(
            onPressed: authStore.login,
            child: const Text('Login'),
          );
        },
      ),
    );
  }
}
