import Foundation
import Combine

/// Source of truth for trial + license state. Persists to UserDefaults so
/// state survives restarts. The validation hook is stubbed for now and
/// gets swapped for a real Lemon Squeezy `validate` call once the
/// payments provider is configured.
final class LicenseManager: ObservableObject {
    static let shared = LicenseManager()

    enum State: Equatable {
        case trialing(daysLeft: Int)
        case trialExpired
        case licensed(email: String)
    }

    @Published private(set) var state: State = .trialing(daysLeft: 14)

    static let trialLength: Int = 14

    // Storage keys live here, not in PreferenceKey, because they're internal
    // to licensing and shouldn't leak into the rest of the app.
    private enum Key {
        static let trialStartedAt = "license.trialStartedAt"
        static let licenseKey     = "license.key"
        static let licenseEmail   = "license.email"
    }

    private init() {
        ensureTrialStarted()
        refresh()
    }

    // MARK: - Public API

    /// Recompute `state` from persisted storage. Call this on launch and
    /// after any successful activation.
    func refresh() {
        if let email = UserDefaults.standard.string(forKey: Key.licenseEmail),
           let key   = UserDefaults.standard.string(forKey: Key.licenseKey),
           !email.isEmpty, !key.isEmpty {
            state = .licensed(email: email)
            return
        }

        let started = trialStartedAt() ?? Date()
        let elapsed = Int(Date().timeIntervalSince(started) / 86_400)
        let left = Self.trialLength - elapsed
        state = left > 0 ? .trialing(daysLeft: left) : .trialExpired
    }

    /// Days remaining in the trial. Returns 0 if not trialing.
    var trialDaysLeft: Int {
        if case .trialing(let n) = state { return n }
        return 0
    }

    var isLicensed: Bool {
        if case .licensed = state { return true }
        return false
    }

    /// Stub validation. Real Lemon Squeezy integration will POST to
    /// `/v1/licenses/validate` and check `valid: true` + `meta.customer_email`.
    /// For now any non-empty key/email pair activates locally.
    @MainActor
    func activate(email: String, key: String) async -> Result<Void, LicenseError> {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let k = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, e.contains("@") else { return .failure(.invalidEmail) }
        guard k.count >= 8 else { return .failure(.invalidKey) }

        // Simulate a brief network roundtrip so the UI shows progress.
        try? await Task.sleep(nanoseconds: 400_000_000)

        UserDefaults.standard.set(e, forKey: Key.licenseEmail)
        UserDefaults.standard.set(k, forKey: Key.licenseKey)
        refresh()
        return .success(())
    }

    func deactivate() {
        UserDefaults.standard.removeObject(forKey: Key.licenseEmail)
        UserDefaults.standard.removeObject(forKey: Key.licenseKey)
        refresh()
    }

    // MARK: - Internals

    private func trialStartedAt() -> Date? {
        let ts = UserDefaults.standard.double(forKey: Key.trialStartedAt)
        return ts > 0 ? Date(timeIntervalSince1970: ts) : nil
    }

    private func ensureTrialStarted() {
        if trialStartedAt() == nil {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.trialStartedAt)
        }
    }
}

enum LicenseError: LocalizedError {
    case invalidEmail
    case invalidKey
    case network

    var errorDescription: String? {
        switch self {
        case .invalidEmail: return "Enter a valid email address."
        case .invalidKey:   return "License key looks too short."
        case .network:     return "Couldn't reach the activation server. Try again."
        }
    }
}
