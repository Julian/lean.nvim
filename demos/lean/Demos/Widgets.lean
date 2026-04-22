-- Widgets: inline images and SVGs rendered directly in the infoview.
-- Place your cursor on `#html` below and watch the infoview.
-- Requires a terminal with Kitty graphics protocol support
-- (Kitty, WezTerm, Ghostty, ...) and `resvg` for SVG rasterization.

import ProofWidgets.Component.RefreshComponent
import ProofWidgets.Component.HtmlDisplay

open Lean Server Widget ProofWidgets Jsx

private def pi : Float := 3.14159265358979

private def fmod (a b : Float) : Float :=
  a - (a / b).floor * b

/-- Build the SVG for a single frame, given accumulated points and a hue offset. -/
private def frame (points : Array (Float × Float)) (hueOffset : Float) : Html :=
  let n := points.size
  let segments : Array Html := Id.run do
    let mut segs : Array Html := #[]
    for i in List.range (n - 1) do
      let (x1, y1) := points[i]!
      let (x2, y2) := points[i + 1]!
      let hue := fmod (hueOffset + i.toFloat / n.toFloat * 360) 360
      segs := segs.push <| Html.element "line"
        #[("x1", s!"{x1}"), ("y1", s!"{y1}"),
          ("x2", s!"{x2}"), ("y2", s!"{y2}"),
          ("stroke", s!"hsl({hue}, 85%, 60%)"),
          ("stroke-width", "2"),
          ("stroke-linecap", "round")]
        #[]
    return segs
  Html.element "svg"
    #[("xmlns", "http://www.w3.org/2000/svg"),
      ("width", "400"), ("height", "400"),
      ("viewBox", "0 0 400 400")]
    segments

/-- An animated spirograph (hypotrochoid) drawn progressively, then color-cycled.

`R` and `r` are the radii of the fixed and rolling circles; `d` is the pen
offset.  The ratio R/r = 5/3 gives a classic five-petalled rose. -/
partial def spirograph : CoreM Html := do
  let R : Float := 5
  let r : Float := 3
  let d : Float := 5
  let scale : Float := 18
  let cx : Float := 200
  let cy : Float := 200
  let totalSteps : Nat := 300
  let period : Float := 2 * pi * 3  -- lcm(R,r) / gcd(R,r) full turns

  mkRefreshComponentM (.text "⏳") fun token => do
    -- Phase 1: progressively trace the curve
    let mut points : Array (Float × Float) := #[]
    for step in List.range totalSteps do
      IO.sleep 33
      Core.checkSystem "spirograph"
      let t := step.toFloat / totalSteps.toFloat * period
      let x := (R - r) * t.cos + d * ((R - r) / r * t).cos
      let y := (R - r) * t.sin - d * ((R - r) / r * t).sin
      points := points.push (cx + x * scale, cy + y * scale)
      if points.size > 1 then
        token.update (frame points 270)

    -- Phase 2: cycle the rainbow across the completed curve
    let mut hueOffset : Float := 0
    repeat do
      IO.sleep 50
      Core.checkSystem "spirograph"
      hueOffset := hueOffset + 3
      token.update (frame points hueOffset)

-- Place your cursor here:
#html spirograph
