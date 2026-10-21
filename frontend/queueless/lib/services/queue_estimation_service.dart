import 'dart:math';
import 'package:flutter/material.dart';

enum RushLevel {
  low, // Low Rush / Quiet
  moderate, // Moderate Traffic
  peak, // Peak Rush Hours
}

class AiRushPrediction {
  final RushLevel level;
  final String levelLabel;
  final String insightDescription;
  final String bufferNote;
  final String bestTimeToVisit;
  final int rushScore; // 0 to 100 percentage
  final int predictedBufferMinutes;

  const AiRushPrediction({
    required this.level,
    required this.levelLabel,
    required this.insightDescription,
    required this.bufferNote,
    required this.bestTimeToVisit,
    required this.rushScore,
    required this.predictedBufferMinutes,
  });

  Color get color {
    switch (level) {
      case RushLevel.low:
        return const Color(0xFF10B981);
      case RushLevel.moderate:
        return const Color(0xFFF59E0B);
      case RushLevel.peak:
        return const Color(0xFFEF4444);
    }
  }

  Color get softBgColor {
    switch (level) {
      case RushLevel.low:
        return const Color(0xFFECFDF5);
      case RushLevel.moderate:
        return const Color(0xFFFFFBEB);
      case RushLevel.peak:
        return const Color(0xFFFEF2F2);
    }
  }

  Color get borderColor {
    switch (level) {
      case RushLevel.low:
        return const Color(0xFFA7F3D0);
      case RushLevel.moderate:
        return const Color(0xFFFDE68A);
      case RushLevel.peak:
        return const Color(0xFFFECACA);
    }
  }

  IconData get icon {
    switch (level) {
      case RushLevel.low:
        return Icons.speed_rounded;
      case RushLevel.moderate:
        return Icons.trending_flat_rounded;
      case RushLevel.peak:
        return Icons.local_fire_department_rounded;
    }
  }
}

/// Representation of the calculated estimation details for customer UI
class QueueEstimationResult {
  /// The estimated wait time in minutes (accounting for countdown / priority)
  final int estimatedMinutes;

  /// The human-readable formatted wait time string (e.g. "< 1 min", "~14 min", "Now Serving")
  final String formattedWaitTime;

  /// Average duration per token for this office/provider
  final int avgServiceTimeMinutes;

  /// Whether this office is newly registered without prior completion history (defaults to 12 mins)
  final bool isNewOffice;

  /// Number of people ahead
  final int peopleAhead;

  /// Whether the customer's own token has accepted priority
  final bool isPriorityCustomer;

  /// Status of priority ('NONE', 'PENDING_OFFICE', 'PENDING_PROVIDER', 'ACCEPTED', 'REJECTED')
  final String priorityStatus;

  /// Number of priority tokens currently ahead of this customer
  final int priorityTokensAhead;

  /// Informational tag/message explaining the estimate
  final String statusDescription;

  /// Detailed sub-label for the metrics display
  final String estimationSubtitle;

  /// Real-time AI crowd rush and queue dynamics forecast
  final AiRushPrediction aiRush;

  const QueueEstimationResult({
    required this.estimatedMinutes,
    required this.formattedWaitTime,
    required this.avgServiceTimeMinutes,
    required this.isNewOffice,
    required this.peopleAhead,
    required this.isPriorityCustomer,
    required this.priorityStatus,
    required this.priorityTokensAhead,
    required this.statusDescription,
    required this.estimationSubtitle,
    required this.aiRush,
  });
}

class QueueEstimationService {
  static const int defaultServiceTimeMinutes = 12;

