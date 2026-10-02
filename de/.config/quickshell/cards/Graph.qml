pragma ComponentBehavior: Bound
import QtQuick
import ".."   // Theme, Config, Txt, Poll and the root singletons

// Rolling time-series line, analog of eww's (graph ...) widget.
// Push a new value -> ring buffer -> repaint. maxSamples*interval = time window.
//
// Always overlaid: a card stacks several of these over one plot area, so each
// fills its parent by default rather than every instance saying so.
Canvas {
    id: root

    anchors.fill: parent

    property real value: 0
    property color lineColor: Theme.text
    property real thickness: Config.s(2)
    property int maxSamples: 30   // 30 samples * 2s = 60s window (eww GRAPH-RANGE "60s")
    property real maxv: 100
    property var samples: []

    onValueChanged: {
        samples.push(value);
        while (samples.length > maxSamples)
            samples.shift();
        requestPaint();
    }

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        if (samples.length < 2)
            return;
        ctx.lineWidth = thickness;
        ctx.strokeStyle = lineColor;
        ctx.lineJoin = "round";      // eww :line-style "round"
        ctx.lineCap = "round";
        ctx.beginPath();
        for (var i = 0; i < samples.length; i++) {
            var x = width * i / (maxSamples - 1);
            var y = height - samples[i] / maxv * height;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
