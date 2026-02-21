import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../services/api_service.dart';


/// Full-screen QR code scanner for organizers to scan tickets at events.
class TicketScannerScreen extends StatefulWidget {
  final int eventId;
  final String? eventTitle;

  const TicketScannerScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
  });

  @override
  State<TicketScannerScreen> createState() => _TicketScannerScreenState();
}

class _TicketScannerScreenState extends State<TicketScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  int _scannedCount = 0;
  String? _lastResult;
  bool _lastSuccess = false;
  bool _torchOn = false;
  bool _sponsorMode = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawData = barcode.rawValue!;

    if (rawData == _lastResult && _lastSuccess) return;

    setState(() => _isProcessing = true);

    try {
      final api = context.read<ApiService>();

      String? ticketCode;
      String? encryptedPayload;

      if (rawData.trimLeft().startsWith('{')) {
        try {
          final json = jsonDecode(rawData) as Map<String, dynamic>;
          ticketCode = json['ticket_code'] as String?;
        } catch (_) {
          ticketCode = rawData;
        }
      } else {
        encryptedPayload = rawData;
      }

      if (_sponsorMode) {
        await _handleSponsorScan(api, rawData, encryptedPayload);
      } else {
        await _handleRegularScan(
            api, rawData, ticketCode, encryptedPayload);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = false;
        });
        final msg = ApiService.extractError(e, fallback: 'Invalid ticket');
        _showScanResult(
          success: false,
          title: 'Scan Failed',
          subtitle: msg,
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _handleRegularScan(ApiService api, String rawData,
      String? ticketCode, String? encryptedPayload) async {
    final result = await api.scanTicket(
      widget.eventId,
      ticketCode: ticketCode,
      encryptedPayload: encryptedPayload,
    );

    final alreadyScanned = result['already_scanned'] == true;
    final ticket = result['ticket'] as Map<String, dynamic>?;
    final ticketReceiptNum = ticket?['receipt_number'] ?? '';

    if (mounted) {
      setState(() {
        _lastResult = rawData;
        _lastSuccess = true;
        if (!alreadyScanned) _scannedCount++;
      });
      _showScanResult(
        success: !alreadyScanned,
        title: alreadyScanned ? 'Already Scanned' : 'Ticket Verified',
        subtitle: alreadyScanned
            ? 'This ticket was already scanned'
            : 'Entry confirmed',
        receiptNumber: ticketReceiptNum,
        alreadyScanned: alreadyScanned,
      );
    }
  }

  Future<void> _handleSponsorScan(
      ApiService api, String rawData, String? encryptedPayload) async {
    if (encryptedPayload == null) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = false;
        });
        _showScanResult(
          success: false,
          title: 'Invalid QR',
          subtitle: 'This does not look like a sponsor ticket',
        );
      }
      return;
    }

    final result =
        await api.scanSponsorTicket(widget.eventId, encryptedPayload);

    final alreadyScanned = result['already_scanned'] == true;
    final receiptNum = result['receipt_number'] ?? '';
    final companyName = result['company_name'] ?? 'Sponsor';
    final scanCount = result['scan_count'] ?? 0;
    final catNames = (result['category_names'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (mounted) {
      setState(() {
        _lastResult = rawData;
        _lastSuccess = true;
        _scannedCount++;
      });
      _showSponsorScanResult(
        alreadyScanned: alreadyScanned,
        companyName: companyName,
        receiptNumber: receiptNum,
        scanCount: scanCount,
        categoryNames: catNames,
      );
    }
  }

  void _showScanResult({
    required bool success,
    required String title,
    required String subtitle,
    String? receiptNumber,
    bool alreadyScanned = false,
  }) {
    final color = success
        ? AppTheme.successColor
        : alreadyScanned
            ? AppTheme.warningColor
            : AppTheme.errorColor;
    final icon = success
        ? Icons.check_circle_rounded
        : alreadyScanned
            ? Icons.info_rounded
            : Icons.error_rounded;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        final themeCtx = ctx;
        return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(themeCtx),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondaryOf(themeCtx),
              ),
              textAlign: TextAlign.center,
            ),
            if (receiptNumber != null && receiptNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(themeCtx),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  receiptNumber,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue Scanning',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      );
      },
    );
  }

  void _showSponsorScanResult({
    required bool alreadyScanned,
    required String companyName,
    required String receiptNumber,
    required int scanCount,
    required List<String> categoryNames,
  }) {
    final color = AppTheme.successColor;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.cardOf(ctx),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: AppTheme.successColor, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sponsor Verified',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                companyName,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondaryOf(ctx),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(ctx),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _infoRow(ctx, 'Receipt', receiptNumber),
                    const SizedBox(height: 8),
                    _infoRow(ctx, 'Entries', scanCount.toString()),
                    if (categoryNames.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _infoRow(ctx, 'Sponsorships', categoryNames.join(', ')),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Continue Scanning',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _modeTab({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext ctx, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: AppTheme.textSecondaryOf(ctx),
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              letterSpacing: 0.3,
            ),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
          ),

          // Dark overlay with cutout
          _ScannerOverlay(isProcessing: _isProcessing),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    // Close button
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white, size: 22),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Scan Tickets',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (widget.eventTitle != null)
                            Text(
                              widget.eventTitle!,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    // Torch toggle
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _torchOn
                            ? AppTheme.warningColor
                            : Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {
                          _cameraController.toggleTorch();
                          setState(() => _torchOn = !_torchOn);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Switch camera
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.cameraswitch_rounded,
                            color: Colors.white, size: 20),
                        onPressed: () => _cameraController.switchCamera(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom area: mode toggle + info bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mode toggle
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          _modeTab(
                            label: 'Customer',
                            icon: Icons.person_rounded,
                            selected: !_sponsorMode,
                            onTap: () => setState(() {
                              _sponsorMode = false;
                              _lastResult = null;
                            }),
                          ),
                          _modeTab(
                            label: 'Sponsor',
                            icon: Icons.storefront_rounded,
                            selected: _sponsorMode,
                            onTap: () => setState(() {
                              _sponsorMode = true;
                              _lastResult = null;
                            }),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Info bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.cardOf(context),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _scannedCount > 0
                                  ? AppTheme.successColor
                                      .withValues(alpha: 0.1)
                                  : AppTheme.surfaceOf(context),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.qr_code_scanner_rounded,
                              color: _scannedCount > 0
                                  ? AppTheme.successColor
                                  : AppTheme.textSecondaryOf(context),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _isProcessing
                                      ? 'Processing...'
                                      : 'Point camera at QR code',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _scannedCount == 0
                                      ? 'Ready to scan'
                                      : '$_scannedCount ticket${_scannedCount == 1 ? '' : 's'} scanned this session',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _scannedCount > 0
                                        ? AppTheme.successColor
                                        : AppTheme.textSecondaryOf(context),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isProcessing)
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter for the scanner overlay with a rounded cutout.
class _ScannerOverlay extends StatelessWidget {
  final bool isProcessing;
  const _ScannerOverlay({required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _OverlayPainter(isProcessing: isProcessing),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final bool isProcessing;
  _OverlayPainter({required this.isProcessing});

  @override
  void paint(Canvas canvas, Size size) {
    final cutoutSize = size.width * 0.65;
    final left = (size.width - cutoutSize) / 2;
    final top = (size.height - cutoutSize) / 2 - 40;

    // Semi-transparent overlay
    final overlayPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    final cutoutRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, cutoutSize, cutoutSize),
      const Radius.circular(24),
    );

    // Draw overlay with cutout
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(cutoutRect),
      ),
      overlayPaint,
    );

    // Draw corner brackets
    final borderPaint = Paint()
      ..color = isProcessing
          ? const Color(0xFFFFC043)
          : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    const cornerLen = 28.0;
    final r = cutoutRect.outerRect;

    // Top-left
    canvas.drawLine(Offset(r.left, r.top + cornerLen), Offset(r.left, r.top + 12), borderPaint);
    canvas.drawArc(Rect.fromLTWH(r.left, r.top, 24, 24), 3.14, 1.57, false, borderPaint);
    canvas.drawLine(Offset(r.left + 12, r.top), Offset(r.left + cornerLen, r.top), borderPaint);

    // Top-right
    canvas.drawLine(Offset(r.right - cornerLen, r.top), Offset(r.right - 12, r.top), borderPaint);
    canvas.drawArc(Rect.fromLTWH(r.right - 24, r.top, 24, 24), -1.57, 1.57, false, borderPaint);
    canvas.drawLine(Offset(r.right, r.top + 12), Offset(r.right, r.top + cornerLen), borderPaint);

    // Bottom-left
    canvas.drawLine(Offset(r.left, r.bottom - cornerLen), Offset(r.left, r.bottom - 12), borderPaint);
    canvas.drawArc(Rect.fromLTWH(r.left, r.bottom - 24, 24, 24), 1.57, 1.57, false, borderPaint);
    canvas.drawLine(Offset(r.left + 12, r.bottom), Offset(r.left + cornerLen, r.bottom), borderPaint);

    // Bottom-right
    canvas.drawLine(Offset(r.right - cornerLen, r.bottom), Offset(r.right - 12, r.bottom), borderPaint);
    canvas.drawArc(Rect.fromLTWH(r.right - 24, r.bottom - 24, 24, 24), 0, 1.57, false, borderPaint);
    canvas.drawLine(Offset(r.right, r.bottom - 12), Offset(r.right, r.bottom - cornerLen), borderPaint);
  }

  @override
  bool shouldRepaint(_OverlayPainter oldDelegate) =>
      oldDelegate.isProcessing != isProcessing;
}
