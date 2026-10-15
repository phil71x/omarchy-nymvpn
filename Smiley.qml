pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Nym's smiley (disc, oval eyes, wide smile with a crossbar at each tip) on a 28-unit grid,
// scaled to `size`. Eyes and smile traced from the smiley in the Nym docs
// (nym.com/docs/_next/static/media/smiley.7d68337f.png, 862 px wide).
Item {
  id: face

  property real size: 18
  property color featureColor: "white"
  property color discColor: "black"
  property color rimColor: "grey"
  readonly property real k: size / 28
  // The traced stroke (0.85 unit) vanishes at bar size, so it never goes below 1.4 px.
  readonly property real stroke: Math.max(0.85 * k, 1.4)

  implicitWidth: size
  implicitHeight: size
  width: size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: width / 2
    color: face.discColor
    border.color: face.rimColor
    border.width: 1
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    // Eyes: filled ellipses.
    Eye { cx: 10.12 }
    Eye { cx: 17.85 }

    // Smile: a near half circle ending in two short crossbars, outer ends lower.
    ShapePath {
      strokeColor: face.featureColor
      strokeWidth: face.stroke
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      Behavior on strokeColor { ColorAnimation { duration: 160 } }

      PathAngleArc {
        centerX: 14 * face.k
        centerY: 15.3 * face.k
        radiusX: 9.97 * face.k
        radiusY: 9.97 * face.k
        startAngle: 5.2
        sweepAngle: 169.6
      }
      PathMove { x: 3.02 * face.k; y: 16.4 * face.k }
      PathLine { x: 5.26 * face.k; y: 15.98 * face.k }
      PathMove { x: 24.98 * face.k; y: 16.4 * face.k }
      PathLine { x: 22.74 * face.k; y: 15.98 * face.k }
    }
  }

  component Eye: ShapePath {
    id: eye
    property real cx
    strokeColor: "transparent"
    fillColor: face.featureColor
    Behavior on fillColor { ColorAnimation { duration: 160 } }

    PathAngleArc {
      centerX: eye.cx * face.k
      centerY: 9.92 * face.k
      radiusX: 1.625 * face.k
      radiusY: 4.29 * face.k
      startAngle: 0
      sweepAngle: 360
    }
  }
}
