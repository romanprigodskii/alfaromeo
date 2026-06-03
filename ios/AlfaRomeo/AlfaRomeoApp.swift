import SwiftUI

/// App entry point. Owns the single ``AppSession`` (cold start → splash → pre-auth flow) and
/// injects dependencies into the environment (DI pin).
@main
struct AlfaRomeoApp: App {
    @State private var session: AppSession

    // TEMPORARY verification harness — see ScreenshotHost. `-ARShot <name>` renders one target screen.
    private let shotName: String? = {
        #if DEBUG
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "-ARShot"), i + 1 < args.count { return args[i + 1] }
        #endif
        return nil
    }()

    init() {
        let session = AppSession()
        #if DEBUG
        // Demo/QA shortcut: `-ARDemoBusiness` boots straight into the authenticated business profile,
        // so business-mode tabs can be exercised/screenshotted without driving the pre-auth flow. The
        // initial business tab can be preselected via the `AR_BUSINESS_TAB` env var (see BusinessTabView).
        if CommandLine.arguments.contains("-ARDemoBusiness") {
            let business = MockData.profiles.first { $0.type == .business } ?? MockData.profiles[0]
            session.completeAuthentication(user: MockData.user, profile: business, profiles: MockData.profiles)
        }
        #endif
        _session = State(initialValue: session)
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let shotName {
                ScreenshotHost(name: shotName)
            } else {
                RootView()
                    .environment(session)
                    .environment(\.apiClient, MockAPIClient())
            }
            #else
            RootView()
                .environment(session)
                .environment(\.apiClient, MockAPIClient())
            #endif
        }
    }
}
