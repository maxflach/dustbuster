import SwiftUI

// MARK: - Layout model

private struct BubbleLayout: Identifiable {
    let id: UUID
    let name: String
    let size: Int64
    var radius: CGFloat
    var position: CGPoint
    var color: Color
}

// MARK: - View

struct BubbleChartView: View {
    let nodes: [FileSystemNode]
    var onTap: ((FileSystemNode) -> Void)? = nil

    @State private var layout: [BubbleLayout] = []
    @State private var viewSize: CGSize = .zero

    private let palette: [Color] = [
        .blue, .purple, .indigo, .cyan, .teal, .green,
        .orange, .pink, .mint, Color(hue: 0.55, saturation: 0.7, brightness: 0.9)
    ]

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(layout) { bubble in
                    bubbleCell(bubble)
                        .position(bubble.position)
                        .transition(.scale(scale: 0.01, anchor: .center).combined(with: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewSize = geo.size
                recalculate(animated: false)
            }
            .onChange(of: geo.size) { _, new in
                viewSize = new
                recalculate(animated: false)
            }
            .onChange(of: nodes.count) { _, _ in
                recalculate(animated: true)
            }
        }
    }

    @ViewBuilder
    private func bubbleCell(_ bubble: BubbleLayout) -> some View {
        let tappable = onTap != nil
        Button {
            if let onTap, let node = nodes.first(where: { $0.id == bubble.id }) {
                onTap(node)
            }
        } label: {
            ZStack {
                Circle()
                    .fill(bubble.color.gradient)
                    .overlay(Circle().strokeBorder(bubble.color.opacity(0.35), lineWidth: 1.5))

                if bubble.radius > 26 {
                    VStack(spacing: 3) {
                        Text(bubble.name)
                            .font(.system(size: fontSize(bubble.radius, scale: 0.20, max: 13), weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .minimumScaleFactor(0.6)

                        if bubble.radius > 42 {
                            Text(ByteCountFormatter.string(fromByteCount: bubble.size, countStyle: .file))
                                .font(.system(size: fontSize(bubble.radius, scale: 0.14, max: 11)))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    .padding(bubble.radius * 0.18)
                }
            }
            .frame(width: bubble.radius * 2, height: bubble.radius * 2)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!tappable)
        .onHover { inside in
            if tappable {
                if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
    }

    private func fontSize(_ radius: CGFloat, scale: CGFloat, max: CGFloat) -> CGFloat {
        Swift.min(radius * scale, max)
    }

    // MARK: - Layout

    private func recalculate(animated: Bool) {
        guard viewSize.width > 0, !nodes.isEmpty else { return }

        let sorted = nodes.sorted { $0.size > $1.size }
        let maxSize = max(1, sorted.first?.size ?? 1)
        let maxRadius = min(viewSize.width, viewSize.height) * 0.22
        let minRadius: CGFloat = 22

        var newLayout: [BubbleLayout] = sorted.enumerated().map { i, node in
            let ratio = sqrt(Double(node.size) / Double(maxSize))
            let radius = max(minRadius, maxRadius * CGFloat(ratio))
            return BubbleLayout(
                id: node.id,
                name: node.name,
                size: node.size,
                radius: radius,
                position: CGPoint(x: viewSize.width / 2, y: viewSize.height / 2),
                color: palette[i % palette.count]
            )
        }

        let positions = packCircles(radii: newLayout.map(\.radius), in: viewSize)
        for i in newLayout.indices { newLayout[i].position = positions[i] }

        if animated {
            withAnimation(.spring(response: 0.48, dampingFraction: 0.72)) {
                layout = newLayout
            }
        } else {
            layout = newLayout
        }
    }

    /// Greedy packing: places each circle tangent to an existing one,
    /// choosing the position closest to center with no overlaps.
    private func packCircles(radii: [CGFloat], in size: CGSize) -> [CGPoint] {
        guard !radii.isEmpty else { return [] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        var positions: [CGPoint] = [center]
        let gap: CGFloat = 5

        for i in 1..<radii.count {
            let r = radii[i]
            var bestPos = center
            var bestDist = CGFloat.infinity
            var placed = false

            for j in 0..<i {
                let jc = positions[j]
                let tangent = r + radii[j] + gap

                var deg: CGFloat = 0
                while deg < 360 {
                    let angle = deg * .pi / 180
                    let cx = jc.x + tangent * cos(angle)
                    let cy = jc.y + tangent * sin(angle)

                    guard cx - r >= gap, cx + r <= size.width - gap,
                          cy - r >= gap, cy + r <= size.height - gap else {
                        deg += 10; continue
                    }

                    let candidate = CGPoint(x: cx, y: cy)
                    var overlaps = false
                    for k in 0..<i where hypot(candidate.x - positions[k].x,
                                               candidate.y - positions[k].y) < r + radii[k] + gap {
                        overlaps = true; break
                    }

                    if !overlaps {
                        let d = hypot(cx - center.x, cy - center.y)
                        if d < bestDist { bestDist = d; bestPos = candidate; placed = true }
                    }
                    deg += 10
                }
            }

            positions.append(placed ? bestPos : center)
        }

        return positions
    }
}
