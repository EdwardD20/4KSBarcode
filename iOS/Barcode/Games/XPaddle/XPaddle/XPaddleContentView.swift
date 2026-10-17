//
// XPaddleContentView.swift
//
// My original XPaddle game conceived in 2009 and was written in Objective C.
// Unfortunately the original source was lost.
//
// In 2026, I found this project on GitHub.com and adapted it back to my original game.
// Adapted from: https://github.com/rickyjonesus/pong
//

import SwiftUI
import UIKit

extension Color {
    static let darkBlue = Color(red: 0.0, green: 0.0, blue: 0.55)
} // extension Color

extension ShapeStyle where Self == Color {
    static var darkBlue: Color {
        Color(red: 0.0, green: 0.0, blue: 0.55)
    } // var darkBlue
} // extension ShapeStyle

struct XPaddleContentView: View {
    
    let onExitToHost: (() -> Void)?

    init(onExitToHost: (() -> Void)? = nil) {
        self.onExitToHost = onExitToHost
    }

    @StateObject private var engine = GameEngine()
    @StateObject private var safeArea = SafeAreaProvider()
    @State private var showNearbyDuel = false
    @State private var showSettings = false
    @AppStorage("xpaddle.soundEnabled") private var soundEnabled = true
    @AppStorage("xpaddle.smarterAI") private var smarterAI = false
    @AppStorage("xpaddle.blackHole") private var blackHole = false

