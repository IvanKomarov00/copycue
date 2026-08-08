import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "CopyCue Settings"
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.moveToActiveSpace]
        window.center()

        let settingsView = SettingsView { [weak window] in
            window?.close()
        }
        window.contentView = NSHostingView(rootView: settingsView)

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}

private struct SettingsView: View {
    @AppStorage(FeedbackDurationOption.defaultsKey)
    private var durationRawValue = FeedbackDurationOption.medium.rawValue

    let onDone: () -> Void

    private var durationSelection: Binding<FeedbackDurationOption> {
        Binding(
            get: {
                FeedbackDurationOption(rawValue: durationRawValue) ?? .medium
            },
            set: { option in
                durationRawValue = option.rawValue
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            introduction
            sectionDivider
            durationSettings
            sectionDivider
            privacySummary
            Spacer(minLength: 18)

            HStack {
                Spacer()
                Button("Done", action: onDone)
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                    .frame(minWidth: 84)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 22)
        .frame(width: 520, height: 430)
    }

    private var introduction: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(Color.blue.opacity(0.12))
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(.blue)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("Copy with confidence")
                    .font(.title2.weight(.semibold))
                Text("CopyCue confirms successful clipboard changes with a blue underline beneath the current cursor and a temporary menu-bar checkmark.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var sectionDivider: some View {
        Divider()
            .padding(.vertical, 19)
    }

    private var durationSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cursor feedback duration")
                .font(.headline)

            VStack(spacing: 9) {
                Picker("Cursor feedback duration", selection: durationSelection) {
                    ForEach(FeedbackDurationOption.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .controlSize(.large)
                .frame(width: 220)

                HStack(spacing: 0) {
                    ForEach(FeedbackDurationOption.allCases) { option in
                        Text(option.durationLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 220)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Changes apply to the next copy and remain selected after CopyCue restarts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var privacySummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            summaryRow(
                icon: "keyboard",
                text: "Monitors clipboard changes—not keyboard input"
            )
            summaryRow(
                icon: "clock.arrow.circlepath",
                text: "Keeps only the current and previous text in memory"
            )
            summaryRow(
                icon: "lock.shield",
                text: "Clears text history when CopyCue quits"
            )
        }
        .font(.callout)
    }

    private func summaryRow(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20, alignment: .center)
            Text(text)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
