import Foundation
import AppKit
import Network
import SystemConfiguration

// MARK: - Address parsing

/// Turns whatever the user typed — `studio.local`, `10.0.0.5:5901`,
/// `vnc://jae@studio.local`, a bare IPv6 address — into the `vnc://` URL that
/// Screen Sharing.app opens. Pure, so the menu can enable/disable Connect on
/// every keystroke.
enum RemoteAddress {
    static func vncURL(from input: String) -> URL? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("vnc://") { s = String(s.dropFirst(6)) }
        while s.hasSuffix("/") { s.removeLast() }
        guard !s.isEmpty, !s.contains(where: { $0.isWhitespace || $0 == "/" }) else { return nil }

        // A bare IPv6 address (two or more colons, no brackets) needs brackets
        // to be a valid URL host.
        if !s.hasPrefix("["), !s.contains("@"), s.filter({ $0 == ":" }).count >= 2 {
            s = "[\(s)]"
        }

        guard var comps = URLComponents(string: "vnc://\(s)"),
              let host = comps.host, !host.isEmpty,
              comps.path.isEmpty, comps.query == nil, comps.fragment == nil
        else { return nil }
        if let port = comps.port, !(1...65535).contains(port) { return nil }
        // Never carry a typed password around (it would end up persisted in
        // UserDefaults); Screen Sharing prompts and keeps it in the Keychain.
        comps.password = nil
        return comps.url
    }

    /// Short display form of a URL produced by `vncURL` (drops the scheme).
    static func display(_ url: URL) -> String {
        url.absoluteString.replacingOccurrences(of: "vnc://", with: "")
    }
}

// MARK: - Model

/// A Mac the user can connect to: either found on the local network via
/// Bonjour, or saved by address (LAN, Tailscale/MagicDNS, port-forwarded IP).
struct RemoteMac: Identifiable, Codable, Hashable {
    var name: String
    /// Whatever the user typed / Bonjour resolved; normalized via `RemoteAddress`.
    var address: String

    var id: String { address.lowercased() }
    var url: URL? { RemoteAddress.vncURL(from: address) }
}

/// A Mac advertising Screen Sharing on the local network. Not persisted —
/// it shows up on its own whenever it's nearby.
struct DiscoveredMac: Identifiable, Hashable {
    let name: String
    let endpoint: NWEndpoint
    var id: String { name }
}

/// An address *this* Mac can be reached at, shown so the user can type it on
/// the other Mac.
struct LocalAddress: Identifiable, Hashable {
    enum Kind { case bonjour, lan, tailscale }
    let kind: Kind
    let value: String
    var id: String { value }

    var label: String {
        switch kind {
        case .bonjour: return "Local name"
        case .lan: return "Local network"
        case .tailscale: return "Tailscale"
        }
    }
}

// MARK: - Manager

/// "Remote" — view and control other Macs through Apple's built-in Screen
/// Sharing. Macaveli doesn't stream pixels itself: it finds Macs (Bonjour
/// `_rfb._tcp`, plus user-saved addresses), checks whether this Mac is
/// shareable, and hands a `vnc://` URL to Screen Sharing.app, which owns auth,
/// encryption, view and control. Over the internet that works through any
/// address the other Mac answers on — typically a Tailscale/MagicDNS name.
final class RemoteMacManager: ObservableObject {
    static let shared = RemoteMacManager()

    private static let savedKey = "remoteMacs"
    private static let screenSharingPort: NWEndpoint.Port = 5900

    @Published private(set) var discovered: [DiscoveredMac] = []
    /// `DiscoveredMac.id` currently being resolved for a connect, if any.
    @Published private(set) var resolving: String? = nil
    /// `DiscoveredMac.id` whose last connect attempt couldn't reach it.
    @Published private(set) var unreachable: String? = nil
    /// macOS 15 Local Network privacy blocked Bonjour browsing.
    @Published private(set) var localNetworkDenied = false
    @Published private(set) var saved: [RemoteMac] = []
    /// nil while the probe is in flight.
    @Published private(set) var sharingEnabled: Bool? = nil
    @Published private(set) var localAddresses: [LocalAddress] = []

