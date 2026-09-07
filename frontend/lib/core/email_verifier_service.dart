import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

enum EmailVerificationStatus {
  valid,
  noInternet,
  domainDoesNotExist,
  invalidSyntax,
}

class EmailVerifierService {
  /// Validates email syntax, internet connectivity, and MX records
  static Future<EmailVerificationStatus> verifyEmailExistence(String email) async {
    final trimmed = email.trim();

    // 1. Syntax Check
    final regex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!regex.hasMatch(trimmed)) {
      return EmailVerificationStatus.invalidSyntax;
    }

    final domain = trimmed.split('@').last.toLowerCase();

    // 2. Network Check (Local Socket Lookup)
    try {
      final connectivityCheck = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 4));
      if (connectivityCheck.isEmpty || connectivityCheck[0].rawAddress.isEmpty) {
        return EmailVerificationStatus.noInternet;
      }
    } on SocketException {
      return EmailVerificationStatus.noInternet;
    } on TimeoutException {
      return EmailVerificationStatus.noInternet;
    } catch (_) {
      return EmailVerificationStatus.noInternet;
    }

    // 3. Domain & MX Record Verification (Free Google Public DNS API)
    try {
      final uri = Uri.parse('https://dns.google/resolve?name=$domain&type=MX');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['Status'] as int?; // 0 = NOERROR, 3 = NXDOMAIN
        final answers = data['Answer'] as List?;

        if (status == 3 || answers == null || answers.isEmpty) {
          // Fallback: Check if domain has at least an A record
          final aUri = Uri.parse('https://dns.google/resolve?name=$domain&type=A');
          final aResponse = await http.get(aUri).timeout(const Duration(seconds: 4));

          if (aResponse.statusCode == 200) {
            final aData = jsonDecode(aResponse.body) as Map<String, dynamic>;
            final aAnswers = aData['Answer'] as List?;
            if (aAnswers == null || aAnswers.isEmpty) {
              return EmailVerificationStatus.domainDoesNotExist;
            }
          } else {
            return EmailVerificationStatus.domainDoesNotExist;
          }
        }
      }
    } on SocketException {
      return EmailVerificationStatus.noInternet;
    } on TimeoutException {
      // Proceed if DNS query times out to not block users on slow connections
    } catch (_) {
      // Ignore network flukes in DoH lookup and allow downstream Supabase check
    }

    return EmailVerificationStatus.valid;
  }
}
