# canvas-backend-svg

Deterministic, accessible inline SVG for the [canvas-protocol](https://github.com/egao1980/canvas-protocol) chart model (slice H4h-1). Pure Lisp: no JS, no CFFI.

```lisp
(asdf:load-system "canvas-backend-svg")   ; registers itself as canvas:*chart-backend*
(canvas:to-html
 (canvas:make-chart :line :title "Temps"
                    :series (list (canvas:make-series "a" '((0 . 0) (5 . 10) (10 . 5))))))
;; => "<figure data-chart=\"line\"><svg id=\"chart-temps\" viewBox=\"0 0 640 360\" role=\"img\" …"
```

- All four kinds: `:line`, `:bar` (grouped, categorical), `:scatter`, `:histogram` (equal-width bins).
- Scales: linear with Heckbert nice ticks (`nice-ticks`), base-10 log (`log-ticks`), time on calendar units in UTC (`time-ticks`, via datetime-protocol).
- Byte-deterministic output: exact rational arithmetic, integer coordinates, and fixed label formatting (`format-tick`, `format-number`).
- Accessible: `role="img"`, `aria-labelledby` pointing at `<title>` and `<desc>`, and a `<title>` tooltip on every mark.
- Themeable: no colour literals. Marks use `currentColor` and each series carries `data-series="n"`. `palette-css` gives the Okabe–Ito rules a theme includes.
- CSP-clean (`canvas:csp-violations` is empty) and survives `canvas:freeze`.

Design: [cl-stack/docs/capabilities/canvas.md § H4h-1](https://github.com/egao1980/cl-stack/blob/main/docs/capabilities/canvas.md). The rules live in the header comments of `src/*.lisp`.

## License

MIT — see [LICENSE](LICENSE).
