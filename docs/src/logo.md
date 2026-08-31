# Logo

The Mera logo, for talks, posters, teaching material and anything else you want to use it in.
Please take it from here rather than screenshotting it from a page.

```@raw html
<div style="display:flex;flex-wrap:wrap;gap:14px;margin:22px 0">
  <div style="background:#000;padding:22px 26px;border-radius:8px">
    <img src="assets/logo.svg" width="300" alt="Mera logo on black">
  </div>
  <div style="background:#fff;padding:22px 26px;border-radius:8px;border:1px solid #d0d7de">
    <img src="assets/logo.svg" width="300" alt="Mera logo on white">
  </div>
  <div style="background:#5a5f66;padding:22px 26px;border-radius:8px">
    <img src="assets/logo.svg" width="300" alt="Mera logo on grey">
  </div>
  <div style="background:linear-gradient(120deg,#2b6cb0,#805ad5,#dd6b20);padding:22px 26px;border-radius:8px">
    <img src="assets/logo.svg" width="300" alt="Mera logo on a photographic background">
  </div>
</div>
```

There is one file for every background. The letters carry a thin dark outline, so the logo keeps
its edges on black, on white, on a mid grey and on top of an image, without needing a light and a
dark version.

## Download

```@raw html
<table>
<thead><tr><th>File</th><th>Format</th><th>Use it for</th></tr></thead>
<tbody>
<tr><td><a href="assets/logo.svg" download>mera-logo.svg</a></td>
    <td>SVG, 14 KB</td>
    <td><b>Prefer this.</b> Vector, so it stays sharp at any size, from a slide title to a poster.</td></tr>
<tr><td><a href="assets/logo/mera-logo-512.png" download>mera-logo-512.png</a></td>
    <td>PNG, 512 px wide</td><td>Slides, README badges, anything on screen.</td></tr>
<tr><td><a href="assets/logo/mera-logo-1024.png" download>mera-logo-1024.png</a></td>
    <td>PNG, 1024 px wide</td><td>Full-width slide, or a figure in a paper.</td></tr>
<tr><td><a href="assets/logo/mera-logo-2048.png" download>mera-logo-2048.png</a></td>
    <td>PNG, 2048 px wide</td><td>Print and posters.</td></tr>
</tbody>
</table>
```

Every file has a **transparent background**, so it takes on whatever is behind it.

Use the SVG wherever the tool accepts one: LaTeX with `\includegraphics`, Inkscape, Figma, the web.
Keynote and PowerPoint handle SVG unevenly, so the PNGs are there for those.

## Using it

The logo is part of Mera, which is MIT licensed, so you are free to use it when writing or talking
about the package. Two requests, both ordinary courtesy rather than legal terms:

- Keep the proportions and the colours as they are, and leave clear space around it.
- Do not use it as the logo of your own project, or in a way that suggests Mera endorses something.

If you need a variant that is not here, a single flat colour for a monochrome print, a square
version for a social avatar, or a different aspect ratio, open an
[issue](https://github.com/ManuelBehrendt/Mera.jl/issues) and it can be added.

If Mera contributed to a piece of work, a citation helps more than a logo does: see
[Citation](index.md#Citation-and-license) on the home page.
