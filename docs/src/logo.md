# Logo

The Mera logo, for talks, posters, teaching material and anything else you want to use it in.
Please take it from here rather than screenshotting it from a page.

There are two versions. The **black card** is the one used on this site and in the README, and it is
the one to reach for by default. The **transparent** version is there for the cases where a card
would not fit: over a photograph, on coloured paper, or inside a layout that already has its own
panel.

## Black card

```@raw html
<div style="display:flex;flex-wrap:wrap;gap:14px;margin:20px 0">
  <div style="background:#fff;padding:20px;border-radius:8px;border:1px solid #d0d7de">
    <img src="assets/logo/mera-logo-black.svg" width="290" alt="Mera logo on a light page">
  </div>
  <div style="background:#0d1117;padding:20px;border-radius:8px">
    <img src="assets/logo/mera-logo-black.svg" width="290" alt="Mera logo on a dark page">
  </div>
</div>
```

```@raw html
<table>
<thead><tr><th>File</th><th>Format</th><th>Use it for</th></tr></thead>
<tbody>
<tr><td><a href="assets/logo/mera-logo-black.svg" download>mera-logo-black.svg</a></td>
    <td>SVG, 13 KB</td>
    <td><b>Prefer this.</b> Vector, sharp at any size, from a slide title to a conference poster.</td></tr>
<tr><td><a href="assets/logo/mera-logo-black-512.png" download>mera-logo-black-512.png</a></td>
    <td>PNG, 512 px</td><td>Slides and anything on screen.</td></tr>
<tr><td><a href="assets/logo/mera-logo-black-1024.png" download>mera-logo-black-1024.png</a></td>
    <td>PNG, 1024 px</td><td>A full-width slide, or a figure in a paper.</td></tr>
<tr><td><a href="assets/logo/mera-logo-black-2048.png" download>mera-logo-black-2048.png</a></td>
    <td>PNG, 2048 px</td><td>Print and posters.</td></tr>
</tbody>
</table>
```

## Transparent

The letters carry a thin dark outline, so this version keeps its edges on white, on grey and on top
of an image, without a background of its own.

```@raw html
<div style="display:flex;flex-wrap:wrap;gap:14px;margin:20px 0">
  <div style="background:#fff;padding:20px;border-radius:8px;border:1px solid #d0d7de">
    <img src="assets/logo/mera-logo-transparent.svg" width="230" alt="Mera logo on white">
  </div>
  <div style="background:#5a5f66;padding:20px;border-radius:8px">
    <img src="assets/logo/mera-logo-transparent.svg" width="230" alt="Mera logo on grey">
  </div>
  <div style="background:linear-gradient(120deg,#2b6cb0,#805ad5,#dd6b20);padding:20px;border-radius:8px">
    <img src="assets/logo/mera-logo-transparent.svg" width="230" alt="Mera logo over an image">
  </div>
</div>
```

```@raw html
<table>
<thead><tr><th>File</th><th>Format</th><th>Use it for</th></tr></thead>
<tbody>
<tr><td><a href="assets/logo/mera-logo-transparent.svg" download>mera-logo-transparent.svg</a></td>
    <td>SVG, 13 KB</td><td>Over a photograph, or wherever a black block would clash.</td></tr>
<tr><td><a href="assets/logo/mera-logo-transparent-512.png" download>mera-logo-transparent-512.png</a></td>
    <td>PNG, 512 px</td><td>Screen use.</td></tr>
<tr><td><a href="assets/logo/mera-logo-transparent-1024.png" download>mera-logo-transparent-1024.png</a></td>
    <td>PNG, 1024 px</td><td>Slides and figures.</td></tr>
<tr><td><a href="assets/logo/mera-logo-transparent-2048.png" download>mera-logo-transparent-2048.png</a></td>
    <td>PNG, 2048 px</td><td>Print and posters.</td></tr>
</tbody>
</table>
```

## Which format

Use the SVG wherever the tool accepts one: LaTeX with `\includegraphics`, Inkscape, Figma, the web.
It is a vector, so it never goes soft, and it is smaller than any of the PNGs. Keynote and
PowerPoint handle SVG unevenly, which is what the PNGs are for.

## Using it

The logo is part of Mera, which is MIT licensed, so you are free to use it when writing or talking
about the package. Two requests, ordinary courtesy rather than legal terms:

- Keep the proportions and the colours as they are, and leave clear space around it.
- Do not use it as the mark of your own project, or in a way that suggests Mera endorses something.

If you need a variant that is not here, a single flat colour for monochrome print, or a square
version for a social avatar, open an
[issue](https://github.com/ManuelBehrendt/Mera.jl/issues) and it can be added.

If Mera contributed to a piece of work, a citation helps far more than a logo does: see
[Citation](index.md#Citation-and-license) on the home page.