    var body: some View {
        GeometryReader { geo in
            let isPortrait = geo.size.height > geo.size.width

            ZStack {
                Color.darkBlue.ignoresSafeArea()

                if !showSettings {
                    CourtView(engine: engine, isPortrait: isPortrait)
                        .onAppear {
                            engine.configureCourt(geo.size, isPortrait: isPortrait)
                            safeArea.begin()
                        }
                        .onChange(of: geo.size) { _, newSize in
                            engine.configureCourt(newSize, isPortrait: newSize.height > newSize.width)
                        }
                        .onReceive(safeArea.$insets) { insets in
                            if isPortrait {
                                engine.configureSafeArea(leading: insets.top, trailing: insets.bottom)
                            } else {
                                engine.configureSafeArea(leading: insets.left, trailing: insets.right)
                            }
                        }
                }

                if let onExitToHost {
                    VStack {
                        HStack {
                            Button(LocalizedStringKey("Return to app"), action: onExitToHost)
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(.red.opacity(0.4), in: Capsule())
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(.top, 76)
                    .padding(.leading, 12)
                    .zIndex(1)
                } // if let onExitToHost

                switch engine.phase {
                case .menu:
                    if showSettings {
                        XPaddleSettingsView(soundEnabled: $soundEnabled,
                                     blackHole: $blackHole,
                                     smarterAI: $smarterAI,
                                     onBack: { showSettings = false })
                    } else {
                        MenuOverlay(engine: engine,
                                    showSettings: $showSettings,
                                    showNearbyDuel: $showNearbyDuel,
                                    embedded: onExitToHost != nil)
                    } // if showSettings
                case .serving:
                    ServeOverlay(engine: engine)
                case .gameOver:
                    GameOverOverlay(engine: engine)
                default:
                    EmptyView()
                } // engine.phaase
            } // Stack
        } // GeometryReader
        .ignoresSafeArea()
        .background(Color.darkBlue)
        .fullScreenCover(isPresented: $showNearbyDuel) {
            DuelView()
        } // fullScreenCover
        .onAppear { applyOptions() }
        .onChange(of: soundEnabled) { _, _ in applyOptions() }
        .onChange(of: smarterAI) { _, _ in applyOptions() }
        .onChange(of: blackHole) { _, _ in applyOptions() }
    } // body

    private func applyOptions() {
        engine.configureOptions(soundEnabled: soundEnabled, smarterAI: smarterAI, blackHole: blackHole)
    }
}

// MARK: - Court (gameplay canvas)

private struct CourtView: View {
    @ObservedObject var engine: GameEngine
    let isPortrait: Bool

    var body: some View {
        TimelineView(.animation(paused: engine.phase != .playing)) { context in
            Canvas { ctx, _ in
                // The model always thinks in landscape logical coordinates
                // (x = axis between paddles, y = axis a paddle slides
                // along). In portrait we transpose that coordinate space
                // onto the screen with a single transform, so every draw
                // call below can stay orientation-agnostic.
                if isPortrait {
                    ctx.transform = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
                }
                let size = engine.courtSize
                if engine.blackHoleEnabled, let blackHolePosition = engine.blackHolePosition {
                    drawBlackHole(ctx: &ctx, position: blackHolePosition, date: context.date)
                }
                drawNet(ctx: &ctx, size: size)
                drawPaddle(ctx: &ctx,
                           x: engine.leftPaddleX,
                           y: engine.leftPaddleY,
                           engine: engine)
                drawPaddle(ctx: &ctx,
                           x: engine.rightPaddleX,
                           y: engine.rightPaddleY,
                           engine: engine)
                if !engine.isBallHidden {
                    let isMouthOpen = engine.ballMouthOpenUntil.map { context.date < $0 } ?? false
                    drawBall(ctx: &ctx, engine: engine, isMouthOpen: isMouthOpen, isPortrait: isPortrait)
                }
            } // Canvas
            .onChange(of: context.date) { _, newDate in
                engine.tick(now: newDate)
            } // onChange
        } // TimelineVIew
        .overlay(
            // A SwiftUI DragGesture only ever tracks one active touch, which
            // is why 2-player mode couldn't register two fingers on opposite
            // halves at once. This drops to raw UIKit touch tracking (a
            // Set<UITouch>) instead, so each finger drives its own paddle
            // independently. It's layered *below* the score bar overlay so
            // the pause button in front of it still gets first crack at taps.
            TouchInputView(
                onTouchesBegan: {
                    if engine.phase == .serving {
                        engine.serve()
                    } // engine.phase
                },
                onTouchesChanged: { touches, view in
                    handleTouches(touches, in: view)
                }
            )
        ) // overlay (multitouch paddle input)
        .overlay(alignment: .top) {
            ScoreBar(engine: engine)
                .padding(.top, 24)
        } // overlay (score bar)
    } // body

    /// Screen point -> logical point. The transpose is its own inverse,
    /// so this is the exact reverse of the canvas transform above.
    private func toLogical(_ p: CGPoint) -> CGPoint {
        isPortrait ? CGPoint(x: p.y, y: p.x) : p
    } // toLogical

    /// Applies every currently active touch to whichever paddle it's over.
    /// Because this reads the full touch set directly (rather than a single
    /// SwiftUI gesture value), two touches on opposite halves in 2-player
    /// mode move both paddles independently and simultaneously.
    private func handleTouches(_ touches: Set<UITouch>, in view: UIView) {
        let width = engine.courtSize.width
        guard width > 0 else { return } // guard width > 0

        for touch in touches {
            let loc = toLogical(touch.location(in: view))
            let isLeftSide = loc.x < width / 2
            if isLeftSide {
                if engine.twoPlayerMode {
                    engine.leftPaddleTarget = loc.y
                } // twoPlayerMode
            } else {
                engine.rightPaddleTarget = loc.y
            } // if isLeftSide
        } // for touch in touches
    } // handleTouches

    private func drawBlackHole(ctx: inout GraphicsContext, position: CGPoint, date: Date) {
        let frame = Int(date.timeIntervalSinceReferenceDate / 0.18) % 3
        let image = ctx.resolve(Image(["BlackHole0", "BlackHole1", "BlackHole2"][frame]))
        let diameter = GameEngine.blackHoleDiameter
        let rect = CGRect(x: position.x - diameter / 2,
                          y: position.y - diameter / 2,
                          width: diameter,
                          height: diameter)
        ctx.draw(image, in: rect)
    }

    private func drawNet(ctx: inout GraphicsContext,
                         size: CGSize) {
        var path = Path()
        let dashHeight: CGFloat = 12
        let gap: CGFloat = 10
        var net: CGFloat = 0
        while net < size.height {
            path.addRect(CGRect(x: size.width / 2 - 2,
                                y: net,
                                width: 4,
                                height: dashHeight))
            net += dashHeight + gap
        } // while
        ctx.fill(path, with: .color(.yellow.opacity(0.4)))
    } // drawNet

    private func drawPaddle(ctx: inout GraphicsContext,
                            x: CGFloat,
                            y: CGFloat,
                            engine: GameEngine) {
        let rect = CGRect(x: x - engine.paddleWidth / 2,
                          y: y - engine.paddleHeight / 2,
                          width: engine.paddleWidth,
                          height: engine.paddleHeight)
        let path = Path(roundedRect: rect, cornerRadius: 3)
        ctx.fill(path, with: .color(.yellow))
    } // drawPaddle

    private func drawBall(ctx: inout GraphicsContext,
                          engine: GameEngine,
                          isMouthOpen: Bool,
                          isPortrait: Bool) {
        let rect = CGRect(x: engine.ballPos.x - engine.ballSize / 2,
                          y: engine.ballPos.y - engine.ballSize / 2,
                          width: engine.ballSize,
                          height: engine.ballSize)
        let assetName: String
        if isPortrait {
            assetName = isMouthOpen ? "Ball_Open_Mouth_Portrait" : "Ball_Portrait"
        } else {
            assetName = isMouthOpen ? "Ball_Open_Mouth" : "Ball"
        }
        ctx.draw(ctx.resolve(Image(assetName)), in: rect)
    } // drawBall
}

// MARK: - Multitouch paddle input

/// Bridges raw UIKit touch tracking into SwiftUI. `isMultipleTouchEnabled`
/// plus overriding `touches*` (instead of a SwiftUI gesture) is what lets
/// two fingers be tracked independently at once.
private final class TouchTrackingUIView: UIView {
    var onTouchesBegan: (() -> Void)?
    var onTouchesChanged: ((Set<UITouch>, UIView) -> Void)?

    private var activeTouches: Set<UITouch> = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    } // init(frame:)

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    } // init(coder:)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.formUnion(touches)
        onTouchesBegan?()
        onTouchesChanged?(activeTouches, self)
    } // touchesBegan

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTouchesChanged?(activeTouches, self)
    } // touchesMoved

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        onTouchesChanged?(activeTouches, self)
    } // touchesEnded

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        activeTouches.subtract(touches)
        onTouchesChanged?(activeTouches, self)
    } // touchesCancelled
} // class TouchTrackingUIView

