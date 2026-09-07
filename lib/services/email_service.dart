import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import '../models/app_settings.dart';

class EmailService {
  /// Envoie un e-mail via le serveur SMTP configuré avec pièces jointes optionnelles
  Future<void> sendEmail({
    required AppSettings settings,
    required String to,
    required String subject,
    required String body,
    String? htmlBody,
    List<String> bcc = const [],
    List<File> attachments = const [],
    List<Attachment> inlineAttachments = const [],
  }) async {
    final host = settings.smtpHost;
    final port = settings.smtpPort;
    final user = settings.smtpUser;
    final password = settings.smtpPassword;

    if (host.isEmpty || user.isEmpty || password.isEmpty) {
      throw 'Configuration SMTP incomplète. Veuillez renseigner le serveur, l\'utilisateur et le mot de passe dans les paramètres de l\'application.';
    }

    // Configuration du serveur SMTP
    final smtpServer = SmtpServer(
      host,
      port: port,
      ssl: port == 465, // SSL direct sur le port 465, STARTTLS sinon
      allowInsecure: port != 465, // Autorise STARTTLS / TLS non direct
      username: user,
      password: password,
    );

    // Construction du message
    final message = Message()
      ..from = Address(user, 'VIV Relations Fournisseurs')
      ..recipients.add(to)
      ..subject = subject
      ..text = body;

    if (htmlBody != null && htmlBody.isNotEmpty) {
      message.html = htmlBody;
    }

    // Ajout éventuel des destinataires en copie conforme invisible (Bcc)
    if (bcc.isNotEmpty) {
      for (var email in bcc) {
        if (email.trim().isNotEmpty) {
          message.bccRecipients.add(email.trim());
        }
      }
    }

    // Ajout éventuel des pièces jointes standard
    if (attachments.isNotEmpty) {
      for (var file in attachments) {
        if (file.existsSync()) {
          message.attachments.add(FileAttachment(file));
        }
      }
    }

    // Ajout éventuel des pièces jointes inline (images de signature cid)
    if (inlineAttachments.isNotEmpty) {
      message.attachments.addAll(inlineAttachments);
    }

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      final buffer = StringBuffer('Erreur lors de l\'envoi de l\'email :\n');
      for (var p in e.problems) {
        buffer.write('- ${p.code}: ${p.msg}\n');
      }
      throw buffer.toString();
    } catch (e) {
      throw 'Erreur SMTP inattendue : $e';
    }
  }
}

final emailServiceProvider = Provider<EmailService>((ref) {
  return EmailService();
});
