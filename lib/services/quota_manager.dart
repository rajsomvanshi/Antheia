// ═══════════════════════════════════════════════════════════════
// Antheia — Quota Manager
// ═══════════════════════════════════════════════════════════════
// Tracks per-provider usage, enforces daily limits, manages
// cooldowns so exhausted providers are skipped automatically.
// ═══════════════════════════════════════════════════════════════

class QuotaManager {
  // Singleton
  static final QuotaManager _instance = QuotaManager._();
  factory QuotaManager() => _instance;
  QuotaManager._();

  // provider-id → usage record
  final Map<String, _ProviderUsage> _usage = {};

  // provider-id → exhaustion expiry time
  final Map<String, DateTime> _exhausted = {};

  // provider-id → daily limits (set once at init)
  final Map<String, int> _dailyLimits = {};

  // ─── Configure a provider's daily quota ───
  void setDailyLimit(String providerId, int limit) {
    _dailyLimits[providerId] = limit;
  }

  // ─── Check if provider has remaining quota ───
  bool hasRemainingQuota(String providerId) {
    // Check if provider is in cooldown
    final exhaustedUntil = _exhausted[providerId];
    if (exhaustedUntil != null) {
      if (DateTime.now().isBefore(exhaustedUntil)) {
        return false; // still in cooldown
      }
      _exhausted.remove(providerId); // cooldown expired
    }

    // Check daily limit
    final limit = _dailyLimits[providerId];
    if (limit == null) return true; // no limit configured = unlimited

    final usage = _getOrCreateUsage(providerId);
    if (!_isSameDay(usage.lastResetDate, DateTime.now())) {
      usage.reset();
    }
    return usage.count < limit;
  }

  // ─── Record a successful API call ───
  void recordSuccess(String providerId) {
    final usage = _getOrCreateUsage(providerId);
    if (!_isSameDay(usage.lastResetDate, DateTime.now())) {
      usage.reset();
    }
    usage.count++;
    usage.lastSuccessTime = DateTime.now();
    usage.consecutiveFailures = 0;
  }

  // ─── Record a failed API call ───
  void recordFailure(String providerId) {
    final usage = _getOrCreateUsage(providerId);
    usage.consecutiveFailures++;
  }

  // ─── Mark a provider as exhausted (rate-limited / quota hit) ───
  void markExhausted(String providerId, {int cooldownMinutes = 60}) {
    _exhausted[providerId] = DateTime.now().add(
      Duration(minutes: cooldownMinutes),
    );
  }

  // ─── Get usage stats for a provider (for UI display) ───
  Map<String, dynamic> getStats(String providerId) {
    final usage = _getOrCreateUsage(providerId);
    final limit = _dailyLimits[providerId] ?? -1;
    final isExhausted = _exhausted.containsKey(providerId) &&
        DateTime.now().isBefore(_exhausted[providerId]!);

    return {
      'providerId': providerId,
      'count': usage.count,
      'dailyLimit': limit,
      'remaining': limit > 0 ? limit - usage.count : -1,
      'isExhausted': isExhausted,
      'exhaustedUntil': _exhausted[providerId]?.toIso8601String(),
      'consecutiveFailures': usage.consecutiveFailures,
    };
  }

  // ─── Get summary of all providers ───
  List<Map<String, dynamic>> getAllStats() {
    final allIds = <String>{
      ..._usage.keys,
      ..._dailyLimits.keys,
      ..._exhausted.keys,
    };
    return allIds.map((id) => getStats(id)).toList();
  }

  // ─── Reset everything (for testing) ───
  void resetAll() {
    _usage.clear();
    _exhausted.clear();
  }

  // ─── Internal helpers ───
  _ProviderUsage _getOrCreateUsage(String providerId) {
    return _usage.putIfAbsent(providerId, () => _ProviderUsage());
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _ProviderUsage {
  int count = 0;
  DateTime lastResetDate = DateTime.now();
  DateTime? lastSuccessTime;
  int consecutiveFailures = 0;

  void reset() {
    count = 0;
    lastResetDate = DateTime.now();
    consecutiveFailures = 0;
  }
}
