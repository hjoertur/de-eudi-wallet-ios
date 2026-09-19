import Foundation
import CryptoKit
import EudiWalletKit
import logic_business

/// A UI fixture, deliberately without a holder key: it cannot be presented.
public enum LocalMockPID {
  public static let id = "trustables-local-mock-erika-mustermann"

  public static func seed(in wallet: EudiWallet, requestedByUser: Bool = false) async throws {
    guard LocalSimulatorSettings.enabled,
          requestedByUser || ProcessInfo.processInfo.environment["TRUSTABLES_MOCK_PID"] == "erika" else { return }
    guard try await wallet.loadDocument(id: id, status: .issued) == nil else { return }

    let claims: [(String, Any)] = [
      ("given_name", "Erika"), ("family_name", "Mustermann"),
      ("birthdate", "1964-08-12"), ("nationalities", ["DE"]),
      ("age_over_18", true), ("issuing_country", "DE"),
      ("issuing_authority", "Trustables local simulation — MOCK"),
      ("mock_credential", true)
    ]
    let disclosures = try claims.map { name, value in
      encode(try JSONSerialization.data(withJSONObject: [UUID().uuidString, name, value]))
    }
    let now = Int(Date().timeIntervalSince1970)
    let payload: [String: Any] = [
      "iss": "https://mock-issuer.example.invalid", "vct": "urn:eudi:pid:de:1",
      "iat": now, "nbf": now, "exp": now + 30 * 24 * 60 * 60,
      "_sd_alg": "sha-256",
      "_sd": disclosures.map { encode(Data(SHA256.hash(data: Data($0.utf8)))) }
    ]
    let key = P256.Signing.PrivateKey()
    let publicKey = key.publicKey.x963Representation
    let header: [String: Any] = [
      "alg": "ES256", "typ": "dc+sd-jwt",
      "jwk": ["kty": "EC", "crv": "P-256",
              "x": encode(publicKey.subdata(in: 1..<33)),
              "y": encode(publicKey.subdata(in: 33..<65))]
    ]
    let signingInput = try encode(JSONSerialization.data(withJSONObject: header)) + "." +
      encode(JSONSerialization.data(withJSONObject: payload))
    let signature = try key.signature(for: Data(signingInput.utf8))
    let compact = signingInput + "." + encode(signature.rawRepresentation) + "~" +
      disclosures.joined(separator: "~") + "~"
    let metadata = DocMetadata(
      credentialIssuerIdentifier: "https://mock-issuer.example.invalid",
      configurationIdentifier: "trustables-mock-pid", docType: "urn:eudi:pid:de:1",
      display: [.init(name: "MOCK — Erika Mustermann", localeIdentifier: "en")],
      issuerDisplay: [.init(name: "Trustables local simulation — MOCK", localeIdentifier: "en")],
      claims: [], authorizedRequestData: nil, keyOptions: nil, credentialOptions: nil
    )
    let document = WalletStorage.Document(
      id: id, docType: "urn:eudi:pid:de:1", docDataFormat: .sdjwt,
      data: Data(compact.utf8), docKeyInfo: nil, createdAt: .now,
      metadata: metadata.toData(), displayName: "MOCK — Erika Mustermann", status: .issued
    )
    try await wallet.endIssueDocument(document, batch: nil)
  }

  private static func encode(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
}
