# Trustables local d-you lab

Fork: https://github.com/hjoertur/de-eudi-wallet-ios

Upstream baseline: `3dac550` (OSS sync 2026-09-16).
Working branch: `trustables/local-simulation`.

Run from this checkout:

```sh
./scripts/run-simulator.sh
```

The script uses the installed Xcode directly, builds the DevDebug scheme,
signs the simulator app locally for Keychain access, installs it, and launches
it with `TRUSTABLES_LOCAL_SIMULATION=1`. Pass another installed simulator UDID
as the first argument. No Apple developer account is needed.

Local mode is gated to the DEV variant running in an iOS simulator and requires
the explicit launch environment flag. It selects `http://localhost:8080`, uses
software keys because the simulator has no Secure Enclave, and disables
Firebase push and analytics initialization (the published placeholder key
otherwise crashes at launch). The script labels the installed app `d-you Local`
and allows local networking only in its built simulator artifact.

## Wallet backend

The official backend is checked out alongside this repository at
`../de-eudi-wallet-backend`. The local Compose project is
`trustables-dyou-local`. It uses generated test keys and the upstream `ci-test`
profile; its only published application port binds to loopback.

```sh
cd ../de-eudi-wallet-backend
docker compose -p trustables-dyou-local up -d --build app-combined
curl http://localhost:8080/actuator/health/readiness
# Stop the lab, preserving test data:
docker compose -p trustables-dyou-local stop
```

For a fresh backend checkout, generate fixtures with `./softhsm/gen-keys.sh`
and build `./gradlew bootJar` under JDK 25 before starting Compose. This
workstation used the official `eclipse-temurin:25-jdk-noble` Docker image to
build the jar. Generated private keys stay in the backend's ignored
`softhsm/generated/` directory.

## Scope

### Erika Mustermann UI fixture

In Overview, use **Use mock ID — Erika Mustermann** to add or remove the
synthetic PID. This control exists only in explicit local simulator mode.
It requires no issuer connection and persists the credential in the simulator
Keychain. The card is labelled **Mock ID — Erika Mustermann**. To seed it at launch:

```sh
TRUSTABLES_MOCK_PID=erika ./scripts/run-simulator.sh
```

The fixture is a locally signed SD-JWT with synthetic name, birth date,
nationality and adult-age claims. It has no holder key and the wallet's
presentation selection excludes it. It is for UI testing; it cannot complete
a Trustables identity verification. The upstream **Use simulated eID card**
switch instead simulates the NFC card during issuance, which still requires
an available PID issuer.

Two Overview bugs were corrected: an empty credential list incorrectly counted
as loading forever, and the PID lookup only selected mdoc, ignoring SD-JWT.
Verified in the simulator: switch off returns to an interactive empty Overview;
switch on creates the mock; opening Personal data displays Erika Mustermann,
DE nationality and the synthetic birth date; relaunch preserves the mock.

Verified on 2026-09-19 with Xcode 26.6 and the iPhone 17 Pro / iOS 26.5
simulator: build succeeds, the app launches, the welcome and wallet-loss
protection screens render, and the local database contains one device account
and one wallet account from registration. This initial smoke test did not include a PID presentation.

The backend readiness endpoint returns overall `UP`, but a later probe
reported its `hsm` component as `UNKNOWN` due to a session-pool timeout. Treat
that component separately from the overall readiness status before extending
the lab to signing and issuance tests.

This is a local development wallet, not an enrolled sandbox wallet. The
upstream PID issuer remains unconfigured. The E2E mode below adds synthetic credential issuance and a matching test trust
configuration. An app launch or local wallet registration is not evidence of
successful PID presentation or official d-you sandbox interoperability.

## Presentable E2E test credential

`TRUSTABLES_E2E_PID=erika ./scripts/run-simulator.sh` enables the separate
`trustables-e2e-erika-mustermann` credential. It creates a P-256 holder key in the
wallet software secure area and requests a one-hour signed SD-JWT from
`http://localhost:8088/issue`. The issuer script lives in the Trustables backend
repository under `scripts/e2e/local_pid_issuer.py`.

Place the actual test relying-party certificate in the app container's
`Documents/northline-test-reader.der` before launch. It is added to reader trust
only in explicitly enabled simulator E2E mode. The generated PID issuer is
trusted by the development backend using a signed LoTE and pinned root hash.
Request and credential signatures remain checked.

The wallet's normal OpenID4VP request, consent, selective disclosure, holder
signature and encrypted response flow is used. Only this fixture skips the
remote-WSCA PIN route because its key is local software. It does not establish
hardware protection, official issuer enrollment, NFC, device attestation, or
production trust. The fixture refreshes on document load after 50 minutes.

The old Overview switch remains a display-only mock; it is a separate document.
Do not use it as evidence of a successful presentation.

Development backend trust configuration and deployment changes for the test
are recorded in the Trustables repository's Northline E2E report.
