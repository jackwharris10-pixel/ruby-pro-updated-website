# Ruby Pro Website

Marketing site for Ruby Pro Software — ERP and pricing tools for wine & spirits distributors.

## Stack
Static HTML + Bootstrap 5, hosted on Azure Static Web Apps. No build step — edit and push.

## Live URL
https://www.rubyprosoftware.com

## Directory Structure
```
index.html                      # Homepage
route-accounting/index.html     # ERP product page (for distributors)
route-accounting/state/index.html # Dynamic state landing pages (/route-accounting/state/ny)
pricing/index.html              # Pricing product page (for suppliers)
pricing/free-template.html      # Free template lead-gen page
pricing/thank-you.html          # Post-form thank you
contact-us.html                 # Contact form
thank-you.html                  # Post-contact thank you
privacy-policy.html             # Legal
terms-of-service.html           # Legal
404.html                        # Custom 404
sitemap.xml / robots.txt        # SEO

assets/
  bootstrap/css/bootstrap.min.css   # Bootstrap 5 (do not edit)
  bootstrap/js/bootstrap.min.js
  css/rubypro.css                   # Custom CSS vars + overrides (brand color: #681D15)
  css/rubypro.compiled.css          # Additional compiled styles
  css/bss-overrides.css             # Bootstrap Studio overrides
  js/states.js                      # Dynamic state page logic (loads JSON, renders content)
  js/{state}.json                   # Per-state content (ca.json, ny.json, etc.)
  js/default.json                   # Fallback content for unknown states
  js/routes.json                    # Azure SWA routing rules (rewrites + redirects)
  js/state_map.json                 # State metadata for map
  js/smart-forms.min.js             # Form handling
  img/                              # Images (logo, hero banners)

.github/workflows/azure-static-web-apps-*.yml  # CI/CD — auto-deploys on push to main
```

## How It Works
- **State landing pages:** `/route-accounting/state/{abbrev}` all rewrite to `state/index.html`. `states.js` reads the URL, fetches `assets/js/{state}.json`, and renders state-specific content.
- **Routing:** `assets/js/routes.json` defines Azure SWA routes. `/ny` redirects to `/route-accounting/state/ny`.
- **Analytics:** Google Analytics (G-LC32W6VK7M) + Apollo.io tracker on every page.
- **SEO:** JSON-LD structured data on main pages (Organization, SoftwareApplication schemas).

## Run Locally
```bash
python3 -m http.server 8080  # then open http://localhost:8080
```

## Conventions
- Brand primary color: `#681D15` (dark ruby red). Secondary: `#E5877D`.
- Fonts: Catamaran (headings) + Lato (body) via Google Fonts.
- Every page includes: Apollo tracker, GA tag, navbar, footer.
- Nav links: Home, Distributors (/route-accounting), Suppliers (/pricing), Contact Us.
- All pages use Bootstrap 5 classes. Custom styles go in `rubypro.css`.

## Common Tasks
- **Add a new state landing page:** Create `assets/js/{state}.json` following the existing pattern (see `ny.json`). The state page template auto-loads it.
- **Edit page content:** Directly edit the HTML file. No build needed.
- **Change styling:** Edit `assets/css/rubypro.css` for brand overrides, or inline styles for one-off changes.
- **Add a new page:** Create HTML file, copy navbar/footer from an existing page, add analytics snippets.
- **Update routing:** Edit `assets/js/routes.json` for redirects/rewrites.

## Deployment
Push to `main` branch. GitHub Actions auto-deploys to Azure Static Web Apps.
