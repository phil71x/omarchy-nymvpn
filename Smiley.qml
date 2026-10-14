pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes

// Nym's smiley (disc, capsule eyes, wide smile) on a 28-unit grid, scaled to `size`.
Item {
  id: face

  property real size: 18
  property color featureColor: "white"
  property color discColor: "black"
  property color rimColor: "grey"
  readonly property real k: size / 28

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

  Repeater {
    model: [10.5, 17.5]

    Rectangle {
      required property real modelData
      width: 3.5 * face.k
      height: 7.5 * face.k
      radius: width / 2
      x: modelData * face.k - width / 2
      y: 10.5 * face.k - height / 2
      color: face.featureColor
      Behavior on color { ColorAnimation { duration: 160 } }
    }
  }

  Shape {
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeColor: face.featureColor
      strokeWidth: 2.2 * face.k
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      Behavior on strokeColor { ColorAnimation { duration: 160 } }

      PathAngleArc {
        centerX: 14 * face.k
        centerY: 13 * face.k
        radiusX: 9.5 * face.k
        radiusY: 9.5 * face.k
        startAngle: 15
        sweepAngle: 150
      }
    }
  }
}
