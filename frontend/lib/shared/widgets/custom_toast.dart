import 'package:flutter/material.dart';

class CustomToast {
  static void show(
    BuildContext context, 
    String message, {
    bool isError = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    // 1. Convert raw exception strings to friendly text
    String friendlyMessage = message;
    if (message.contains('invalid_credentials') || message.contains('Invalid login credentials')) {
      friendlyMessage = 'Incorrect email or password. Please try again.';
    } else if (message.contains('email_not_confirmed')) {
      friendlyMessage = 'Please verify your email address to proceed.';
    } else if (message.contains('network') || message.contains('SocketException') || message.contains('Failed host lookup')) {
      friendlyMessage = 'Network error. Please check your connection and try again.';
    } else if (message.contains('user already exists') || message.contains('User already registered')) {
      friendlyMessage = 'An account with this email already exists.';
    } else if (message.contains('weak_password') || message.contains('Password should be')) {
      friendlyMessage = 'Your password is too weak. Please use at least 6 characters.';
    } else if (message.contains('AuthApiException') || message.contains('Exception:')) {
      // Strip generic framework packaging tags
      friendlyMessage = message.replaceAll(RegExp(r'.*Exception:?\s*'), '');
      if (friendlyMessage.trim().isEmpty) {
        friendlyMessage = 'An unexpected error occurred. Please try again.';
      }
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF161A22), // App dark background
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isError ? Colors.redAccent.withAlpha(120) : const Color(0xFF00E676).withAlpha(120), // Green border for success, Red for error
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(120),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.redAccent : const Color(0xFF00E676), // Green color for success, Red for error
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  friendlyMessage,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