    private var browser: NWBrowser?
    private var probe: NWConnection?

    private init() {
        saved = Self.loadSaved()
    }

    // MARK: Lifecycle

    /// Called when the Remote group appears: start browsing and refresh the
    /// this-Mac state. Cheap and idempotent.
    func refresh() {
        startBrowsing()
        probeLocalSharing()
        localAddresses = Self.currentLocalAddresses()
    }

    func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    // MARK: Connect

    func connect(_ mac: RemoteMac) {
        guard let url = mac.url else { return }
        open(url)
    }

    /// Opens a `vnc://` URL in Apple's Screen Sharing specifically — not
    /// whichever third-party VNC client last claimed the scheme.
    func open(_ url: URL) {
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.ScreenSharing") else {
            NSWorkspace.shared.open(url)
            return
        }
        NSWorkspace.shared.open([url], withApplicationAt: app, configuration: NSWorkspace.OpenConfiguration())
    }

    /// System Settings → General → Sharing, scrolled to Screen Sharing where
    /// supported; falls back to the Sharing pane root.
    func openSharingSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preferences.sharing?Services_ScreenSharing",
            "x-apple.systempreferences:com.apple.Sharing-Settings.extension",
            "x-apple.systempreferences:com.apple.preferences.sharing",
        ]
        for s in candidates {
            if let url = URL(string: s), NSWorkspace.shared.open(url) { return }
        }
    }

    // MARK: Saved Macs

    /// Returns false (and saves nothing) when the address is invalid or already saved.
    @discardableResult
    func save(name: String, address: String) -> Bool {
        guard let url = RemoteAddress.vncURL(from: address) else { return false }
        let normalized = RemoteAddress.display(url)
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let mac = RemoteMac(
            name: trimmed.isEmpty ? normalized : trimmed,
            address: normalized
        )
        guard !saved.contains(where: { $0.id == mac.id }) else { return false }
        saved.append(mac)
        persist()
        return true
    }

    func remove(_ mac: RemoteMac) {
        saved.removeAll { $0.id == mac.id }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(saved) {
            UserDefaults.standard.set(data, forKey: Self.savedKey)
        }
    }

    private static func loadSaved() -> [RemoteMac] {
        guard let data = UserDefaults.standard.data(forKey: savedKey),
              let macs = try? JSONDecoder().decode([RemoteMac].self, from: data)
        else { return [] }
        return macs
    }

    // MARK: Bonjour discovery

    private func startBrowsing() {
        guard browser == nil else { return }
        let browser = NWBrowser(for: .bonjour(type: "_rfb._tcp", domain: nil), using: .tcp)
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            let me = Self.localComputerName()
            var seen = Set<String>()
            let macs: [DiscoveredMac] = results.compactMap { result in
                // One Mac on Wi-Fi + Ethernet shows up once per interface.
                guard case let .service(name, _, _, _) = result.endpoint,
                      name.caseInsensitiveCompare(me) != .orderedSame,
                      seen.insert(name).inserted
                else { return nil }
                return DiscoveredMac(name: name, endpoint: result.endpoint)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async { self?.discovered = macs }
        }
        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.localNetworkDenied = false
                case .waiting(let error):
                    // kDNSServiceErr_PolicyDenied: Local Network access is off.
                    if case .dns(let code) = error, code == -65570 {
                        self?.localNetworkDenied = true
                    }
                case .failed:
                    // Restarted by the next `refresh()` (popover reopen).
                    self?.browser?.cancel()
                    self?.browser = nil
                default:
                    break
                }
            }
        }
        browser.start(queue: .global(qos: .utility))
        self.browser = browser
    }

    /// The Bonjour service name is the Sharing "Computer Name" (spaces,
    /// emoji…), not a host name Screen Sharing can dial. Resolve the service
    /// to an IPv4 address by opening (and immediately dropping) a TCP
    /// connection, then hand Screen Sharing `vnc://<ip>:<port>`.
    func connect(_ mac: DiscoveredMac) {
        guard resolving == nil else { return }
        resolving = mac.id
        unreachable = nil
        let params = NWParameters.tcp
        (params.defaultProtocolStack.internetProtocol as? NWProtocolIP.Options)?.version = .v4
        let conn = NWConnection(to: mac.endpoint, using: params)
        var settled = false
        let finish: (URL?) -> Void = { [weak self] url in
            DispatchQueue.main.async {
                guard !settled else { return }
                settled = true
                conn.cancel()
                self?.resolving = nil
                if let url { self?.open(url) } else { self?.unreachable = mac.id }
            }
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if case let .hostPort(host, port)? = conn.currentPath?.remoteEndpoint {
                    let h: String
                    switch host {
                    case .ipv4(let a): h = a.rawValue.map { String($0) }.joined(separator: ".")
                    case .name(let n, _): h = n
                    default: h = "\(host)"
                    }
                    finish(RemoteAddress.vncURL(from: "\(h):\(port.rawValue)"))
                } else {
                    finish(nil)
                }
            // `.waiting` is not a failure here: on macOS 15 the first LAN
            // connect waits on the Local Network prompt. The timeout decides.
            case .failed: finish(nil)
            default: break
            }
        }
        conn.start(queue: .global(qos: .userInitiated))
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { finish(nil) }
    }

    // MARK: This Mac

    /// Screen Sharing (and Remote Management) listen on 5900 when on; a
    /// loopback connect is an unprivileged, prompt-free way to tell.
    private func probeLocalSharing() {
        probe?.cancel()
        sharingEnabled = nil
        let conn = NWConnection(host: "127.0.0.1", port: Self.screenSharingPort, using: .tcp)
        probe = conn
        var settled = false
        let settle: (Bool) -> Void = { [weak self] on in
            DispatchQueue.main.async {
                guard !settled else { return }
                settled = true
                conn.cancel()
                // A probe superseded by a quicker popover reopen must not
                // overwrite the newer probe's answer.
                guard let self, self.probe === conn else { return }
                self.sharingEnabled = on
            }
        }
        conn.stateUpdateHandler = { state in
            switch state {
            case .ready: settle(true)
            case .failed, .waiting: settle(false)
            default: break
            }
        }
        conn.start(queue: .global(qos: .utility))
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { settle(false) }
    }

    static func localComputerName() -> String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? Host.current().localizedName ?? ""
    }

    static func currentLocalAddresses() -> [LocalAddress] {
        var out: [LocalAddress] = []
        if let local = SCDynamicStoreCopyLocalHostName(nil) as String?, !local.isEmpty {
            out.append(LocalAddress(kind: .bonjour, value: "\(local).local"))
        }

        var lan: [String] = []
        var tailscale: [String] = []
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return out }
        defer { freeifaddrs(ifaddr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
                  let sa = ptr.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET)
            else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count),
                              nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let ip = String(cString: host)
            let iface = String(cString: ptr.pointee.ifa_name)
            // Tailscale is a utun; carrier/hotspot CGNAT addresses share its
            // 100.64/10 range but sit on en*. Skip VM bridges and other VPNs.
            if iface.hasPrefix("utun"), isTailscale(ip) {
                tailscale.append(ip)
            } else if iface.hasPrefix("en"), !ip.hasPrefix("169.254.") {
                lan.append(ip)
            }
        }
        out += lan.map { LocalAddress(kind: .lan, value: $0) }
        out += tailscale.map { LocalAddress(kind: .tailscale, value: $0) }
        return out
    }

    /// Tailscale hands out CGNAT-range addresses: 100.64.0.0/10.
    static func isTailscale(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts[0] == 100 else { return false }
        return (64...127).contains(parts[1])
    }
}
