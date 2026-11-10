//
// XPaddleSettingsView.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI

struct XPaddleSettingsView: View {
    @Binding var soundEnabled: Bool
    @Binding var blackHole: Bool
    @Binding var smarterAI: Bool
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            xpaddleText("SETTINGS")
                .font(.system(size: 34, weight: .heavy, design: .monospaced))
                .foregroundStyle(.yellow)

            optionRow(isOn: $soundEnabled) {
                Image(systemName: soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    .font(.system(size: 25, weight: .semibold))
                    .frame(width: 64, height: 42)
                    .accessibilityLabel(xpaddleText("Sound"))
            }

            optionRow(isOn: $blackHole) {
                BlackHoleOptionIcon(isOn: blackHole)
            }

            optionRow(isOn: $smarterAI) {
                xpaddleText("SMARTER AI")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .frame(width: 180, alignment: .leading)
            }

            Text("Drag your paddle. First to \(GameEngine.winningScore) wins.\nPlay Nearby: place two iPhones side by side\nand rally the ball between screens.", tableName: "XPaddle")
                .multilineTextAlignment(.center)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.55))

            Button(action: onBack) {
                xpaddleText("BACK")
                    .font(.system(size: 17, weight: .bold, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.vertical, 12)
                    .frame(width: 340)
                    .background(Color.yellow)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBlue)
    }

    private func optionRow<Label: View>(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) -> some View {
        Toggle(isOn: isOn, label: label)
            .tint(.yellow)
            .frame(width: 340)
    }
}

private struct BlackHoleOptionIcon: View {
    let isOn: Bool

    var body: some View {
        Group {
            if isOn {
                TimelineView(.periodic(from: .now, by: 0.18)) { timeline in
                    let frame = Int(timeline.date.timeIntervalSinceReferenceDate / 0.18) % 3
                    Image(["BlackHole0", "BlackHole1", "BlackHole2"][frame])
                        .resizable()
                        .scaledToFit()
                }
            } else {
                Image("BlackHoleIcon")
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: 64, height: 64)
        .accessibilityLabel(xpaddleText("Black Hole"))
    }
}
