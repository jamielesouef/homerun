import SwiftUI

struct CleanupItemRow: View {
    // MARK: - Inputs

    let item: CleanupItem
    let isSelected: Bool
    let toggle: () -> Void

    // MARK: - View

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.medium) {
            Toggle(isOn: selectionBinding) {
                EmptyView()
            }
            .toggleStyle(.checkbox)
            .labelsHidden()
            .disabled(item.isDeletable == false)

            VStack(alignment: .leading, spacing: AppSpacing.xsmall) {
                Text(item.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if item.isDeletable == false {
                    Text(String(localized: "homerun will not remove this."))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Spacer(minLength: AppSpacing.small)

            Text(item.formattedSize)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, AppSpacing.xsmall)
    }

    // MARK: - Helpers

    private var selectionBinding: Binding<Bool> {
        Binding(get: { isSelected }, set: { _ in toggle() })
    }
}

#if DEBUG
#Preview("Removable and protected") {
    List {
        CleanupItemRow(
            item: CleanupItem(
                title: "iOS 18.0 (22A3351)",
                detail: "/Library/Developer/CoreSimulator/Images/R1.dmg",
                sizeBytes: 7_100_000_000,
                category: .simulatorRuntimes,
                target: .simulatorRuntime("R1"),
                isDeletable: true
            ),
            isSelected: true,
            toggle: {}
        )
        CleanupItemRow(
            item: CleanupItem(
                title: "iOS 17.5 bundled with Xcode",
                detail: "/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes",
                sizeBytes: 5_000_000_000,
                category: .simulatorRuntimes,
                target: .simulatorRuntime("R2"),
                isDeletable: false
            ),
            isSelected: false,
            toggle: {}
        )
    }
    .frame(width: 620, height: 200)
}
#endif
