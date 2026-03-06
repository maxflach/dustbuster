import SwiftUI

// MARK: - Layout Engine

struct TreemapRect: Identifiable {
    let id: UUID
    let node: FileSystemNode
    var rect: CGRect
    var color: Color
    var depth: Int
}

enum TreemapLayoutEngine {

    /// Squarified treemap layout. Returns an array of positioned rects.
    static func layout(_ nodes: [FileSystemNode], in bounds: CGRect, depth: Int = 0) -> [TreemapRect] {
        let filtered = nodes.filter { $0.size > 0 }
        guard !filtered.isEmpty, bounds.width > 2, bounds.height > 2 else { return [] }

        let total = Double(filtered.reduce(0) { $0 + $1.size })
        guard total > 0 else { return [] }

        let area = Double(bounds.width) * Double(bounds.height)
        // Scale each node's size to an area proportional to bounds
        let scaled = filtered.map { ($0, Double($0.size) / total * area) }
        let sorted = scaled.sorted { $0.1 > $1.1 }

        var result: [TreemapRect] = []
        squarify(sorted, in: bounds, result: &result, depth: depth)
        return result
    }

    private static func squarify(
        _ items: [(FileSystemNode, Double)],
        in rect: CGRect,
        result: inout [TreemapRect],
        depth: Int
    ) {
        guard !items.isEmpty, rect.width > 1, rect.height > 1 else { return }

        let w = min(rect.width, rect.height)
        var row: [(FileSystemNode, Double)] = []
        var remaining = items

        while !remaining.isEmpty {
            let next = remaining[0]
            let candidate = row + [next]

            if row.isEmpty || worst(candidate, w: Double(w)) <= worst(row, w: Double(w)) {
                row.append(next)
                remaining.removeFirst()
            } else {
                break
            }
        }

        // Layout the row and recurse
        let rowArea = row.reduce(0.0) { $0 + $1.1 }
        let newRect = layoutRow(row, rowArea: rowArea, in: rect, result: &result, depth: depth)
        squarify(remaining, in: newRect, result: &result, depth: depth)
    }

    @discardableResult
    private static func layoutRow(
        _ row: [(FileSystemNode, Double)],
        rowArea: Double,
        in rect: CGRect,
        result: inout [TreemapRect],
        depth: Int
    ) -> CGRect {
        let isHorizontal = rect.width >= rect.height
        let thickness = CGFloat(rowArea) / CGFloat(isHorizontal ? rect.width : rect.height)

        var cursor: CGFloat = 0
        let paletteOffset = depth * 3

        for (i, (node, area)) in row.enumerated() {
            let length = CGFloat(area) / thickness
            let nodeRect: CGRect
            if isHorizontal {
                nodeRect = CGRect(x: rect.minX + cursor, y: rect.minY, width: length, height: thickness)
                cursor += length
            } else {
                nodeRect = CGRect(x: rect.minX, y: rect.minY + cursor, width: thickness, height: length)
                cursor += length
            }

            // Inset slightly for visual separation
            let displayRect = nodeRect.insetBy(dx: 1, dy: 1)
            let color = colorForNode(node, index: (i + paletteOffset))

            result.append(TreemapRect(id: node.id, node: node, rect: displayRect, color: color, depth: depth))
        }

        // Return the remaining rect after this row
        if isHorizontal {
            return CGRect(x: rect.minX, y: rect.minY + thickness,
                          width: rect.width, height: rect.height - thickness)
        } else {
            return CGRect(x: rect.minX + thickness, y: rect.minY,
                          width: rect.width - thickness, height: rect.height)
        }
    }

    private static func worst(_ row: [(FileSystemNode, Double)], w: Double) -> Double {
        guard !row.isEmpty else { return .infinity }
        let areas = row.map { $0.1 }
        let s = areas.reduce(0, +)
        let maxA = areas.max()!
        let minA = areas.min()!
        guard minA > 0 else { return .infinity }
        return max(w * w * maxA / (s * s), s * s / (w * w * minA))
    }

    private static func colorForNode(_ node: FileSystemNode, index: Int) -> Color {
        if node.isDirectory {
            let colors: [Color] = [.blue, .indigo, .cyan, .teal, .mint]
            return colors[index % colors.count].opacity(0.75)
        }
        switch node.fileCategory {
        case .image:    return .green.opacity(0.8)
        case .video:    return .red.opacity(0.8)
        case .audio:    return .purple.opacity(0.8)
        case .document: return .orange.opacity(0.8)
        case .app:      return .teal.opacity(0.8)
        case .archive:  return .gray.opacity(0.8)
        case .code:     return .blue.opacity(0.8)
        case .folder:   return .blue.opacity(0.75)
        case .other:    return .secondary.opacity(0.6)
        }
    }
}

// MARK: - TreemapView

struct TreemapView: View {
    let nodes: [FileSystemNode]
    let onDrillDown: (FileSystemNode) -> Void

    @State private var hoveredID: UUID?
    @State private var layoutRects: [TreemapRect] = []
    @State private var viewSize: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Background
                Color(nsColor: .controlBackgroundColor)

                // Canvas for rectangles
                Canvas { ctx, size in
                    for item in layoutRects {
                        let path = Path(roundedRect: item.rect, cornerRadius: 4)
                        ctx.fill(path, with: .color(item.color))

                        if hoveredID == item.id {
                            ctx.stroke(path, with: .color(.white.opacity(0.8)), lineWidth: 2)
                        }
                    }
                }
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        hoveredID = layoutRects.first { $0.rect.contains(location) }?.id
                    case .ended:
                        hoveredID = nil
                    }
                }
                .onTapGesture { location in
                    if let tapped = layoutRects.first(where: { $0.rect.contains(location) }) {
                        onDrillDown(tapped.node)
                    }
                }

                // Labels overlay (only for large enough rects)
                ForEach(layoutRects) { item in
                    if item.rect.width > 60 && item.rect.height > 30 {
                        labelView(for: item)
                            .position(x: item.rect.midX, y: item.rect.midY)
                    }
                }

                // Tooltip for hovered item
                if let hovered = layoutRects.first(where: { $0.id == hoveredID }) {
                    tooltipView(for: hovered.node)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
            }
            .onChange(of: geo.size) { _, size in
                viewSize = size
                recompute(size: size)
            }
            .onChange(of: nodes.map(\.id)) { _, _ in
                recompute(size: viewSize)
            }
            .onAppear {
                viewSize = geo.size
                recompute(size: geo.size)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func labelView(for item: TreemapRect) -> some View {
        VStack(spacing: 2) {
            Text(item.node.name)
                .font(.system(size: min(11, item.rect.height / 3)))
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(.white)

            if item.rect.height > 50 {
                Text(item.node.formattedSize)
                    .font(.system(size: min(10, item.rect.height / 4)))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .frame(width: item.rect.width - 8, height: item.rect.height - 8)
        .allowsHitTesting(false)
    }

    private func tooltipView(for node: FileSystemNode) -> some View {
        HStack(spacing: 8) {
            Image(systemName: node.isDirectory ? "folder.fill" : "doc.fill")
                .foregroundStyle(.secondary)
            Text(node.name)
                .font(.callout.bold())
            Text("·")
                .foregroundStyle(.secondary)
            Text(node.formattedSize)
                .font(.callout)
                .foregroundStyle(.secondary)
            if node.isDirectory {
                Text("(click to drill in)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 4)
    }

    private func recompute(size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let bounds = CGRect(origin: .zero, size: size)
        layoutRects = TreemapLayoutEngine.layout(nodes, in: bounds)
    }
}
