import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/avatar_helper.dart';

class ContactProfilePage extends StatelessWidget {
  final UserModel user;

  const ContactProfilePage({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111111)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 80,
              backgroundColor: AvatarHelper.backgroundColor(user.username),
              backgroundImage: user.photoUrl.isNotEmpty
                  ? NetworkImage(user.photoUrl)
                  : null,
              child: user.photoUrl.isEmpty
                  ? Text(
                      user.username.isNotEmpty
                          ? user.username[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 60,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),
            Text(
              user.username,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user.email,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF999999),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
