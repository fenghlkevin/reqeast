// Original RHEQ geometric mark. Coordinates also live in scripts/generate_rheq_brand.py.
import SwiftUI

struct RheqLogoShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        let origin = CGPoint(x: rect.midX - scale * 50, y: rect.midY - scale * 50)
        let outlines: [[CGPoint]] = [
            [.init(x: 8, y: 8), .init(x: 58, y: 8), .init(x: 58, y: 26),
             .init(x: 26, y: 26), .init(x: 26, y: 66), .init(x: 8, y: 66)],
            [.init(x: 58, y: 26), .init(x: 80, y: 26), .init(x: 94, y: 40),
             .init(x: 94, y: 78), .init(x: 76, y: 78), .init(x: 76, y: 46), .init(x: 58, y: 46)],
            [.init(x: 40, y: 66), .init(x: 56, y: 66), .init(x: 90, y: 100),
             .init(x: 64, y: 100), .init(x: 40, y: 76)]
        ]
        var path = Path()
        for outline in outlines {
            for (index, point) in outline.enumerated() {
                let position = CGPoint(x: origin.x + point.x * scale, y: origin.y + point.y * scale)
                if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
            }
            path.closeSubpath()
        }
        return path
    }
}
