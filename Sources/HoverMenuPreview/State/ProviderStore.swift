import Combine
import Foundation

@MainActor
final class ProviderStore: ObservableObject {
    let registry: ProviderRegistry
    @Published var selectedPluginID: PluginID?
    @Published private(set) var states: [PluginID: ProviderState]

    private var refreshTask: Task<Void, Never>?

    init(registry: ProviderRegistry = .empty) {
        self.registry = registry
        self.selectedPluginID = registry.manifests.first?.id
        self.states = Dictionary(
            uniqueKeysWithValues: registry.manifests.map { ($0.id, ProviderState.idle) }
        )
    }

    var selectedProvider: (any NotchProvider)? {
        registry.provider(for: selectedPluginID)
    }

    func select(_ id: PluginID) {
        guard selectedPluginID != id else { return }
        selectedPluginID = id
        refreshSelected(reason: .userRequested)
    }

    func state(for id: PluginID) -> ProviderState {
        states[id] ?? .idle
    }

    func snapshot(for id: PluginID) -> ProviderSnapshot? {
        states[id]?.snapshot
    }

    func refreshSelected(reason: RefreshReason) {
        guard let provider = selectedProvider else { return }
        guard shouldRefresh(provider: provider, reason: reason) else { return }

        refreshTask?.cancel()

        let id = provider.manifest.id
        let previous = states[id]?.snapshot
        states[id] = ProviderState(phase: .loading, snapshot: previous)

        refreshTask = Task { [weak self, provider] in
            do {
                let snapshot = try await provider.refresh(context: .empty, reason: reason)
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.states[id] = ProviderState(phase: .ready, snapshot: snapshot)
                }
            } catch is CancellationError {
                return
            } catch {
                await MainActor.run {
                    guard let self, !Task.isCancelled else { return }
                    self.states[id] = ProviderState(
                        phase: .failed(error.localizedDescription),
                        snapshot: previous
                    )
                }
            }
        }
    }

    private func shouldRefresh(provider: any NotchProvider, reason: RefreshReason) -> Bool {
        switch reason {
        case .appLaunch:
            return provider.manifest.refreshPolicy != .manual
        case .panelOpened:
            return provider.manifest.refreshPolicy == .onPanelOpen
        case .timer:
            if case .interval = provider.manifest.refreshPolicy {
                return true
            }
            return false
        case .userRequested:
            return true
        case .dependencyChanged:
            return provider.manifest.refreshPolicy != .manual
        }
    }

    deinit {
        refreshTask?.cancel()
    }
}
