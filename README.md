Dots Canvas
============

a custom element with Polymer.dart.

Sample
-------

In your html:

```html
<body bgcolor="#ccc">
  <dots-canvas verticalDots="10" horizontalDots="10" dotSize="50">
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
  </dots-canvas>
</body>
```

then it will be renderd like:

![the sample of screenshot](img/screenshot1.png)
