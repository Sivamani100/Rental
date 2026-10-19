import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:rental/app/theme/app_theme.dart';
import 'package:rental/features/partner/data/models/partner_handover_request.dart';

class PartnerClaimCard extends StatelessWidget {
  final PartnerHandoverRequest request;

  const PartnerClaimCard({
    super.key,
    required this.request,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppTheme.darkCard : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFEEEEEE);
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subtextColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    final isApproved = request.status.toLowerCase() == 'approved';
    final isPending = request.status.toLowerCase() == 'pending';

    final Color statusColor = isApproved
        ? AppTheme.swiggyGreen
        : (isPending ? const Color(0xFFFF9500) : AppTheme.swiggyRed);
    final IconData statusIcon = isApproved
        ? CupertinoIcons.checkmark_seal_fill
        : (isPending ? CupertinoIcons.clock_fill : CupertinoIcons.xmark_circle_fill);
    final String statusLabel = isApproved
        ? 'APPROVED & LINKED'
        : (isPending ? 'PENDING ADMIN REVIEW' : 'DECLINED');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? const Color(0xFFFF9500).withValues(alpha: 0.35) : borderColor,
          width: isPending ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Pill Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 12, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${request.createdAt.day}/${request.createdAt.month}/${request.createdAt.year}',
                style: TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 11.5,
                  color: subtextColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Property Title & Role
          Text(
            request.propertyTitle,
            style: TextStyle(
              fontFamily: 'ProximaNova',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              const Icon(CupertinoIcons.person_fill, size: 13, color: Color(0xFF007AFF)),
              const SizedBox(width: 4),
              Text(
                'Claimed Role: ${request.role}',
                style: const TextStyle(
                  fontFamily: 'ProximaNova',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF007AFF),
                ),
              ),
            ],
          ),

          if (request.note.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E222B) : const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(CupertinoIcons.doc_text_fill, size: 14, color: subtextColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      request.note,
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 12.5,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isApproved) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.swiggyGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.swiggyGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: AppTheme.swiggyGreen),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ownership verified & granted! Manage availability directly in Your Properties tab.',
                      style: TextStyle(
                        fontFamily: 'ProximaNova',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF065F46),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
