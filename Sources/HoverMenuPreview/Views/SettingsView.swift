import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var calendarStore = GoogleCalendarStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Display")
                    .font(.system(size: 13, weight: .bold))

                Picker("Display", selection: $settings.displayPlacementMode) {
                    ForEach(DisplayPlacementMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(settings.displayPlacementMode.detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Google Calendar")
                    .font(.system(size: 13, weight: .bold))

                HStack(spacing: 10) {
                    calendarStatus

                    Spacer()

                    if calendarStore.isSignedIn {
                        Button("Disconnect") {
                            calendarStore.signOut()
                        }
                    } else {
                        Button(calendarConnectTitle) {
                            calendarStore.signIn()
                        }
                        .disabled(!calendarStore.isConfigured || calendarStore.connectionState == .signingIn)
                    }
                }

                if let message = calendarStore.lastErrorMessage {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 420, height: 230)
    }

    private var calendarStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: calendarStatusSymbol)
                .foregroundStyle(calendarStore.isSignedIn ? .green : .secondary)

            Text(calendarStatusText)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    private var calendarStatusSymbol: String {
        switch calendarStore.connectionState {
        case .missingConfiguration:
            return "key.slash"
        case .signedOut:
            return "person.crop.circle.badge.plus"
        case .needsReconnect:
            return "exclamationmark.arrow.triangle.2.circlepath"
        case .signingIn:
            return "arrow.triangle.2.circlepath"
        case .signedIn:
            return "checkmark.circle.fill"
        }
    }

    private var calendarStatusText: String {
        switch calendarStore.connectionState {
        case .missingConfiguration:
            return "Set GOOGLE_CLIENT_ID and relaunch."
        case .signedOut:
            return "Not connected"
        case .needsReconnect:
            return "Reconnect to allow editing"
        case .signingIn:
            return "Waiting for Google sign-in"
        case .signedIn:
            return "Connected"
        }
    }

    private var calendarConnectTitle: String {
        switch calendarStore.connectionState {
        case .signingIn:
            return "Connecting"
        case .needsReconnect:
            return "Reconnect"
        default:
            return "Connect"
        }
    }
}
