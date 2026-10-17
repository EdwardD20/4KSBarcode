//
// DuelView.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI
import Combine

struct DuelView: View {
    @StateObject private var engine = DuelEngine()
    @StateObject private var safeArea = SafeAreaProvider()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                if engine.phase == .connecting || engine.phase == .connectionLost {
                    ConnectingOverlay(engine: engine, dismiss: dismiss)
                } else {
                    DuelCourtView(engine: engine)
                        .onAppear {
                            engine.configureCourt(geo.size)
                        }
                        .onChange(of: geo.size) { _, newSize in engine.configureCourt(newSize) }
                        .onReceive(safeArea.$insets) { insets in
                            engine.configureSafeArea(leading: insets.left, trailing: insets.right)
                        }

                    if engine.phase == .gameOver {
                        DuelGameOverOverlay(engine: engine, dismiss: dismiss)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .background(Color.black)
        .onAppear {
            engine.start()
            safeArea.begin()
        }
        .onDisappear {
            engine.stop()
            safeArea.stop()
        }
    }
}

// MARK: - Connecting

private struct ConnectingOverlay: View {
    @ObservedObject var engine: DuelEngine
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Text("XPaddle")
                .font(.system(size: 48, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)
                .kerning(6)

            if engine.phase == .connectionLost {
                Text("CONNECTION LOST")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                Button { engine.start() } label: { pillLabel("SEARCH AGAIN") }
            } else {
                ProgressView()
                    .tint(.white)
                Text(engine.connectionLabel)
                    .font(.system(size: 15, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                Text("Bring both phones close together.\nMake sure Wi-Fi and Bluetooth are on,\nand XPaddle is open on both.")
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
            }

            Button { dismiss() } label: { pillLabel("CANCEL", filled: false) }
        }
        .padding(40)
    }

    private func pillLabel(_ text: String, filled: Bool = true) -> some View {
        Text(text)
            .font(.system(size: 16, weight: .bold, design: .monospaced))
            .foregroundStyle(filled ? .black : .white)
            .padding(.vertical, 12)
            .frame(width: 240)
            .background(filled ? Color.white : Color.clear)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: filled ? 0 : 2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Court

private struct DuelCourtView: View {
    @ObservedObject var engine: DuelEngine

    var body: some View {
        TimelineView(.animation(paused: engine.phase != .playing)) { context in
            Canvas { ctx, size in
                drawSeamHint(ctx: &ctx, size: size)
                drawPaddle(ctx: &ctx, size: size)
                if engine.ballVisible {
                    drawBall(ctx: &ctx)
                }
            }
            .onChange(of: context.date) { _, newDate in engine.tick(now: newDate) }
        }
        .overlay(alignment: .top) {
            DuelScoreBar(engine: engine).padding(.top, 24)
        }
        .overlay {
            statusOverlay
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if engine.phase == .serving { engine.serve() }
                    engine.paddleTarget = value.location.y
                }
        )
    }

    @ViewBuilder
    private var statusOverlay: some View {
        switch engine.phase {
        case .serving:
            Text("TAP TO SERVE")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .padding(16)
                .background(.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .allowsHitTesting(false)
        case .waitingForBall:
            Text("OPPONENT'S SERVE…")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
                .allowsHitTesting(false)
        default:
            EmptyView()
        }
    }

    private func drawSeamHint(ctx: inout GraphicsContext, size: CGSize) {
        // A faint bar marking the edge that's touching the other phone,
        // so it's clear which side the ball disappears/appears from.
        let x: CGFloat = engine.isLeftSide ? size.width - 3 : 0
        let rect = CGRect(x: x, y: 0, width: 3, height: size.height)
        ctx.fill(Path(rect), with: .color(.white.opacity(0.2)))
    }

    private func drawPaddle(ctx: inout GraphicsContext, size: CGSize) {
        let rect = CGRect(x: engine.paddleX - engine.paddleWidth / 2, y: engine.paddleY - engine.paddleHeight / 2,
                           width: engine.paddleWidth, height: engine.paddleHeight)
        ctx.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white))
    }

    private func drawBall(ctx: inout GraphicsContext) {
        let rect = CGRect(x: engine.ballPos.x - engine.ballSize / 2, y: engine.ballPos.y - engine.ballSize / 2,
                           width: engine.ballSize, height: engine.ballSize)
        ctx.fill(Path(ellipseIn: rect), with: .color(.white))
    }
}

private struct DuelScoreBar: View {
    @ObservedObject var engine: DuelEngine

    var body: some View {
        HStack(spacing: 32) {
            scoreBlock(label: "YOU", value: engine.localScore)
            Text(":").foregroundStyle(.white.opacity(0.3))
            scoreBlock(label: "THEM", value: engine.opponentScore)
        }
        .font(.system(size: 32, weight: .bold, design: .monospaced))
        .foregroundStyle(.white)
    }

    private func scoreBlock(label: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Game over

private struct DuelGameOverOverlay: View {
    @ObservedObject var engine: DuelEngine
    let dismiss: DismissAction

    var body: some View {
        VStack(spacing: 24) {
            Text(engine.winnerIsMe == true ? "YOU WIN" : "YOU LOSE")
                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                .foregroundStyle(.white)

            Text("\(engine.localScore) — \(engine.opponentScore)")
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 16) {
                Button { engine.requestRematch() } label: {
                    Text("REMATCH")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.vertical, 12)
                        .frame(width: 150)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button { dismiss() } label: {
                    Text("EXIT")
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.vertical, 12)
                        .frame(width: 150)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white, lineWidth: 2))
                }
            }
        }
        .padding(40)
        .background(Color.black.opacity(0.001))
    }
}

#Preview {
    DuelView()
}
