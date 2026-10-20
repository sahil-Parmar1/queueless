import 'dart:math';

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
  });
}

class QueueEstimationService {
  static const int defaultServiceTimeMinutes = 12;

  /// Compute accurate estimation details from active token payload and local elapsed time
  static QueueEstimationResult calculate({
    required Map<String, dynamic> tokenData,
    Duration elapsedSinceSync = Duration.zero,
  }) {
    final status = (tokenData['status'] ?? tokenData['token']?['status'] ?? 'WAITING').toString().toUpperCase();
    final tokenObj = tokenData['token'] is Map ? tokenData['token'] as Map<String, dynamic> : null;

    final isTurnNow = status == 'CALLED' || status == 'IN_SERVICE';

    // People ahead
    final rawAhead = tokenData['peopleAhead'] ?? 0;
    final int peopleAhead = (rawAhead is int) ? rawAhead : int.tryParse('$rawAhead') ?? 0;

    // Average service duration from completion history (fallback to 12 if new)
    final rawAvg = tokenData['avgServiceTimeMinutes'];
    int avgDuration = (rawAvg is int && rawAvg > 0)
        ? rawAvg
        : (rawAvg is num && rawAvg > 0)
            ? rawAvg.round()
            : defaultServiceTimeMinutes;

    final bool isNewOffice = tokenData['isNewOffice'] == true || rawAvg == null;

    // Priority flags
    final bool isPriority = tokenData['isPriority'] == true || tokenObj?['isPriority'] == true;
    final String priorityStatus = (tokenData['priorityStatus'] ?? tokenObj?['priorityStatus'] ?? 'NONE').toString().toUpperCase();
    final bool isPriorityActive = isPriority || priorityStatus == 'ACCEPTED';
    final int priorityTokensAhead = (tokenData['priorityTokensAhead'] is int)
        ? tokenData['priorityTokensAhead'] as int
        : int.tryParse('${tokenData['priorityTokensAhead']}') ?? 0;

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
        statusDescription: 'Your turn has arrived! Please step up to the counter.',
        estimationSubtitle: 'Turn in Progress',
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
      statusDesc = 'Normal queue position. Note: $priorityTokensAhead customer(s) granted high priority are served first.';
      subLabel = isNewOffice
          ? 'Includes priority ($priorityTokensAhead ahead) • 12m default'
          : 'Includes priority ($priorityTokensAhead ahead) • ${avgDuration}m avg';
    } else if (priorityStatus == 'PENDING_OFFICE' || priorityStatus == 'PENDING_PROVIDER') {
      formattedWait = '~$dynamicMinutes min';
      statusDesc = 'Standard queue estimate. Your priority request is currently pending review.';
      subLabel = isNewOffice
          ? 'Priority Reviewing • ~12 min default'
          : 'Priority Reviewing • ~$avgDuration min avg';
    } else {
      formattedWait = '~$dynamicMinutes min';
      statusDesc = 'Estimate based on your queue position and historical service duration.';
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
    );
  }
}
