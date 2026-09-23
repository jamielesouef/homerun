import Foundation

struct SyncPlan: Equatable {
    let steps: [SyncPlanStep]

    static let empty = SyncPlan(steps: [])

    var actionableSteps: [SyncPlanStep] {
        steps.filter(\.isActionable)
    }

    var blockedSteps: [SyncPlanStep] {
        steps.filter { step in
            switch step.action {
            case .blocked:
                true
            case .commitAndPush,
                 .nothingToDo:
                false
            }
        }
    }

    var isEmpty: Bool {
        actionableSteps.isEmpty
    }
}
