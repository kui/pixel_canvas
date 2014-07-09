Pixel Canvas
==============

A custom element with Polymer.dart.

Example Usage
--------------

In your html:

```html
<body bgcolor="#ccc">
  <pixel-canvas verticalPixels="10" horizontalPixels="10" pixelSize="50">
    [
      ["green"],
      ["red", null, "blue"],
      ["rgb(255, 128, 128)", "rgb(128, 255, 128)", "rgb(128, 128, 255)"],
      [null, null, "#f00", "#333", "#ffffff", "#abab00"],
      null,
      [],
      ["", ""],
      ["rgba(0, 255, 255, 0.2)",
       "rgba(0, 255, 255, 0.4)",
       "rgba(0, 255, 255, 0.6)",
       "rgba(0, 255, 255, 0.8)",
       "rgba(0, 255, 255, 1.0)"]
    ]
  </pixel-canvas>
</body>
```

then it will be renderd like:

![the sample of screenshot](https://raw.githubusercontent.com/kui/pixel_canvas/master/img/screenshot1.png)


You can see [other samples](https://github.com/kui/dots_canvas/tree/master/example/web)

Run Sample
-------------

In your terminal:

```bash
pub serve
```

then browse <http://localhost:8080/>
