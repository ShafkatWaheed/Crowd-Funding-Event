import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/theme.dart';
import '../config/design_tokens.dart';
import '../models/event.dart';
import '../models/ticket.dart';
import '../providers/ticket_provider.dart';
import '../utils/share_utils.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_toast.dart';

// Brand / third-party colours used only in this file's export card.
class _BrandColors {
  _BrandColors._();
  /// Dark navy background for the ticket export card.
  static const Color ticketCardBg = Color(0xFF1A1A2E);
}

Future<void> showShareSheet(BuildContext context, Event event) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _ShareSheetContent(event: event),
  );
}

Future<void> showTicketShareSheet(BuildContext context, TicketSale ticket) {
  return showAppBottomSheet(
    context: context,
    builder: (_) => _TicketShareSheetContent(ticket: ticket),
  );
}

// ─── Event share sheet (unchanged) ───────────────────────────────────────────

class _ShareSheetContent extends StatelessWidget {
  final Event event;
  const _ShareSheetContent({required this.event});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.textSecondaryOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share Event',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          AppSpacing.vLg,

          _ShareOption(
            icon: Icons.email_outlined,
            iconColor: const Color(0xFFEA4335),
            label: 'Gmail',
            subtitle: 'Send via email',
            onTap: () => _openGmail(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.chat_rounded,
            iconColor: const Color(0xFF25D366),
            label: 'WhatsApp',
            subtitle: 'Share with contacts',
            onTap: () => _openWhatsApp(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.copy_rounded,
            iconColor: textSecondary,
            label: 'Copy Link',
            subtitle: 'Copy event URL to clipboard',
            onTap: () => _copyLink(context),
          ),
          _divider(context),
          _ShareOption(
            icon: Icons.share_rounded,
            iconColor: AppTheme.accentColor,
            label: 'More...',
            subtitle: 'Other apps',
            onTap: () => _nativeShare(context),
          ),

          AppSpacing.vSm,
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) =>
      Divider(height: 1, color: AppTheme.dividerOf(context));

  String? get _shareToken => event.isPrivate ? event.shareToken : null;

  Future<void> _openGmail(BuildContext context) async {
    Navigator.pop(context);
    final uri = ShareUtils.gmailUrl(
      event.title,
      event.id,
      dateInfo: ShareUtils.dateInfoString(event),
      token: _shareToken,
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppToast.error(context, 'Could not open Gmail');
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    Navigator.pop(context);
    final uri = ShareUtils.whatsAppUrl(event.title, event.id, token: _shareToken);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) AppToast.error(context, 'Could not open WhatsApp');
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    Navigator.pop(context);
    final url = ShareUtils.eventUrl(event.id, token: _shareToken);
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) AppToast.success(context, 'Event link copied!');
  }

  Future<void> _nativeShare(BuildContext context) async {
    Navigator.pop(context);
    final text = ShareUtils.shareText(event.title, event.id, token: _shareToken);
    await Share.share(text);
  }
}

// ─── Ticket share sheet ───────────────────────────────────────────────────────

class _TicketShareSheetContent extends StatefulWidget {
  final TicketSale ticket;
  const _TicketShareSheetContent({required this.ticket});

  @override
  State<_TicketShareSheetContent> createState() =>
      _TicketShareSheetContentState();
}

class _TicketShareSheetContentState extends State<_TicketShareSheetContent> {
  final _cardKey = GlobalKey();
  late final TextEditingController _nameCtrl;
  String? _nameError;
  bool _saving = false;
  // The name currently rendered on the offscreen card.
  String _cardAttendeeName = '';

  TicketSale get ticket => widget.ticket;

  @override
  void initState() {
    super.initState();
    final initial = ticket.attendeeName ?? ticket.attendeeDisplayName ?? '';
    _nameCtrl = TextEditingController(text: initial);
    _cardAttendeeName = initial;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<XFile?> _captureAsXFile() async {
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        debugPrint('Ticket capture: RepaintBoundary context is null');
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();
      final safeTitle = (ticket.eventTitle ?? 'ticket')
          .replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final name = 'ticket_${safeTitle}_${ticket.id}.png';
      try {
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/$name');
        await file.writeAsBytes(bytes);
        return XFile(file.path, mimeType: 'image/png');
      } catch (_) {
        return XFile.fromData(bytes, mimeType: 'image/png', name: name);
      }
    } catch (e) {
      debugPrint('Ticket capture error: $e');
      return null;
    }
  }

