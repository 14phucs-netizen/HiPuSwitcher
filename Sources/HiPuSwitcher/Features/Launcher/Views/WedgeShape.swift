import SwiftUI

// MARK: - Rounded Wedge Shape
public struct WedgeShape: Shape {
    public var startAngle: Angle
    public var endAngle: Angle
    public var innerRadius: CGFloat
    public var outerRadius: CGFloat
    public var cornerRadius: CGFloat = 10

    public init(startAngle: Angle, endAngle: Angle, innerRadius: CGFloat, outerRadius: CGFloat, cornerRadius: CGFloat = 10) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.cornerRadius = cornerRadius
    }

    public func path(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let s  = CGFloat(startAngle.radians)
        let e  = CGFloat(endAngle.radians)
        
        let safeInner = max(1.0, innerRadius)
        
        // Clamp corner radius so it never exceeds wedge geometry.
        // We must base the angular clamp on safeInner because the inner arc is shorter than the outer arc,
        // making the inner arc the limiting factor for corner radius without crossing over.
        let r  = min(cornerRadius,
                     (outerRadius - safeInner) / 2.2,
                     safeInner * CGFloat(abs(endAngle.radians - startAngle.radians)) / 4)

        let oS = CGPoint(x: cx + outerRadius * cos(s), y: cy + outerRadius * sin(s))
        let oE = CGPoint(x: cx + outerRadius * cos(e), y: cy + outerRadius * sin(e))
        let iE = CGPoint(x: cx + safeInner * cos(e), y: cy + safeInner * sin(e))
        let iS = CGPoint(x: cx + safeInner * cos(s), y: cy + safeInner * sin(s))

        let od = Double(r / outerRadius)  // angle offset for outer arc
        let id = Double(r / safeInner)    // angle offset for inner arc

        // Points just past each corner on the arcs (for tangent2End in addArc)
        let oS_next = CGPoint(x: cx + outerRadius * cos(s + CGFloat(od)),
                              y: cy + outerRadius * sin(s + CGFloat(od)))
        let iE_next = CGPoint(x: cx + safeInner * cos(e - CGFloat(id)),
                              y: cy + safeInner * sin(e - CGFloat(id)))

        var path = Path()
        // Start on start-radial, r inside outerStart
        path.move(to: CGPoint(x: cx + (outerRadius - r) * cos(s),
                              y: cy + (outerRadius - r) * sin(s)))

        // Corner 1 — outerStart: going outward → outer arc toward endAngle
        path.addArc(tangent1End: oS, tangent2End: oS_next, radius: r)

        // Outer arc (skip corner zones)
        path.addArc(center: CGPoint(x: cx, y: cy), radius: outerRadius,
                    startAngle: .radians(Double(s) + od),
                    endAngle:   .radians(Double(e) - od), clockwise: false)

        // Corner 2 — outerEnd: outer arc → end-radial going INWARD toward iE
        path.addArc(tangent1End: oE, tangent2End: iE, radius: r)

        // End-radial line down to near innerEnd
        path.addLine(to: CGPoint(x: cx + (safeInner + r) * cos(e),
                                 y: cy + (safeInner + r) * sin(e)))

        // Corner 3 — innerEnd: end-radial → inner arc going back toward startAngle
        path.addArc(tangent1End: iE, tangent2End: iE_next, radius: r)

        // Inner arc backward (CW)
        path.addArc(center: CGPoint(x: cx, y: cy), radius: safeInner,
                    startAngle: .radians(Double(e) - id),
                    endAngle:   .radians(Double(s) + id), clockwise: true)

        // Corner 4 — innerStart: inner arc → start-radial going OUTWARD toward oS
        path.addArc(tangent1End: iS, tangent2End: oS, radius: r)

        path.closeSubpath()
        return path
    }
}