private struct TouchInputView: UIViewRepresentable {
    let onTouchesBegan: () -> Void
    let onTouchesChanged: (Set<UITouch>, UIView) -> Void

    func makeUIView(context: Context) -> TouchTrackingUIView {
        let view = TouchTrackingUIView()
        view.onTouchesBegan = onTouchesBegan
        view.onTouchesChanged = onTouchesChanged
        return view
    } // makeUIView

    func updateUIView(_ uiView: TouchTrackingUIView, context: Context) {
        uiView.onTouchesBegan = onTouchesBegan
        uiView.onTouchesChanged = onTouchesChanged
    } // updateUIView
} // struct TouchInputView

private struct ScoreBar: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        HStack {
            Spacer()
            Text("\(engine.leftScore)")
                .frame(minWidth: 60)
            Spacer()
            Button {
                engine.backToMenu()
            } label: {
                Image(systemName: "pause.fill")
                    .foregroundStyle(.yellow.opacity(0.6))
                    .padding(10)
            }
            Spacer()
            Text("\(engine.rightScore)")
                .frame(minWidth: 60)
            Spacer()
        }
        .font(.system(size: 44, weight: .bold, design: .monospaced))
        .foregroundStyle(.yellow)
    }
}

// MARK: - Overlays

private struct MenuOverlay: View {
    @ObservedObject var engine: GameEngine
    @Binding var showSettings: Bool
    @Binding var showNearbyDuel: Bool
    var embedded: Bool
    
    var body: some View {
        VStack(spacing: 28) {
            Text("XPaddle")
                .font(.system(size: 48, weight: .heavy, design: .monospaced))
                .foregroundStyle(.yellow)
                .kerning(8)

            VStack(spacing: 16) {
                Button {
                    engine.startGame(twoPlayer: false)
                } label: {
                    menuLabel("1 PLAYER  (VS CPU)")
                } // label
                if !embedded {
                    Button {
                        engine.startGame(twoPlayer: true)
                    } label: {
                        menuLabel("2 PLAYER  (SAME DEVICE)")
                    }
                    Button { showNearbyDuel = true } label: { menuLabel("PLAY NEARBY  (2 DEVICES)") }
                } // if let onExitToHost
                Button { showSettings = true } label: { menuLabel("SETTINGS") }
            } // VStack
        } // VStack
        .padding(10)
        .background(Color.darkBlue.opacity(0.001)) // capture taps but stay invisible
    } // body

    private func menuLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold, design: .monospaced))
            .foregroundStyle(.black)
            .padding(.vertical, 14)
            .frame(width: 340)
            .background(Color.yellow)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct ServeOverlay: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(spacing: 14) {
            Text("TAP TO SERVE")
                .font(.system(size: 26, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow)
            Text(engine.twoPlayerMode
                 ? (engine.isPortrait ? "Player 1 (top) vs Player 2 (bottom)" : "Player 1 (left) vs Player 2 (right)")
                 : (engine.isPortrait ? "You are the bottom paddle" : "You are the right paddle"))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.6))
        }
        .padding(20)
        .background(.darkBlue.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

private struct GameOverOverlay: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        VStack(spacing: 24) {
            Text("\(engine.winner ?? "") WINS")
                .font(.system(size: 40, weight: .heavy, design: .monospaced))
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.center)

            Text("\(engine.leftScore) — \(engine.rightScore)")
                .font(.system(size: 24, weight: .bold, design: .monospaced))
                .foregroundStyle(.yellow.opacity(0.7))

            HStack(spacing: 16) {
                Button {
                    engine.startGame(twoPlayer: engine.twoPlayerMode)
                } label: {
                    Text("REMATCH")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.vertical, 12)
                        .frame(width: 160)
                        .background(Color.yellow)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                Button {
                    engine.backToMenu()
                } label: {
                    Text("MENU")
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundStyle(.yellow)
                        .padding(.vertical, 12)
                        .frame(width: 160)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow, lineWidth: 2))
                }
            }
        }
        .padding(40)
    }
}

#Preview {
    XPaddleContentView()
}
