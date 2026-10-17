//
//  Barcode/SplashRevealStyle.swift
//
//  Created by Ed Danley on 10/2/26.
//

import SwiftUI

enum SplashRevealStyle: CaseIterable {
    case circularWipe
    case radialBurst
    case irisOpening
    case particleBurst
    case zoomThrough
    case lightFlash
    case panelReveal
    case horizontalWipe
    case diagonalWipe
    case spiral
    case pixelMosaic
    case shutterBlades

    static func random() -> Self {
        let style = allCases.randomElement() ?? .circularWipe
        #if DEBUG
        print("[SplashTransition] Selected style: \(style)")
        #endif
        return style
    } // random

} // SplashRevealStyle

struct SplashRevealProgress: ViewModifier, Animatable {
    let style: SplashRevealStyle
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }

    @ViewBuilder
    func body(content: Content) -> some View {
        switch style {
        case .circularWipe:
            content.modifier(CircularRevealModifier(progress: progress))
        case .radialBurst:
            content.modifier(RadialRevealModifier(progress: progress))
        case .irisOpening:
            content.modifier(IrisRevealModifier(progress: progress))
        case .particleBurst:
            content.modifier(ParticleRevealModifier(progress: progress))
        case .zoomThrough:
            content
                .scaleEffect(0.08 + 0.92 * progress, anchor: .center)
                .opacity(progress)
        case .lightFlash:
            content.opacity(progress)
        case .panelReveal:
            GeometryReader { proxy in
                content
                    .offset(y: (1 - progress) * proxy.size.height)
                    .opacity(progress)
            } // GeometryReader
        case .horizontalWipe, .diagonalWipe, .spiral, .pixelMosaic, .shutterBlades:
            content.modifier(GeometricRevealModifier(style: style, progress: progress))
        } // switch style
    } // body
} // SplashRevealProgress

private struct CircularRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        if progress >= 0.999 {
            content
        } else {
            GeometryReader { proxy in
                let diameter = hypot(proxy.size.width, proxy.size.height) * 2.0 * progress
                content.mask(
                    Circle()
                        .frame(width: diameter, height: diameter)
                        .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
                )
            } // GeometryReader
        } // if progress
    } // body
} // CircularRevealModifier

private struct RadialRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        if progress >= 0.999 {
            content
        } else {
            GeometryReader { proxy in
                content.mask(RadialBurstShape(points: 12, innerRadius: 0.28 + 0.72 * progress, outerRadius: progress * 1.2)
                    .frame(width: max(proxy.size.width, proxy.size.height) * 1.5, height: max(proxy.size.width, proxy.size.height) * 1.5))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } // GeometryReader
        } // if progress
    } // body
} // RadialRevealModifier

private struct IrisRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        if progress >= 0.999 {
            content
        } else {
            GeometryReader { proxy in
                content.mask(Ellipse().frame(width: proxy.size.width * progress * 1.8, height: proxy.size.height * progress * 1.8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity))
            } // GeometryReader
        } // if progress
    } // body
} // IrisRevealModifier

private struct ParticleRevealModifier: ViewModifier, Animatable {
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }
    func body(content: Content) -> some View {
        if progress >= 0.999 {
            content
        } else {
            GeometryReader { proxy in
                content.mask(ParticleBurstShape(progress: progress).frame(width: proxy.size.width, height: proxy.size.height))
            } // GeometryReader
        } // if progress
    } // body
} // ParticleRevealModifier

private struct GeometricRevealModifier: ViewModifier, Animatable {
    let style: SplashRevealStyle
    var progress: CGFloat
    var animatableData: CGFloat { get { progress } set { progress = newValue } }

    func body(content: Content) -> some View {
        if progress >= 0.999 {
            content
        } else {
            GeometryReader { proxy in
                content.mask(
                    GeometricRevealShape(style: style, progress: progress)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                )
            } // GeometryReader
        } // if progress
    } // body
} // GeometricRevealModifier

