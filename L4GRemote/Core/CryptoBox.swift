import CryptoKit
import Foundation

/// AES-256-GCM matching Android's `Cipher.getInstance("AES/GCM/NoPadding")`.
/// Android emits `IV(12) || ciphertext || tag(16)`, base64 with NO_WRAP.
/// CryptoKit's `AES.GCM.SealedBox.combined` is the exact same layout.
enum CryptoBox {
    private static let key = SymmetricKey(data: AppConfig.gcmKey)

    static func encrypt(_ plaintext: String) -> String {
        guard let data = plaintext.data(using: .utf8) else { return plaintext }
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            guard let combined = sealed.combined else { return plaintext }
            return combined.base64EncodedString()
        } catch {
            return plaintext
        }
    }

    static func decrypt(_ encoded: String) -> String {
        let trimmed = encoded.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let combined = Data(base64Encoded: trimmed),
              combined.count > 12 else {
            return encoded
        }
        do {
            let box = try AES.GCM.SealedBox(combined: combined)
            let plain = try AES.GCM.open(box, using: key)
            return String(data: plain, encoding: .utf8) ?? encoded
        } catch {
            // Legacy plaintext JSON passes through untouched, same as Android.
            return encoded
        }
    }
}
