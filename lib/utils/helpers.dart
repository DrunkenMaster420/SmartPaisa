import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

class Helpers {
  /* ───────────────────────────────────── Dates & Time ───────────────────────────────────── */

  /// Returns date as **dd/MM/yyyy** (e.g. 18/07/2025).
  static String formatDate(DateTime date) =>
      DateFormat('dd/MM/yyyy').format(date);

  /// Returns date-time as **dd/MM/yyyy HH:mm** (e.g. 18/07/2025 14:30).
  static String formatDateTime(DateTime dateTime) =>
      DateFormat('dd/MM/yyyy HH:mm').format(dateTime);

  /// Human-readable "time-ago" string (e.g. "2 hours ago").
  static String getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);

    if (diff.inDays > 0) {
      return '${diff.inDays} day${diff.inDays > 1 ? 's' : ''} ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours} hour${diff.inHours > 1 ? 's' : ''} ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes} minute${diff.inMinutes > 1 ? 's' : ''} ago';
    }
    return 'Just now';
  }

  /* ───────────────────────────────────── Currency ───────────────────────────────────── */

  /// Formats a double value to **₹1,234.56**.
  static String formatCurrency(double amount) =>
      '₹${amount.toStringAsFixed(2)}';

  /* ───────────────────────────────────── Text ───────────────────────────────────── */

  /// Capitalises the first letter of a string.
  static String capitalize(String text) =>
      text.isEmpty
          ? text
          : '${text[0].toUpperCase()}${text.substring(1).toLowerCase()}';

  /* ───────────────────────────────────── Layout ───────────────────────────────────── */

  /// Returns padding that scales with screen width.
  ///
  /// • **Phones (< 800 px)** → `base`
  /// • **Tablets (800 – 1,199 px)** → `base × 1.5`
  /// • **Large screens (≥ 1,200 px)** → `base × 2`
  static double getResponsivePadding(
      BuildContext context, {
        double base = 16,
      }) {
    final width = MediaQuery.of(context).size.width;

    if (width >= 1200) return base * 2;    // large screens (removed comma)
    if (width >= 800) return base * 1.5;   // tablets
    return base;                           // phones
  }
}
