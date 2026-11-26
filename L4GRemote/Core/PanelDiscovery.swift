import Darwin
import Foundation

/// Zero-config panel discovery: cached IP probe, encrypted UDP broadcast on 5005,
/// then a bounded sweep of the local /24. Mirrors Android's `startAutoDiscovery`.
final class PanelDiscovery: @unchecked Sendable {
    private let lock = NSLock()
    private var running = false
    private var emitted = false
    private var socketFD: Int32 = -1
    private var onFound: (@Sendable (String) -> Void)?

    private var cancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !running
    }

    func cancel() {
        lock.lock()
        running = false
        let fd = socketFD
        socketFD = -1
        lock.unlock()
        if fd >= 0 { close(fd) }
    }

    func run(cachedIP: String?, onFound: @escaping @Sendable (String) -> Void) {
        self.onFound = onFound
        lock.lock()
        running = true
        emitted = false
        lock.unlock()

        if let cached = cachedIP, !cached.isEmpty {
            Task {
                if await PanelAPI.probe(host: cached, timeout: 0.8) {
                    self.emit(cached)
                }
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.listenLoop()
        }

        Task {
            await probeKnownHosts()
        }

        Task {
            await sweepLocalSubnet()
        }
    }

    private func emit(_ ip: String) {
        lock.lock()
        let allowed = running && !emitted
        if allowed { emitted = true }
        lock.unlock()
        guard allowed else { return }
        onFound?(ip)
    }

    // MARK: - UDP listener / beacon

    private func listenLoop() {
        let deadline = Date().addingTimeInterval(14)
        let fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { return }

        lock.lock()
        guard running else {
            lock.unlock()
            close(fd)
            return
        }
        socketFD = fd
        lock.unlock()

        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))

        var timeout = timeval(tv_sec: 1, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        var address = sockaddr_in()
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = AppConfig.discoveryPort.bigEndian
        address.sin_addr.s_addr = INADDR_ANY

        let bound = withUnsafePointer(to: &address) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            close(fd)
            return
        }

        let ping = CryptoBox.encrypt(AppConfig.discoveryRequest)
        var broadcast = sockaddr_in()
        broadcast.sin_family = sa_family_t(AF_INET)
        broadcast.sin_port = AppConfig.discoveryPort.bigEndian
        inet_pton(AF_INET, "255.255.255.255", &broadcast.sin_addr)

        var buffer = [UInt8](repeating: 0, count: 512)

        while !cancelled && Date() < deadline {
            ping.withCString { cString in
                _ = withUnsafePointer(to: &broadcast) { pointer in
                    pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        sendto(fd, cString, strlen(cString), 0, $0,
                               socklen_t(MemoryLayout<sockaddr_in>.size))
                    }
                }
            }

            var from = sockaddr_in()
            var fromLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let received = withUnsafeMutablePointer(to: &from) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(fd, &buffer, buffer.count, 0, $0, &fromLength)
                }
            }

            if received > 0 {
                let payload = String(decoding: buffer[0..<Int(received)], as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let plain = CryptoBox.decrypt(payload)
                let sender = Self.ipString(from)
                if !sender.isEmpty {
                    if AppConfig.discoveryAckPrefixes.contains(where: { plain.hasPrefix($0) }) {
                        emit(sender)
                    } else {
                        Task {
                            if await PanelAPI.probe(host: sender, timeout: 0.7) {
                                self.emit(sender)
                            }
                        }
                    }
                }
            }
        }

        lock.lock()
        let shouldClose = socketFD == fd
        if shouldClose { socketFD = -1 }
        lock.unlock()
        if shouldClose { close(fd) }
    }

    // MARK: - Known hosts (same fallback list as Android)

    private func probeKnownHosts() async {
        let hosts = ["10.0.2.2", "127.0.0.1", "192.168.1.100", "192.168.31.12", "192.168.0.100"]
        for host in hosts {
            if cancelled { return }
            if await PanelAPI.probe(host: host, timeout: 0.8) {
                emit(host)
                return
            }
        }
    }

    // MARK: - /24 sweep

    private func sweepLocalSubnet() async {
        guard let localIP = Self.localIPv4(), !cancelled else { return }
        let parts = localIP.split(separator: ".")
        guard parts.count == 4 else { return }
        let prefix = "\(parts[0]).\(parts[1]).\(parts[2])"

        outer: for start in stride(from: 1, through: 254, by: 32) {
            if cancelled { break }
            let upper = min(start + 31, 254)
            let hit = await withTaskGroup(of: String?.self) { group -> String? in
                for octet in start...upper {
                    let host = "\(prefix).\(octet)"
                    group.addTask {
                        if self.cancelled { return nil }
                        return await PanelAPI.probe(host: host, timeout: 0.7) ? host : nil
                    }
                }
                for await result in group {
                    if let result {
                        group.cancelAll()
                        return result
                    }
                }
                return nil
            }
            if let hit {
                emit(hit)
                break outer
            }
        }
    }

    // MARK: - Interface helpers

    private static func localIPv4() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else { return nil }
        defer { freeifaddrs(interfaces) }

        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let current = pointer {
            let flags = Int32(current.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp && !isLoopback, let addr = current.pointee.ifa_addr,
               addr.pointee.sa_family == UInt8(AF_INET) {
                let ip = ipString(addr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee })
                if !ip.isEmpty && !ip.hasPrefix("169.254.") && !ip.hasPrefix("127.") {
                    return ip
                }
            }
            pointer = current.pointee.ifa_next
        }
        return nil
    }

    private static func ipString(_ address: sockaddr_in) -> String {
        var addr = address.sin_addr
        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        let converted = withUnsafePointer(to: &addr) { pointer in
            pointer.withMemoryRebound(to: UInt8.self, capacity: MemoryLayout<in_addr>.size) {
                inet_ntop(AF_INET, $0, &buffer, socklen_t(INET_ADDRSTRLEN))
            }
        }
        guard converted != nil else { return "" }
        return String(cString: buffer)
    }
}
