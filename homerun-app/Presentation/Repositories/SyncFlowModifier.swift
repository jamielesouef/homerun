import SwiftUI

struct SyncFlowModifier: ViewModifier {
    // MARK: - Environment

    @Environment(\.syncService) private var sync

    // MARK: - View

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isShowingReview) {
                SyncReviewSheet()
            }
            .sheet(isPresented: isShowingRun) {
                SyncRunSheet()
            }
    }

    // MARK: - Helpers

    private var isShowingReview: Binding<Bool> {
        Binding(
            get: { sync.reviewPlan != nil },
            set: { isPresented in
                guard isPresented == false else {
                    return
                }

                sync.cancelReview()
            }
        )
    }

    private var isShowingRun: Binding<Bool> {
        Binding(
            get: {
                switch sync.phase {
                case .running,
                     .finished:
                    true
                case .idle,
                     .reviewing:
                    false
                }
            },
            set: { isPresented in
                guard isPresented == false else {
                    return
                }

                sync.dismissSummary()
            }
        )
    }
}

extension View {
    func syncFlow() -> some View {
        modifier(SyncFlowModifier())
    }
}
