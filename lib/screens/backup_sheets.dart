import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../provider/wallet_provider.dart';
import '../services/app_services.dart';
import '../services/backup_service.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

void _toast(BuildContext context, String text, {bool ok = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: ok ? AppColors.lime : AppColors.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text)),
      ]),
    ));
}

/// Export: set a password, then hand the encrypted file to the share sheet
/// (Save to Files, AirDrop, Drive, etc.).
Future<void> showExportSheet(BuildContext context) async {
  final wallet = context.read<WalletProvider>();
  if (wallet.cards.isEmpty) {
    _toast(context, 'Add a card first, then back it up', ok: false);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _PasswordSheet(mode: _Mode.export),
  );
}

/// Import: pick a backup file, then ask for its password.
Future<void> startImport(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  FilePickerResult? picked;
  try {
    picked = await FilePicker.pickFiles(type: FileType.any, withData: true);
  } catch (_) {
    messenger.showSnackBar(const SnackBar(content: Text("Couldn't open your files")));
    return;
  }
  final file = picked?.files.single;
  if (file == null || !context.mounted) return;

  String contents;
  try {
    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    contents = utf8.decode(bytes);
  } catch (_) {
    if (context.mounted) _toast(context, "That file isn't a Pocket Cards backup", ok: false);
    return;
  }
  if (!contents.contains(BackupService.format)) {
    if (context.mounted) _toast(context, "That file isn't a Pocket Cards backup", ok: false);
    return;
  }
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _PasswordSheet(mode: _Mode.import, contents: contents),
  );
}

enum _Mode { export, import }

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({required this.mode, this.contents});
  final _Mode mode;
  final String? contents;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _isExport => widget.mode == _Mode.export;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pw = _password.text;
    if (_isExport) {
      if (pw.length < BackupService.minPasswordLength) {
        return _fail('Use at least ${BackupService.minPasswordLength} characters');
      }
      if (pw != _confirm.text) return _fail("Passwords don't match");
    } else if (pw.isEmpty) {
      return _fail('Enter the backup password');
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    FocusScope.of(context).unfocus();
    final wallet = context.read<WalletProvider>();

    try {
      if (_isExport) {
        await _export(wallet, pw);
      } else {
        final maps = await BackupService.decrypt(widget.contents!, pw);
        final result = await wallet.importCards(maps);
        if (!mounted) return;
        Haptics.flip();
        Navigator.pop(context);
        final skipped = result.skipped > 0 ? ' (${result.skipped} already here)' : '';
        _toast(context,
            'Restored ${result.added} ${result.added == 1 ? 'card' : 'cards'}$skipped');
      }
    } on BackupException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(WalletProvider wallet, String pw) async {
    final contents = await BackupService.encrypt(wallet.cards, pw);
    final dir = await getTemporaryDirectory();
    final d = DateTime.now();
    final stamp = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final file = File('${dir.path}/pocket-cards-$stamp.${BackupService.fileExtension}');
    await file.writeAsString(contents, flush: true);
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    final result = await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/octet-stream')],
      subject: 'Pocket Cards backup',
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
    try {
      await file.delete();
    } catch (_) {}
    if (!mounted) return;
    if (result.status != ShareResultStatus.dismissed) {
      Haptics.flip();
      Navigator.pop(context);
      _toast(context, 'Backup saved. Keep the password safe.');
    }
  }

  void _fail(String message) {
    Haptics.warn();
    setState(() => _error = message);
  }

  InputDecoration _decoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textTertiary),
        prefixIcon: const Icon(Icons.key_rounded, color: AppColors.textSecondary, size: 20),
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
              color: AppColors.textSecondary, size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
        filled: true,
        fillColor: AppColors.surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.stroke),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.iris, width: 1.5),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const fieldStyle = TextStyle(color: AppColors.textPrimary, fontSize: 16);
    final count = context.read<WalletProvider>().cards.length;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Text(_isExport ? 'Back up cards' : 'Restore backup', style: AppText.title),
            ),
            GlassIconButton(icon: Icons.close_rounded, onTap: () => Navigator.pop(context)),
          ]),
          const SizedBox(height: 8),
          Text(
            _isExport
                ? 'Your $count ${count == 1 ? 'card' : 'cards'} will be encrypted with this password '
                    "into one file. Save it somewhere safe, like Files or Drive. "
                    "Without the password, nobody can open it, including you."
                : 'Enter the password you set when you made this backup. '
                    'Cards already in your wallet are skipped.',
            style: AppText.body,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _password,
            obscureText: _obscure,
            autofocus: true,
            style: fieldStyle,
            textInputAction: _isExport ? TextInputAction.next : TextInputAction.done,
            onSubmitted: (_) => _isExport ? null : _submit(),
            decoration: _decoration(_isExport ? 'Backup password' : 'Password'),
          ),
          if (_isExport) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _confirm,
              obscureText: _obscure,
              style: fieldStyle,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: _decoration('Confirm password'),
            ),
          ],
          AnimatedSize(
            duration: AppMotion.medium,
            child: _error == null
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13.5)),
                      ),
                    ]),
                  ),
          ),
          const SizedBox(height: 22),
          GradientButton(
            label: _busy
                ? (_isExport ? 'Encrypting…' : 'Decrypting…')
                : (_isExport ? 'Create backup' : 'Restore cards'),
            icon: _isExport ? Icons.lock_rounded : Icons.lock_open_rounded,
            onPressed: _busy ? null : _submit,
          ),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.wifi_off_rounded, size: 13, color: AppColors.textTertiary),
            SizedBox(width: 6),
            Text('aes-256 · encrypted on this phone', style: AppText.mono),
          ]),
        ]),
      ),
    );
  }
}
