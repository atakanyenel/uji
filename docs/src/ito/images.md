# Images

`ito.Image` shows a picture. `ito.ImageViewer` adds keyboard and optional
wheel controls for zooming and panning it. Both take the same
[modifiers](modifiers.md) as every other view and work inside stacks, grids,
scroll views, overlays and `ito.view` functions of your own.

This page is about drawing a picture. Preparing one to send to a model is
[the runtime image helpers](../runtime/images.md).

## Turning graphics on

The screen asks for a graphics protocol, and it starts `off`:

```lua
screen:configure_images({ protocol = "kitty" })
```

`kitty` asserts that the terminal supports Kitty **Unicode placeholders**,
which arrived in Kitty 0.28: plain Kitty graphics support is not enough. The
image id travels in the cell's foreground colour, so graphics also need a
truecolor terminal. Nothing inspects stdin or probes the terminal, so a
terminal that does not support them shows the fallback without ever receiving
graphics commands.

uji owns the screen it draws on, so whether graphics are on is uji's call;
while they are off, an image draws its text or [fallback](#loading-and-fallback-views).

Cell dimensions come from the terminal's window-size ioctl when it answers, and
8 × 16 pixels otherwise. A host that knows them supplies both:

```lua
screen:configure_images({
  protocol = "kitty",
  cell_width = 10,
  cell_height = 20,
  tmux = false,
})
```

Explicit dimensions stay fixed until they are set again. Measured ones are
re-read whenever the screen size is read, including after a font change.
Supplying one of the two without the other is an error.
`screen:image_capabilities()` returns the configured protocol, the cell
dimensions, whether they are measured (`auto`) and the tmux setting. It is not
a probe result.

`tmux = true` wraps each graphics command in tmux passthrough sequences, which
the tmux the user runs has to allow. SSH needs nothing shared with the
terminal: image bytes travel inside the escape codes.

## Sources

```lua
local photo = ito.ImageSource.file("photo.jpg")
local uploaded = ito.ImageSource.bytes(png_or_jpeg_bytes)
local pixels = ito.ImageSource.rgba(width, height, rgba_bytes)
```

Files and encoded bytes load in the background. Only still PNG and JPEG are
decoded; an EXIF orientation is applied before any crop. Raw RGBA data must
hold exactly `width * height * 4` bytes. A source never changes and can be
shown by several views; asking for a file again makes a new source that reads
it again.

`source:status()` answers `{ phase = "loading" }`,
`{ phase = "ready", width = ..., height = ... }` or
`{ phase = "failed", error = ... }`, with the dimensions in pixels after the
EXIF orientation.

Keep sources outside functions that are composed often, or remember them by
their arguments:

```lua
local Photo = ito.view(function(props)
  local source = ito.remember(function()
    return ito.ImageSource.file(props.path)
  end, props.path)
  return ito.Image(source):alt(props.description)
end)
```

Fetching a URL, saving, copying and opening another application are yours to
arrange: pass callbacks in through props and `:on_tap(handler)`.

## Presentation and placement

```lua
ito.Image(photo)
  :content_mode(ito.ImageMode.fill)
  :content_alignment(ito.Alignment.top)
  :crop({ x = 100, y = 50, width = 400, height = 300 })
  :rotate(90)
  :opacity(0.8)
  :sampling(ito.ImageSampling.linear)
  :width(40)
  :height(12)
  :align(ito.Alignment.leading)
  :padding(1)
```

| Setting | Effect |
|---|---|
| `ImageMode.fit` | Default. Keeps the proportions and shows the whole image, with transparent space left over. |
| `ImageMode.fill` | Keeps the proportions and crops to fill the rectangle. |
| `ImageMode.stretch` | Fills the rectangle without keeping the proportions. |
| `ImageMode.original` | One source pixel per terminal pixel, clipped to the rectangle. |
| `content_alignment` | Places the image in its rectangle, including which edge stays visible when it is cropped. |
| `crop` | A rectangle inside the oriented source, in pixels. `nil` removes it. |
| `rotate` | Clockwise multiples of 90 degrees, applied after the crop. |
| `opacity` | A number from 0 to 1, multiplied into the source alpha. |
| `ImageSampling.linear` | Default. Bilinear interpolation with premultiplied alpha. |
| `ImageSampling.nearest` | Keeps hard pixel edges, for pixel art. |

`width`, `height`, `padding` and layout positions count cells. `align` moves
the view inside its parent; `content_alignment` moves the pixels inside the
view. The cell proportions are part of how an image measures its own height,
and explicit dimensions keep the space stable while the image loads.

A transform belongs to the view and never changes the source, so one source
can be a cropped thumbnail in one place and a full preview in another.
Identical prepared images share one upload. Scrolling clips the original
rectangle and keeps its image coordinates, rather than fitting the visible
fragment again.

Image cells replace the text cells under them, and later text or an opaque
overlay covers them again. Text styling cannot overwrite the colours that
carry image identity. Text selection, `screen:text`, styled snapshots and
virtual-terminal frames hold spaces where image cells are, never protocol
characters. Copying the pixels of an image is something the application
arranges.

## Loading and fallback views

```lua
ito.Image(photo)
  :height(12)
  :alt("Mountain at sunset")
  :placeholder(ito.Text("Loading image…"))
  :fallback(function(status)
    return ito.Text("Could not load image")
  end)
  :unsupported(ito.Text("Image preview unavailable"))
```

Each of the three takes a view or a function returning one. The function
receives `{ phase, error, source }`. Loading covers decoding and preparing the
current size and transform. `fallback` handles failures, and is used for a
terminal without graphics when no `unsupported` view is given. The default in
every phase is the alt text, which starts as `Image`.

Changing a transform keeps the previous ready image on screen until the
replacement is prepared, as long as the source and the rectangle size stay the
same and the previous variant is still cached. Changing the source shows the
loading view, so unrelated pixels are never left behind.

A visible image that is still loading asks for the next frame through
`frame.wake`, the same deadline `ito.Spinner` uses, and the host honours it.
Decoding and encoding happen on a worker; terminal writes stay in frame order.

## Interactive viewer

```lua
local viewport = ito.ImageViewport()

ito.ImageViewer(photo)
  :state(viewport)
  :focused()
  :content_mode(ito.ImageMode.fit)
  :wheel(ito.ImageWheel.zoom)
  :on_change(function(state)
    -- Update application controls or labels.
  end)
  :grow()
```

Without `state`, the viewer keeps its own viewport between frames. A viewport
you supply can be shared by several viewers or driven from a toolbar:

```lua
viewport:zoom_to(2)
viewport:zoom_by(1.25)
viewport:pan_to(0, 0.5)
viewport:pan_by(0.1, 0)
viewport:reset()
```

Zoom is relative to the selected content mode and is clamped to 0.1–64. Pan
coordinates run from -1 to 1 and shift the alignment across the difference
between the image and the viewport, so zero leaves `content_alignment` as it
is and positive values move the viewed region right or down for an overflowing
image. Read `zoom`, `x` and `y` for toolbar labels. As with
[`ito.ScrollState`](controls.md#itoscrollstateopts), a change made outside the
viewer needs the host to draw again.

| Input | Action |
|---|---|
| `+` or `=` | Zoom in |
| `-` | Zoom out |
| Arrow keys | Pan |
| `0` or Home | Reset zoom and pan |

Ctrl, Alt and Meta combinations are left to you. `ImageWheel.pass` is the
default and leaves the wheel to the scrolling container; `ImageWheel.zoom` and
`ImageWheel.pan` take it inside the visible viewer. Dragging the mouse still
selects text.

## Bounds and lifecycle

- Encoded input: at most 16 MiB. Source dimensions: at most 8192 per side and
  16 megapixels in total.
- Each prepared placement: at most 4 megapixels and 297 cells per axis, the
  limit of the placeholder coordinate table.
- A screen caches at most 64 prepared variants within a 64 MiB budget, and
  evicts the offscreen ones first. A source the application keeps has its own
  lifetime.
- One worker and eight queued jobs bound the work in flight. A full queue
  defers a placement to a later frame or status check, and work whose result
  nobody waits for any more is skipped.
- Uploads are made from the cells that are left after composing, so a covered
  image is never uploaded. Every cell carries its own image coordinates, so
  clipping and overlays do not depend on neighbouring placeholders.
- Commands carry the bytes directly, in payload chunks of at most 4096 base64
  bytes, and ask for no reply from the terminal.
- Suspending, closing, reclaiming the screen and evicting a variant delete only
  the image ids ito owns. Resuming, and a write that fails, mark the images for
  upload again.

The implementation follows the [Kitty graphics protocol](https://sw.kovidgoyal.net/kitty/graphics-protocol/),
including its published Unicode coordinate table. Whether a terminal supports
Unicode placeholders, and whether tmux passes them through, is worth checking
in each terminal an application supports.
