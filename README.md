# Cuantificación del mimetismo vocal heteroespecífico mediante aprendizaje profundo

Código y presentación del estudio sobre mimetismo vocal en un juvenil de pájaro campana (*Procnias tricarunculatus*) en Monteverde, Costa Rica.

Sitio web: <https://marce10.github.io/bellbird-mimicry/>

## Estructura

- `index.qmd`, `presentacion.qmd`, `_quarto.yml`: páginas y configuración del sitio
- `scripts/`: reportes de análisis
- `presentation/`: presentación (`presentation.qmd`) y sus materiales
- `output/`: figuras

Los datos de audio, los modelos ajustados y el manuscrito no están en el repositorio.

## Actualizar el sitio

Los resultados de los reportes se guardan en `_freeze/`, así que GitHub Pages no necesita R ni los datos:

1. `quarto render` en la raíz del proyecto, y commit de `_freeze/` si cambió un reporte
2. Si cambió la presentación, `quarto render presentation.qmd` dentro de `presentation/`, y commit de `presentation/presentation.html`
3. Push a `master`: `.github/workflows/publish.yml` publica el sitio