private struct GeometricRevealShape: Shape {
    var style: SplashRevealStyle
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    } // animatableData

    func path(in rect: CGRect) -> Path {
        switch style {
        case .horizontalWipe:
            return horizontalWipePath(in: rect)
        case .diagonalWipe:
            return diagonalWipePath(in: rect)
        case .spiral:
            return spiralPath(in: rect)
        case .pixelMosaic:
            return pixelMosaicPath(in: rect)
        case .shutterBlades:
            return shutterBladesPath(in: rect)
        default:
            return Path()
        } // switch style
    } // path

    private func horizontalWipePath(in rect: CGRect) -> Path {
        Path(CGRect(x: rect.minX, y: rect.minY, width: rect.width * progress, height: rect.height))
    } // horizontalWipePath

    private func diagonalWipePath(in rect: CGRect) -> Path {
        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY)
        ]
        let limit = progress * 2
        var clippedPoints: [CGPoint] = []

        for index in corners.indices {
            let start = corners[index]
            let end = corners[(index + 1) % corners.count]
            let startValue = (start.x - rect.minX) / rect.width + (start.y - rect.minY) / rect.height
            let endValue = (end.x - rect.minX) / rect.width + (end.y - rect.minY) / rect.height
            let startInside = startValue <= limit
            let endInside = endValue <= limit

            if startInside {
                clippedPoints.append(start)
            } // if startInside

            if startInside != endInside {
                let fraction = (limit - startValue) / (endValue - startValue)
                clippedPoints.append(CGPoint(
                    x: start.x + (end.x - start.x) * fraction,
                    y: start.y + (end.y - start.y) * fraction
                ))
            } // if edge crosses reveal line
        } // for index

        var path = Path()
        guard let firstPoint = clippedPoints.first else { return path }
        path.move(to: firstPoint)
        for point in clippedPoints.dropFirst() {
            path.addLine(to: point)
        } // for point
        path.closeSubpath()
        return path
    } // diagonalWipePath

    private func spiralPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let maxRadius = hypot(rect.width, rect.height) * 0.72
        let steps = 180
        let turns: CGFloat = 3.2
        var centerline = Path()

        for step in 0...steps {
            let fraction = CGFloat(step) / CGFloat(steps)
            let angle = fraction * turns * 2 * .pi - progress * .pi * 0.6
            let radius = maxRadius * progress * fraction
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if step == 0 {
                centerline.move(to: point)
            } else {
                centerline.addLine(to: point)
            } // if first spiral point
        } // for step

        return centerline.strokedPath(StrokeStyle(
            lineWidth: maxRadius * 0.34 * progress,
            lineCap: .round,
            lineJoin: .round
        ))
    } // spiralPath

    private func pixelMosaicPath(in rect: CGRect) -> Path {
        let columns = 12
        let rows = 18
        let tileWidth = rect.width / CGFloat(columns)
        let tileHeight = rect.height / CGFloat(rows)
        var path = Path()

        for row in 0..<rows {
            for column in 0..<columns {
                let order = (row * 37 + column * 19 + row * column * 7) % (rows * columns)
                let threshold = 0.08 + CGFloat(order) / CGFloat(rows * columns) * 0.82
                if progress >= threshold {
                    path.addRect(CGRect(
                        x: rect.minX + CGFloat(column) * tileWidth,
                        y: rect.minY + CGFloat(row) * tileHeight,
                        width: tileWidth + 0.5,
                        height: tileHeight + 0.5
                    ))
                } // if tile is revealed
            } // for column
        } // for row

        return path
    } // pixelMosaicPath

    private func shutterBladesPath(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height) * 0.8
        let bladeCount = 6
        let halfAngle = progress * .pi / CGFloat(bladeCount)
        let rotation = (1 - progress) * .pi / 5
        var path = Path()

        for blade in 0..<bladeCount {
            let angle = CGFloat(blade) * 2 * .pi / CGFloat(bladeCount) + rotation
            let firstEdge = CGPoint(
                x: center.x + cos(angle - halfAngle) * radius,
                y: center.y + sin(angle - halfAngle) * radius
            )
            let secondEdge = CGPoint(
                x: center.x + cos(angle + halfAngle) * radius,
                y: center.y + sin(angle + halfAngle) * radius
            )
            path.move(to: center)
            path.addLine(to: firstEdge)
            path.addLine(to: secondEdge)
            path.closeSubpath()
        } // for blade

        return path
    } // shutterBladesPath
} // GeometricRevealShape

private struct RadialBurstShape: Shape {
    var points: Int
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for i in 0..<(points * 2) {
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let r = radius * (i.isMultiple(of: 2) ? outerRadius : innerRadius)
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
        } // for i
        path.closeSubpath()
        return path
    } // path
} // RadialBurstShape

private struct ParticleBurstShape: Shape {
    var progress: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = hypot(rect.width, rect.height) * progress
        path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        for i in 0..<14 {
            let angle = CGFloat(i) * 2 * .pi / 14
            let distance = radius * 0.68
            let size = max(2, radius * 0.13)
            path.addEllipse(in: CGRect(x: center.x + cos(angle) * distance - size / 2,
                                       y: center.y + sin(angle) * distance - size / 2,
                                       width: size, height: size))
        } // for i
        return path
    } // path
} // ParticleBurstShape
