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
    <div class="mera-logo-shot mera-logo-shot-black" role="img" aria-label="Mera logo on a light page"></div>
  </div>
  <div style="background:#0d1117;padding:20px;border-radius:8px">
    <div class="mera-logo-shot mera-logo-shot-black" role="img" aria-label="Mera logo on a dark page"></div>
  </div>
</div>
```

```@raw html
<div class="logo-downloads">
```

| File | Format | Use it for |
|:---|:---|:---|
| [mera-logo-black.svg](assets/logo/mera-logo-black.svg) | SVG, 13 KB | **Prefer this.** Vector, sharp at any size, from a slide title to a conference poster. |
| [mera-logo-black-512.png](assets/logo/mera-logo-black-512.png) | PNG, 512 px | Slides and anything on screen. |
| [mera-logo-black-1024.png](assets/logo/mera-logo-black-1024.png) | PNG, 1024 px | A full-width slide, or a figure in a paper. |
| [mera-logo-black-2048.png](assets/logo/mera-logo-black-2048.png) | PNG, 2048 px | Print and posters. |

```@raw html
</div>
```

## Transparent

The letters carry a thin dark outline, so this version keeps its edges on white, on grey and on top
of an image, without a background of its own.

```@raw html
<div style="display:flex;flex-wrap:wrap;gap:14px;margin:20px 0">
  <div style="background:#fff;padding:20px;border-radius:8px;border:1px solid #d0d7de">
    <div class="mera-logo-shot mera-logo-shot-transparent" role="img" aria-label="Mera logo on white"></div>
  </div>
  <div style="background:#5a5f66;padding:20px;border-radius:8px">
    <div class="mera-logo-shot mera-logo-shot-transparent" role="img" aria-label="Mera logo on grey"></div>
  </div>
  <div style="background:linear-gradient(120deg,#2b6cb0,#805ad5,#dd6b20);padding:20px;border-radius:8px">
    <div class="mera-logo-shot mera-logo-shot-transparent" role="img" aria-label="Mera logo over an image"></div>
  </div>
</div>
```

```@raw html
<div class="logo-downloads">
```

| File | Format | Use it for |
|:---|:---|:---|
| [mera-logo-transparent.svg](assets/logo/mera-logo-transparent.svg) | SVG, 13 KB | Over a photograph, or wherever a black block would clash. |
| [mera-logo-transparent-512.png](assets/logo/mera-logo-transparent-512.png) | PNG, 512 px | Screen use. |
| [mera-logo-transparent-1024.png](assets/logo/mera-logo-transparent-1024.png) | PNG, 1024 px | Slides and figures. |
| [mera-logo-transparent-2048.png](assets/logo/mera-logo-transparent-2048.png) | PNG, 2048 px | Print and posters. |

```@raw html
</div>
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
[Citation](index.md#Citation) on the home page.
