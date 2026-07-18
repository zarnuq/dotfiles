import QtQuick

// Rolling time-series line, analog of eww's (graph ...) widget.
// Push a new value -> ring buffer -> repaint. maxSamples*interval = time window.
Canvas {
    id: g

    property real value: 0
    property color lineColor: "white"
    property real thickness: 2
    property int maxSamples: 30   // 30 samples * 2s = 60s window (eww GRAPH-RANGE "60s")
    property real minv: 0
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
            var norm = (samples[i] - minv) / (maxv - minv);
            var y = height - norm * height;
            if (i === 0)
                ctx.moveTo(x, y);
            else
                ctx.lineTo(x, y);
        }
        ctx.stroke();
    }
}
