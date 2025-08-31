# Generate PWA Icons

## SVG to PNG

```bash
inkscape icon.svg --export-filename=output.png --export-width=512 --export-height=512
```

## SVG to favicon

```bash
inkscape logo.svg --export-filename=icon-16.png --export-width=16 --export-height=16
inkscape logo.svg --export-filename=icon-32.png --export-width=32 --export-height=32
inkscape logo.svg --export-filename=icon-48.png --export-width=48 --export-height=48
inkscape logo.svg --export-filename=icon-64.png --export-width=64 --export-height=64
convert icon-16.png icon-32.png icon-48.png icon-64.png favicon.ico
```
