// features/nodes/add_config_dialog.dart
// Sharp dialog to import and validate VLESS, VMess, Shadowsocks, and Trojan configs.
// Real-time URI parsing preview, clipboard paste, zero emojis, sharp theme.

import 'package:country_flags/country_flags.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/persian.dart';
import '../../core/proxy_models.dart';
import '../../core/proxy_service.dart';
import '../../design/components/sharp_button.dart';
import '../../design/components/sharp_toast.dart';
import '../../design/tokens.dart';
import '../../l10n/strings_fa.dart';

class AddConfigDialog extends ConsumerStatefulWidget {
  const AddConfigDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => const AddConfigDialog(),
    );
  }

  @override
  ConsumerState<AddConfigDialog> createState() => _AddConfigDialogState();
}

class _AddConfigDialogState extends ConsumerState<AddConfigDialog> {
  final TextEditingController _controller = TextEditingController();
  List<ProxyNode> _previewNodes = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _checkClipboard();
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _checkClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text?.trim();
      if (text != null && text.isNotEmpty) {
        if (text.startsWith('vless://') ||
            text.startsWith('vmess://') ||
            text.startsWith('ss://') ||
            text.startsWith('trojan://')) {
          _controller.text = text;
        }
      }
    } catch (_) {}
  }

  void _onTextChanged() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() {
        _previewNodes = [];
        _error = null;
      });
      return;
    }

    final parsed = ProxyParser.parseAll(text);
    setState(() {
      _previewNodes = parsed;
      _error = parsed.isEmpty ? StringsFa.toastInvalidConfig : null;
    });
  }

  Future<void> _handlePaste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data?.text != null) {
        _controller.text = data!.text!.trim();
      }
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    if (_previewNodes.isEmpty) return;

    final count = await ref
        .read(proxyNodesProvider.notifier)
        .addFromText(_controller.text);

    if (!mounted) return;
    if (count > 0) {
      // Select the newly added node
      await ref
          .read(selectedNodeProvider.notifier)
          .selectNode(_previewNodes.first);
      if (!mounted) return;
      Navigator.of(context).pop();
      SharpToast.show(context, StringsFa.toastConfigAdded);
    } else {
      setState(() {
        _error = StringsFa.toastInvalidConfig;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hairline =
        isDark ? ZohalTokens.darkHairline : ZohalTokens.lightHairline;
    final textPrimary =
        isDark ? ZohalTokens.darkTextPrimary : ZohalTokens.lightTextPrimary;
    final textSecondary =
        isDark ? ZohalTokens.darkTextSecondary : ZohalTokens.lightTextSecondary;

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: theme.scaffoldBackgroundColor,
      title: Text(
        StringsFa.addConfig,
        style: TextStyle(
          fontFamily: ZohalTokens.fontFamily,
          fontSize: 18.0,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
      ),
      content: SizedBox(
        width: 440.0,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _controller,
                maxLines: 4,
                textDirection: TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 12.0,
                  fontFamily: 'monospace',
                ),
                decoration: InputDecoration(
                  hintText: 'vless://... یا vmess://...\n(یا پیوندهای چندخطی)',
                  hintStyle: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 12.0,
                    color: textSecondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? ZohalTokens.darkSurface
                      : ZohalTokens.lightSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(color: hairline),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.zero,
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8.0),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: _handlePaste,
                  icon: const Icon(Icons.paste_sharp, size: 16.0),
                  label: const Text(
                    StringsFa.pasteConfig,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 12.0,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8.0),
                Container(
                  padding: const EdgeInsets.all(8.0),
                  color: theme.colorScheme.error.withValues(alpha: 0.12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontFamily: ZohalTokens.fontFamily,
                      fontSize: 12.0,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ],
              if (_previewNodes.isNotEmpty) ...[
                const SizedBox(height: 12.0),
                Text(
                  'سرورهای شناسایی شده (${Persian.formatNumber(_previewNodes.length)}):',
                  style: TextStyle(
                    fontFamily: ZohalTokens.fontFamily,
                    fontSize: 13.0,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8.0),
                for (final node in _previewNodes.take(3))
                  Container(
                    margin: const EdgeInsets.only(bottom: 6.0),
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: hairline),
                    ),
                    child: Row(
                      children: [
                        if (node.countryCode != 'UN')
                          CountryFlag.fromCountryCode(
                            node.countryCode,
                            height: 14.0,
                            width: 20.0,
                            borderRadius: 0,
                          )
                        else
                          Icon(Icons.public_sharp,
                              size: 16.0, color: textSecondary),
                        const SizedBox(width: 8.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                node.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: ZohalTokens.fontFamily,
                                  fontSize: 13.0,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              Text(
                                Persian.ltrIsolate(
                                    '${node.protocol.name.toUpperCase()} • ${node.server}:${node.port}'),
                                style: TextStyle(
                                  fontFamily: ZohalTokens.fontFamily,
                                  fontSize: 11.0,
                                  color: textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        SharpButton(
          label: StringsFa.cancel,
          isOutlined: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8.0),
        SharpButton(
          label: StringsFa.add,
          onPressed: _previewNodes.isNotEmpty ? _handleSave : null,
        ),
      ],
    );
  }
}
