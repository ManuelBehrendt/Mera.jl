# Privacy

This page explains what happens to your data when you read the Mera.jl documentation.

## Page view counting

The documentation counts page views with [GoatCounter](https://www.goatcounter.com), an open-source
counter made for privacy. It sets no cookies and stores nothing on your device. It stores no IP
address and no personal profile, and it does not follow you across other websites.

For each page view it records:

- the page address and title,
- the referring page, if your browser sends one,
- the browser, operating system and screen size,
- the country, derived from the IP address, which is then discarded.

To avoid counting the same visitor twice, GoatCounter makes a hash of the IP address and browser,
mixed with a random value that changes every few hours. The hash is kept only for those few hours
and cannot be traced back to you. The counts serve one purpose: to
see which pages are read, so the documentation can be improved. They are not shared with anyone.

Counting runs only on the published site, not on a local build. Browser blockers that block
GoatCounter also stop it; nothing on the site depends on it.

## Hosting

The documentation is hosted on [GitHub Pages](https://pages.github.com). Like any web server, GitHub
receives your IP address when you load a page and may log it for security. See the
[GitHub privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement).

## Fonts and scripts

The page layout, fonts, math rendering and search are loaded from
[cdnjs](https://cdnjs.com), a public library service run by Cloudflare. Your browser contacts it to
fetch these files, so Cloudflare receives your IP address. See the
[Cloudflare privacy policy](https://www.cloudflare.com/privacypolicy/).

## Links

Links to other websites, such as GitHub, Zenodo or the Julia website, are plain links. Nothing is
sent to those sites until you click one.

## Contact

Questions about this page: Manuel Behrendt, [manuelbehrendt.com](https://manuelbehrendt.com).
