import SwiftUI

/// What the preview shows and offers for one asset. Each screen builds it from its own state,
/// so the viewer holds no decision logic.
struct PreviewChoice {
    struct Status {
        let text: String
        let tint: Color
    }

    struct Action {
        let title: String
        let tint: Color
        let perform: () -> Void
    }

    let status: Status?
    let actions: [Action]
    /// The viewer drops a screen's actions for a protected item, unless they cannot queue a decision.
    var keepsActionsWhenProtected = false
}