  /// Predicts real-time queue rush level and time variance using time-of-day curves,
  /// day-of-week multipliers, current waiting count, and provider service speed.
  static AiRushPrediction predictRush({
    required int waitingCount,
    int? avgServiceTimeMinutes,
    int? dailyMaxTokens,
    int? todayTokensCount,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    final hour = now.hour + (now.minute / 60.0);
    final weekday = now.weekday; // 1 = Monday, 7 = Sunday

    // 1. Time-of-day rush baseline (0.0 to 1.0)
    double timeFactor;
    if (hour >= 10.5 && hour <= 13.0) {
      timeFactor = 0.85; // Morning rush
    } else if (hour >= 17.0 && hour <= 19.5) {
      timeFactor = 0.90; // Evening peak
    } else if (hour >= 13.0 && hour < 15.0) {
      timeFactor = 0.40; // Post-lunch lull
    } else if (hour >= 9.0 && hour < 10.5) {
      timeFactor = 0.55; // Morning ramp-up
    } else if (hour >= 15.0 && hour < 17.0) {
      timeFactor = 0.65; // Afternoon steady
    } else {
      timeFactor = 0.25; // Off-peak / early / late
    }

    // 2. Day-of-week volume multiplier
    double dayMultiplier = 1.0;
    if (weekday == DateTime.monday) {
      dayMultiplier = 1.25;
    } else if (weekday == DateTime.saturday) {
      dayMultiplier = 1.20;
    } else if (weekday == DateTime.friday) {
      dayMultiplier = 1.10;
    } else if (weekday == DateTime.sunday) {
      dayMultiplier = 0.90;
    }

    // 3. Queue density factor based on waiting count
    double queueDensityFactor;
    if (waitingCount <= 1) {
      queueDensityFactor = 0.15;
    } else if (waitingCount <= 4) {
      queueDensityFactor = 0.45;
    } else if (waitingCount <= 8) {
      queueDensityFactor = 0.75;
    } else {
      queueDensityFactor = 1.0;
    }

    // 4. Capacity utilization if available
    double capacityFactor = 0.5;
    if (dailyMaxTokens != null &&
        dailyMaxTokens > 0 &&
        todayTokensCount != null) {
      capacityFactor = (todayTokensCount / dailyMaxTokens).clamp(0.0, 1.0);
    }

    // Combined Weighted Score (0 to 100)
    final double rawScore =
        (queueDensityFactor * 40.0) +
        (timeFactor * 30.0 * dayMultiplier).clamp(0.0, 35.0) +
        (capacityFactor * 15.0) +
        (waitingCount > 0 ? 10.0 : 0.0);

    final int rushScore = rawScore.round().clamp(5, 98);

    RushLevel level;
    String levelLabel;
    String insight;
    String bufferNote;
    int bufferMinutes;

    if (rushScore < 40) {
      level = RushLevel.low;
      levelLabel = 'Low Rush';
      bufferMinutes = 0;
      bufferNote = 'On schedule • Minimal queue delay';
      if (waitingCount <= 1) {
        insight =
            'Counter is quiet with virtually no waiting line. Fast turnaround expected.';
      } else {
        insight =
            'Steady queue flow with minimal delays. Counter is operating smoothly.';
      }
    } else if (rushScore < 70) {
      level = RushLevel.moderate;
      levelLabel = 'Moderate Traffic';
      bufferMinutes = 2;
      bufferNote = 'Typical pace • ±2 min variance';
      insight =
          'Regular crowd volume for this hour. Tokens are served at consistent intervals.';
    } else {
      level = RushLevel.peak;
      levelLabel = 'Peak Rush Hours';
      bufferMinutes = (waitingCount > 4) ? 5 : 3;
      bufferNote = 'Peak rush • +$bufferMinutes min delay expected';
      if (weekday == DateTime.monday || weekday == DateTime.saturday) {
        insight =
            'High crowd volume due to heavy ${weekday == DateTime.monday ? "Monday" : "weekend"} rush. Wait times may run slightly longer.';
      } else {
        insight =
            'Peak traffic period in progress. Expect slight buffer time between consultations.';
      }
    }

    // Best Time Recommendation based on typical curve
    String bestTime;
    if (hour < 13.0) {
      bestTime = '1:30 PM – 3:30 PM (Post-lunch lull)';
    } else if (hour < 17.0) {
      bestTime = '2:30 PM – 4:30 PM (Before evening rush)';
    } else {
      bestTime = 'Tomorrow 9:30 AM – 10:30 AM (Morning opening)';
    }

    return AiRushPrediction(
      level: level,
      levelLabel: levelLabel,
      insightDescription: insight,
      bufferNote: bufferNote,
      bestTimeToVisit: bestTime,
      rushScore: rushScore,
      predictedBufferMinutes: bufferMinutes,
    );
  }

  /// Compute accurate estimation details from active token payload and local elapsed time
  static QueueEstimationResult calculate({
    required Map<String, dynamic> tokenData,
    Duration elapsedSinceSync = Duration.zero,
  }) {
    final status =
        (tokenData['status'] ?? tokenData['token']?['status'] ?? 'WAITING')
            .toString()
            .toUpperCase();
    final tokenObj = tokenData['token'] is Map
        ? tokenData['token'] as Map<String, dynamic>
        : null;

    final isTurnNow = status == 'CALLED' || status == 'IN_SERVICE';

    // People ahead
    final rawAhead = tokenData['peopleAhead'] ?? 0;
    final int peopleAhead = (rawAhead is int)
        ? rawAhead
        : int.tryParse('$rawAhead') ?? 0;

    // Average service duration from completion history (fallback to 12 if new)
    final rawAvg = tokenData['avgServiceTimeMinutes'];
    int avgDuration = (rawAvg is int && rawAvg > 0)
        ? rawAvg
        : (rawAvg is num && rawAvg > 0)
        ? rawAvg.round()
        : defaultServiceTimeMinutes;

    final bool isNewOffice = tokenData['isNewOffice'] == true || rawAvg == null;

    // Priority flags
    final bool isPriority =
        tokenData['isPriority'] == true || tokenObj?['isPriority'] == true;
    final String priorityStatus =
        (tokenData['priorityStatus'] ?? tokenObj?['priorityStatus'] ?? 'NONE')
            .toString()
            .toUpperCase();
    final bool isPriorityActive = isPriority || priorityStatus == 'ACCEPTED';
    final int priorityTokensAhead = (tokenData['priorityTokensAhead'] is int)
        ? tokenData['priorityTokensAhead'] as int
        : int.tryParse('${tokenData['priorityTokensAhead']}') ?? 0;

    final dynamicMax = tokenData['dailyMaxTokens'];
    final dynamicToday = tokenData['todayTokensCount'];

    final aiRush = predictRush(
      waitingCount: peopleAhead,
      avgServiceTimeMinutes: avgDuration,
      dailyMaxTokens: (dynamicMax is int)
          ? dynamicMax
          : int.tryParse('$dynamicMax'),
      todayTokensCount: (dynamicToday is int)
          ? dynamicToday
          : int.tryParse('$dynamicToday'),
    );

    if (isTurnNow) {
      return QueueEstimationResult(
        estimatedMinutes: 0,
        formattedWaitTime: 'Now',
        avgServiceTimeMinutes: avgDuration,
        isNewOffice: isNewOffice,
        peopleAhead: 0,
        isPriorityCustomer: isPriorityActive,
        priorityStatus: priorityStatus,
        priorityTokensAhead: 0,
        statusDescription:
            'Your turn has arrived! Please step up to the counter.',
        estimationSubtitle: 'Turn in Progress',
        aiRush: aiRush,
      );
    }

    if (peopleAhead == 0) {
      return QueueEstimationResult(
        estimatedMinutes: 0,
        formattedWaitTime: '< 1 min',
        avgServiceTimeMinutes: avgDuration,
        isNewOffice: isNewOffice,
        peopleAhead: 0,
        isPriorityCustomer: isPriorityActive,
        priorityStatus: priorityStatus,
        priorityTokensAhead: 0,
        statusDescription: isPriorityActive
            ? '⚡ High Priority: You are next in line to be called!'
            : '🎉 You are next in line! Head to the waiting desk.',
        estimationSubtitle: 'Next in line',
        aiRush: aiRush,
      );
    }

    // Base calculation from queue position and average duration
    final baseMinutes = peopleAhead * avgDuration;

    // Apply elapsed time ticker countdown (smooth dynamic updates while waiting)
    final elapsedMinutes = elapsedSinceSync.inMinutes;
    final int dynamicMinutes = max(1, baseMinutes - elapsedMinutes);

    String formattedWait;
    String statusDesc;
    String subLabel;

    if (isPriorityActive) {
      formattedWait = '~${dynamicMinutes}m (⚡)';
      statusDesc = peopleAhead == 1
          ? '⚡ High Priority: Only 1 person ahead of you. You bypass all regular waiting tokens.'
          : '⚡ High Priority Active: You bypass regular queue members ($peopleAhead priority turns ahead).';
      subLabel = isNewOffice
          ? 'Priority Queue (~12 min default)'
          : 'Priority Queue (~$avgDuration min avg)';
    } else if (priorityTokensAhead > 0) {
      formattedWait = '~$dynamicMinutes min';
      statusDesc =
          'Normal queue position. Note: $priorityTokensAhead customer(s) granted high priority are served first.';
      subLabel = isNewOffice
          ? 'Includes priority ($priorityTokensAhead ahead) • 12m default'
          : 'Includes priority ($priorityTokensAhead ahead) • ${avgDuration}m avg';
    } else if (priorityStatus == 'PENDING_OFFICE' ||
        priorityStatus == 'PENDING_PROVIDER') {
      formattedWait = '~$dynamicMinutes min';
      statusDesc =
          'Standard queue estimate. Your priority request is currently pending review.';
      subLabel = isNewOffice
          ? 'Priority Reviewing • ~12 min default'
          : 'Priority Reviewing • ~$avgDuration min avg';
    } else {
      formattedWait = '~$dynamicMinutes min';
      statusDesc =
          'Estimate based on your queue position and historical service duration.';
      subLabel = isNewOffice
          ? 'New Office (~12 min default)'
          : 'Office Average (~$avgDuration min/person)';
    }

    return QueueEstimationResult(
      estimatedMinutes: dynamicMinutes,
      formattedWaitTime: formattedWait,
      avgServiceTimeMinutes: avgDuration,
      isNewOffice: isNewOffice,
      peopleAhead: peopleAhead,
      isPriorityCustomer: isPriorityActive,
      priorityStatus: priorityStatus,
      priorityTokensAhead: priorityTokensAhead,
      statusDescription: statusDesc,
      estimationSubtitle: subLabel,
      aiRush: aiRush,
    );
  }
}
