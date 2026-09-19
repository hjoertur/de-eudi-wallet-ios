import Foundation
import EudiWalletKit
import logic_business

/// Explicit simulator-only fixture issuance. Presentation uses the normal wallet stack.
public enum LocalE2EPID {
  public static let id = "trustables-e2e-erika-mustermann"
  public static var enabled: Bool {
    LocalSimulatorSettings.enabled && ProcessInfo.processInfo.environment["TRUSTABLES_E2E_PID"] == "erika"
  }
  public static func seed(in wallet: EudiWallet) async throws {
    guard enabled else { return }
    if let existing = try await wallet.loadDocument(id: id, status: .issued) {
      if existing.createdAt.addingTimeInterval(50 * 60) > Date() { return }
      try await wallet.deleteDocument(id: id, status: .issued)
    }
    let options = CredentialOptions(credentialPolicy: .rotateUse, batchSize: 1)
    let keyOptions = KeyOptions(curve: .P256, secureAreaName: SoftwareSecureArea.name,
                                accessProtection: .afterFirstUnlockThisDeviceOnly, accessControl: [])
    let request = try await wallet.beginIssueDocument(id: id, credentialOptions: options, keyOptions: keyOptions)
    let keys = try await request.createKeyBatch()
    let key = keys[0]
    let jwk = ["kty": "EC", "crv": "P-256", "x": encode(Data(key.x)), "y": encode(Data(key.y))]
    var http = URLRequest(url: URL(string: "http://localhost:8088/issue")!)
    http.httpMethod = "POST"
    http.setValue("application/json", forHTTPHeaderField: "Content-Type")
    http.httpBody = try JSONSerialization.data(withJSONObject: jwk)
    let (data, response) = try await URLSession.shared.data(for: http)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let metadata = DocMetadata(
      credentialIssuerIdentifier: "https://northline-e2e-issuer.example.invalid",
      configurationIdentifier: "trustables-e2e-pid", docType: "urn:eudi:pid:de:1",
      display: [.init(name: "TEST ID — Erika Mustermann", localeIdentifier: "en")],
      issuerDisplay: [.init(name: "Northline E2E TEST Issuer", localeIdentifier: "en")],
      claims: [], authorizedRequestData: nil, keyOptions: keyOptions, credentialOptions: options
    )
    let keyInfo = DocKeyInfo(secureAreaName: SoftwareSecureArea.name, batchSize: 1, credentialPolicy: .rotateUse)
    let document = WalletStorage.Document(id: id, docType: "urn:eudi:pid:de:1", docDataFormat: .sdjwt,
      data: data, docKeyInfo: keyInfo.toData(), createdAt: .now, metadata: metadata.toData(),
      displayName: "TEST ID — Erika Mustermann", status: .issued)
    try await wallet.endIssueDocument(document, batch: [document])
  }
  private static func encode(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
}
