import Foundation
import EudiWalletKit
import logic_business

/// Explicit simulator-only fixture issuance. Presentation uses the normal wallet stack.
public enum LocalE2EPID {
  public static let id = "trustables-e2e-hjortur-hjartarson-v2"
  public static var enabled: Bool {
    LocalSimulatorSettings.enabled && ProcessInfo.processInfo.environment["TRUSTABLES_E2E_PID"] == "hjortur"
  }
  public static func seed(in wallet: EudiWallet) async throws {
    guard enabled else { return }
    for oldID in ["trustables-e2e-erika-mustermann", "trustables-local-mock-erika-mustermann", "trustables-local-mock-hjortur-hjartarson", "trustables-e2e-hjortur-driving-licence", "trustables-e2e-hjortur-driving-licence-v2", "trustables-e2e-hjortur-hjartarson"] {
      if try await wallet.loadDocument(id: oldID, status: .issued) != nil {
        try await wallet.deleteDocument(id: oldID, status: .issued)
      }
    }
    try await seedDrivingLicence(in: wallet)
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
      display: [.init(name: "Hjörtur Hjartarson", localeIdentifier: "en")],
      issuerDisplay: [.init(name: "Digital Identity Service", localeIdentifier: "en")],
      claims: [], authorizedRequestData: nil, keyOptions: keyOptions, credentialOptions: options
    )
    let keyInfo = DocKeyInfo(secureAreaName: SoftwareSecureArea.name, batchSize: 1, credentialPolicy: .rotateUse)
    let document = WalletStorage.Document(id: id, docType: "urn:eudi:pid:de:1", docDataFormat: .sdjwt,
      data: data, docKeyInfo: keyInfo.toData(), createdAt: .now, metadata: metadata.toData(),
      displayName: "Hjörtur Hjartarson", status: .issued)
    try await wallet.endIssueDocument(document, batch: [document])
  }
  private static func seedDrivingLicence(in wallet: EudiWallet) async throws {
    let licenceID = "trustables-e2e-hjortur-driving-licence-v3"
    if let existing = try await wallet.loadDocument(id: licenceID, status: .issued) {
      if existing.createdAt.addingTimeInterval(50 * 60) > Date() { return }
      try await wallet.deleteDocument(id: licenceID, status: .issued)
    }
    let options = CredentialOptions(credentialPolicy: .rotateUse, batchSize: 1)
    let keyOptions = KeyOptions(curve: .P256, secureAreaName: SoftwareSecureArea.name,
                               accessProtection: .afterFirstUnlockThisDeviceOnly, accessControl: [])
    let request = try await wallet.beginIssueDocument(id: licenceID, credentialOptions: options, keyOptions: keyOptions)
    let key = try await request.createKeyBatch()[0]
    let jwk = ["kty": "EC", "crv": "P-256", "x": encode(Data(key.x)), "y": encode(Data(key.y))]
    var http = URLRequest(url: URL(string: "http://localhost:8088/issue-mdl")!)
    http.httpMethod = "POST"
    http.setValue("application/json", forHTTPHeaderField: "Content-Type")
    http.httpBody = try JSONSerialization.data(withJSONObject: jwk)
    let (data, response) = try await URLSession.shared.data(for: http)
    guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
    let metadata = DocMetadata(
      credentialIssuerIdentifier: "https://northline-e2e-issuer.example.invalid",
      configurationIdentifier: "trustables-e2e-mdl", docType: "org.iso.18013.5.1.mDL",
      display: [.init(name: "Driving Licence", localeIdentifier: "en")],
      issuerDisplay: [.init(name: "Reykjavík · Iceland", localeIdentifier: "en")],
      claims: [
        .init(display: [.init(name: "Given name", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "given_name"], valueType: nil),
        .init(display: [.init(name: "Family name", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "family_name"], valueType: nil),
        .init(display: [.init(name: "Date of birth", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "birth_date"], valueType: nil),
        .init(display: [.init(name: "Date of issue", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "issue_date"], valueType: nil),
        .init(display: [.init(name: "Expiry date", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "expiry_date"], valueType: nil),
        .init(display: [.init(name: "Issuing country", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "issuing_country"], valueType: nil),
        .init(display: [.init(name: "Issuing authority", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "issuing_authority"], valueType: nil),
        .init(display: [.init(name: "Licence number", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "document_number"], valueType: nil),
        .init(display: [.init(name: "Country code", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "un_distinguishing_sign"], valueType: nil),
        .init(display: [.init(name: "Driving privileges", localeIdentifier: "en")], isMandatory: false, claimPath: ["org.iso.18013.5.1", "driving_privileges"], valueType: nil)
      ], authorizedRequestData: nil, keyOptions: keyOptions, credentialOptions: options
    )
    let keyInfo = DocKeyInfo(secureAreaName: SoftwareSecureArea.name, batchSize: 1, credentialPolicy: .rotateUse)
    let document = WalletStorage.Document(id: licenceID, docType: "org.iso.18013.5.1.mDL", docDataFormat: .cbor,
      data: data, docKeyInfo: keyInfo.toData(), createdAt: .now, metadata: metadata.toData(),
      displayName: "Driving Licence", status: .issued)
    try await wallet.endIssueDocument(document, batch: [document])
  }
  private static func encode(_ data: Data) -> String {
    data.base64EncodedString().replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
  }
}
