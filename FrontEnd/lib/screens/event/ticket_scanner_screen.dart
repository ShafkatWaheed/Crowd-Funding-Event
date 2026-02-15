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

    // Avoid re-scanning the same code repeatedly
    if (rawData == _lastResult && _lastSuccess) return;

    setState(() => _isProcessing = true);

    try {
      final api = context.read<ApiService>();

      String? ticketCode;
      String? encryptedPayload;

      // Try to detect the format:
      // 1. If it starts with a base64-like string (no '{'), treat as encrypted payload
      // 2. If it's valid JSON with ticket_code, extract it
      // 3. Otherwise treat as raw ticket code
      if (rawData.trimLeft().startsWith('{')) {
        // Legacy plaintext JSON QR code
        try {
          final json = jsonDecode(rawData) as Map<String, dynamic>;
          ticketCode = json['ticket_code'] as String?;
        } catch (_) {
          ticketCode = rawData;
        }
      } else {
        // Encrypted payload (base64-encoded AES-256-GCM blob)
        encryptedPayload = rawData;
      }

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

    // Small delay before allowing next scan
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _isProcessing = false);
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
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.cardOf(context),
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
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (receiptNumber != null && receiptNumber.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceOf(context),
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
      ),
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

          // Bottom info bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                            ? AppTheme.successColor.withValues(alpha: 0.1)
                            : AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        color: _scannedCount > 0
                            ? AppTheme.successColor
                            : AppTheme.textSecondary,
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
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
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
                                  : AppTheme.textSecondary,
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
