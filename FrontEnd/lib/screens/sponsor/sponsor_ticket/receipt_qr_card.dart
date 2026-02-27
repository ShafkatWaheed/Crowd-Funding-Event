import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../config/theme.dart';

class ReceiptQrCard extends StatelessWidget {
  final String qrPayload;

  const ReceiptQrCard({super.key, required this.qrPayload});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardOf(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerOf(context)),
      ),
      child: Column(
        children: [
          Text(
            'Scan at Event Entry',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.cardOf(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: QrImageView(
              data: qrPayload,
              version: QrVersions.auto,
              size: 180,
              gapless: true,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Present this QR code for sponsor verification',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryOf(context),
            ),
          ),
        ],
      ),
    );
  }
}