  Future<void> _onShare(BuildContext ctx) async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Attendee name is required');
      return;
    }
    setState(() { _nameError = null; _saving = true; });

    try {
      // Save name to server.
      await ctx.read<TicketProvider>().setAttendeeName(
        ticket.eventId,
        ticket.id,
        SetAttendeeNameRequest(name: name),
      );
    } catch (e) {
      debugPrint('Set attendee name error: $e');
      // Continue with share even if server save fails.
    }

    // Rebuild the offscreen card with the entered name, then capture.
    setState(() => _cardAttendeeName = name);

    // Wait two frames so the engine composites the updated card.
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) => frameCompleter.complete());
    });
    await frameCompleter.future;

    if (!mounted) return;

    final xfile = await _captureAsXFile();
    if (!mounted) return;

    setState(() => _saving = false);

    if (xfile == null) {
      if (ctx.mounted) AppToast.error(ctx, 'Could not export ticket image');
      return;
    }
    if (ctx.mounted) Navigator.pop(ctx);
    await Share.shareXFiles([xfile], subject: ticket.eventTitle ?? 'My Ticket');
  }

  @override
  Widget build(BuildContext context) {
    // clipBehavior: Clip.none so the off-screen card is still PAINTED.
    // Opacity(0) skips painting entirely (Flutter optimisation) so we must
    // NOT wrap in opacity — instead we park the card 2000px above the sheet
    // where users can't see it but the engine still composites the layer,
    // allowing toImage() to succeed.
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -2000,
          left: 0,
          width: 340,
          child: RepaintBoundary(
            key: _cardKey,
            child: _TicketExportCard(
              ticket: ticket,
              attendeeName: _cardAttendeeName.isNotEmpty ? _cardAttendeeName : null,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xxl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Ticket',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              AppSpacing.vLg,

              // ── Attendee name field ──
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Attendee Name',
                  hintText: 'Enter the name of the attendee',
                  errorText: _nameError,
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.md,
                  ),
                ),
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
              ),
              AppSpacing.vLg,

              Divider(height: 1, color: AppTheme.dividerOf(context)),

              _ShareOption(
                icon: Icons.share_rounded,
                iconColor: AppTheme.accentColor,
                label: 'Share Ticket',
                subtitle: 'Gmail, WhatsApp, and more',
                loading: _saving,
                onTap: () => _onShare(context),
              ),

              AppSpacing.vSm,
            ],
          ),
        ),
      ],
    );
  }
}


// ─── Ticket export card (rendered offscreen, captured as PNG) ─────────────────

class _TicketExportCard extends StatelessWidget {
  final TicketSale ticket;
  final String? attendeeName;
  const _TicketExportCard({required this.ticket, this.attendeeName});

  @override
  Widget build(BuildContext context) {
    final qrData = ticket.encryptedQrPayload ??
        '{"tc":"${ticket.ticketCode}"}';
    final eventTitle = ticket.eventTitle ?? 'Event';
    final tierName = ticket.tierName ?? 'General';
    final receipt = ticket.receiptNumber ?? '';
    final code = ticket.ticketCode;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 340,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _BrandColors.ticketCardBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.confirmation_number_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tierName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Attendee name (if set)
            if (attendeeName != null && attendeeName!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.person_rounded,
                      color: Colors.white.withValues(alpha: 0.6), size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      attendeeName!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Dashed divider
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: _DashedDivider(),
            ),

            // QR code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 180,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Ticket code
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  Text(
                    'TICKET CODE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            if (receipt.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Receipt $receipt',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const dashW = 6.0;
      const gap = 4.0;
      final count = (constraints.maxWidth / (dashW + gap)).floor();
      return Row(
        children: List.generate(count, (_) => Padding(
          padding: const EdgeInsets.only(right: gap),
          child: Container(
            width: dashW,
            height: 1,
            color: Colors.white.withValues(alpha: 0.2),
          ),
        )),
      );
    });
  }
}

// ─── Shared option row ────────────────────────────────────────────────────────

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool loading;

  const _ShareOption({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadius.md,
      onTap: loading ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md,
          horizontal: AppSpacing.xs,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: AppRadius.md,
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: iconColor),
                    )
                  : Icon(icon, color: iconColor, size: AppIconSize.lg),
            ),
            AppSpacing.hLg,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryOf(context),
                        ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondaryOf(context),
              size: AppIconSize.md,
            ),
          ],
        ),
      ),
    );
  }
}
