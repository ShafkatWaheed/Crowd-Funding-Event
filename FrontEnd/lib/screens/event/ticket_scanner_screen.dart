import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../db/app_database.dart';
import '../../repositories/ticket_repository.dart';
import '../../repositories/base_repository.dart';
import '../../repositories/sponsor_repository.dart';
import '../../services/sync_service.dart';


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
  bool _isOffline = false;
  int _offlineTicketCount = 0;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadOfflineTicketCount();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          _isOffline = !results.any((r) => r != ConnectivityResult.none);
        });
      }
      // Listen for changes
      Connectivity().onConnectivityChanged.listen((results) {
        if (mounted) {
          final wasOffline = _isOffline;
          setState(() {
            _isOffline = !results.any((r) => r != ConnectivityResult.none);
          });
          // Coming back online — push offline scans
          if (wasOffline && !_isOffline) {
            _pushOfflineScans();
          }
        }
      });
    } catch (_) {
      // connectivity_plus not available on web — assume online
    }
  }

  Future<void> _loadOfflineTicketCount() async {
    try {
      final db = context.read<AppDatabase>();
      final count = await db.countOfflineTickets(widget.eventId);
      if (mounted) setState(() => _offlineTicketCount = count);
    } catch (_) {}
  }

  Future<void> _pushOfflineScans() async {
    try {
      final syncService = context.read<SyncService>();
      await syncService.pushOfflineScans();
    } catch (_) {}
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final rawData = barcode.rawValue!;

    if (rawData == _lastResult && _lastSuccess) return;

    setState(() => _isProcessing = true);

    try {
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
        final repo = context.read<SponsorRepository>();
        await _handleSponsorScan(repo, rawData, encryptedPayload);
      } else {
        final repo = context.read<TicketRepository>();
        await _handleRegularScan(
            repo, rawData, ticketCode, encryptedPayload);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = false;
        });
        final msg = ApiError.extractMessage(e, fallback: 'Invalid ticket');
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

  Future<void> _handleRegularScan(TicketRepository repo, String rawData,
      String? ticketCode, String? encryptedPayload) async {
    if (_isOffline) {
      await _handleOfflineScan(rawData, ticketCode, encryptedPayload);
      return;
    }

    final result = await repo.scanTicket(
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

  Future<void> _handleOfflineScan(
      String rawData, String? ticketCode, String? encryptedPayload) async {
    final db = context.read<AppDatabase>();
    final code = ticketCode ?? encryptedPayload ?? rawData;

    if (_offlineTicketCount == 0) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = false;
        });
        _showScanResult(
          success: false,
          title: 'No Offline Data',
          subtitle: 'Download tickets before scanning offline',
        );
      }
      return;
    }

    final ticket = await db.findTicketByCode(widget.eventId, code);

    if (ticket == null) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = false;
        });
        _showScanResult(
          success: false,
          title: 'Not Found',
          subtitle: 'Ticket not in offline data (may be a recent purchase)',
        );
      }
      return;
    }

    if (ticket.scannedLocally) {
      if (mounted) {
        setState(() {
          _lastResult = rawData;
          _lastSuccess = true;
        });
        _showScanResult(
          success: false,
          title: 'Already Scanned',
          subtitle: 'This ticket was already scanned offline',
          alreadyScanned: true,
        );
      }
      return;
    }

    // Valid ticket — mark scanned locally and queue for sync
    // Get current user ID from the API service's auth state
    final userId = 0; // Will be resolved on push sync
    await db.markTicketScannedLocally(ticket.id);
    await db.addOfflineScan(
      ticketCode: code,
      eventId: widget.eventId,
      scannedById: userId,
    );

    if (mounted) {
      setState(() {
        _lastResult = rawData;
        _lastSuccess = true;
        _scannedCount++;
      });
      _showScanResult(
        success: true,
        title: 'Ticket Verified (Offline)',
        subtitle: '${ticket.userName ?? 'Attendee'} — ${ticket.tierName ?? 'General'}',
      );
    }
  }

  Future<void> _handleSponsorScan(
      SponsorRepository repo, String rawData, String? encryptedPayload) async {
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
        await repo.scanSponsorTicket(widget.eventId, encryptedPayload);

    final alreadyScanned = result['already_scanned'] == true;
    final receiptNum = result['receipt_number'] ?? '';
    final companyName = result['company_name'] ?? 'Sponsor';
    final scanCount = result['scan_count'] ?? 0;
    final catNames = (result['category_names'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final delegates = (result['delegates'] as List?) ?? [];
    final totalDelegates = result['total_delegates'] ?? 0;
    final checkedInCount = result['checked_in_count'] ?? 0;

    if (mounted) {
      setState(() {
        _lastResult = rawData;
        _lastSuccess = true;
        if (totalDelegates == 0) _scannedCount++;
      });

      if (totalDelegates > 0) {
        _showSponsorDelegatePopup(
          companyName: companyName,
          receiptNumber: receiptNum,
          categoryNames: catNames,
          delegates: delegates,
          totalDelegates: totalDelegates,
          checkedInCount: checkedInCount,
        );
      } else {
        _showSponsorScanResult(
          alreadyScanned: alreadyScanned,
          companyName: companyName,
          receiptNumber: receiptNum,
          scanCount: scanCount,
          categoryNames: catNames,
        );
      }
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

  void _showSponsorDelegatePopup({
    required String companyName,
    required String receiptNumber,
    required List<String> categoryNames,
    required List<dynamic> delegates,
    required int totalDelegates,
    required int checkedInCount,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      isScrollControlled: true,
      builder: (ctx) => _SponsorDelegateSheet(
        eventId: widget.eventId,
        companyName: companyName,
        receiptNumber: receiptNumber,
        categoryNames: categoryNames,
        delegates: delegates,
        totalDelegates: totalDelegates,
        checkedInCount: checkedInCount,
        onCheckInDone: () {
          if (mounted) setState(() => _scannedCount++);
        },
      ),
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
                                      : _isOffline
                                          ? 'Offline Mode — Local validation'
                                          : 'Point camera at QR code',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                    color: _isOffline
                                        ? AppTheme.warningColor
                                        : AppTheme.textPrimaryOf(context),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _scannedCount == 0
                                      ? _isOffline
                                          ? '$_offlineTicketCount tickets available offline'
                                          : 'Ready to scan'
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
          ? AppTheme.warningColor
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


// ═══════════════════════════════════════════════════════
// Sponsor Delegate Check-in Bottom Sheet
// ═══════════════════════════════════════════════════════

class _SponsorDelegateSheet extends StatefulWidget {
  final int eventId;
  final String companyName;
  final String receiptNumber;
  final List<String> categoryNames;
  final List<dynamic> delegates;
  final int totalDelegates;
  final int checkedInCount;
  final VoidCallback onCheckInDone;

  const _SponsorDelegateSheet({
    required this.eventId,
    required this.companyName,
    required this.receiptNumber,
    required this.categoryNames,
    required this.delegates,
    required this.totalDelegates,
    required this.checkedInCount,
    required this.onCheckInDone,
  });

  @override
  State<_SponsorDelegateSheet> createState() => _SponsorDelegateSheetState();
}

class _SponsorDelegateSheetState extends State<_SponsorDelegateSheet> {
  late List<Map<String, dynamic>> _delegates;
  late int _checkedIn;

  @override
  void initState() {
    super.initState();
    _delegates = widget.delegates.map((d) => Map<String, dynamic>.from(d as Map)).toList();
    _checkedIn = widget.checkedInCount;
  }

  Future<void> _checkIn(Map<String, dynamic> delegate) async {
    if (delegate['checked_in'] == true) return;

    try {
      final repo = context.read<SponsorRepository>();
      final result = await repo.checkInDelegate(widget.eventId, delegate['id']);

      if (mounted) {
        setState(() {
          delegate['checked_in'] = true;
          delegate['checked_in_at'] = result['checked_in_at'];
          _checkedIn++;
        });
        widget.onCheckInDone();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiError.extractMessage(e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
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
          // ── Header ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront_rounded,
                      color: AppTheme.accentColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(widget.companyName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(widget.receiptNumber,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryOf(context),
                    fontFamily: 'monospace', letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: _checkedIn == widget.totalDelegates
                        ? AppTheme.successColor.withValues(alpha: 0.1)
                        : AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Checked in: $_checkedIn of ${widget.totalDelegates}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _checkedIn == widget.totalDelegates
                          ? AppTheme.successColor
                          : AppTheme.accentColor,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          Divider(height: 1, color: AppTheme.dividerOf(context)),

          // ── Delegate list ──
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _delegates.length,
              separatorBuilder: (_, __) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final d = _delegates[index];
                final isCheckedIn = d['checked_in'] == true;
                return _DelegateRow(
                  name: d['name'] ?? '',
                  checkedIn: isCheckedIn,
                  checkedInAt: d['checked_in_at'],
                  onTap: isCheckedIn ? null : () => _checkIn(d),
                );
              },
            ),
          ),

          // ── Categories ──
          if (widget.categoryNames.isNotEmpty) ...[
            Divider(height: 1, color: AppTheme.dividerOf(context)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, size: 14,
                    color: AppTheme.textSecondaryOf(context)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      widget.categoryNames.join(', '),
                      style: TextStyle(fontSize: 12,
                        color: AppTheme.textSecondaryOf(context)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── Close button ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue Scanning',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _DelegateRow extends StatelessWidget {
  final String name;
  final bool checkedIn;
  final String? checkedInAt;
  final VoidCallback? onTap;

  const _DelegateRow({
    required this.name,
    required this.checkedIn,
    this.checkedInAt,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: checkedIn
          ? AppTheme.successColor.withValues(alpha: 0.06)
          : AppTheme.surfaceOf(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: checkedIn
                  ? AppTheme.successColor.withValues(alpha: 0.3)
                  : AppTheme.dividerOf(context),
            ),
          ),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  checkedIn ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey(checkedIn),
                  size: 24,
                  color: checkedIn ? AppTheme.successColor : AppTheme.textSecondaryOf(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimaryOf(context),
                    )),
                    if (checkedIn && checkedInAt != null)
                      Text(
                        'Checked in ${_formatTime(checkedInAt!)}',
                        style: TextStyle(fontSize: 11, color: AppTheme.successColor),
                      )
                    else if (!checkedIn)
                      Text('Tap to check in',
                        style: TextStyle(fontSize: 11,
                          color: AppTheme.textSecondaryOf(context).withValues(alpha: 0.7))),
                  ],
                ),
              ),
              if (!checkedIn)
                Icon(Icons.touch_app_rounded, size: 18,
                  color: AppTheme.accentColor.withValues(alpha: 0.5)),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final amPm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${h.toString()}:${dt.minute.toString().padLeft(2, '0')} $amPm';
    } catch (_) {
      return '';
    }
  }
}
