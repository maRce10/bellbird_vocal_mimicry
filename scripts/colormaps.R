#' Canonical colormap registry for the bioacoustics suite.
#'
#' Provides the 19 colormaps used across td_spectrograms.py and
#' td_spectrogram_only.py: 5 matplotlib built-ins plus 14 ffmpeg
#' showspectrum/showspectrumpic palettes transcribed from YUV anchor tables.
#'
#' Exports
#' -------
#' MPL_CMAPS    : list of matplotlib built-in colormap name strings
#' FFMPEG_CMAPS : list of 'ff_*' ffmpeg palette name strings
#' CMAPS        : MPL_CMAPS + FFMPEG_CMAPS (all names, in display order)
#' CMAP_OBJECTS : list of colormap functions (ffmpeg palettes only)

# Matplotlib built-ins
MPL_CMAPS <- c('magma', 'inferno', 'plasma', 'viridis', 'gray_r')

# ffmpeg showspectrum/showspectrumpic palettes
# Transcribed verbatim from libavfilter/avf_showspectrum.c YUV tables.
# Each row: (position_0_to_1, y_luma, u_chroma, v_chroma)
# Full-range BT.601 conversion.
FFMPEG_COLOR_TABLES <- list(
  intensity = matrix(c(
    0.00, 0,                   0,                   0,
    0.13, .03587126228984074,  .1573300977624594,  -.02548747583751842,
    0.30, .18572281794568020,  .1772436246393981,   .17475554840414750,
    0.60, .28184980583656130, -.1593064119945782,   .47132074554608920,
    0.73, .65830621175547810, -.3716070802232764,   .24352759331252930,
    0.78, .76318535758242900, -.4307467689263783,   .16866496622310430,
    0.91, .95336363636363640, -.2045454545454546,   .03313636363636363,
    1.00, 1,                   0,                   0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  rainbow = matrix(c(
    0.00, 0,            0,              0,
    0.13, 44/256.,  (189-128)/256., (138-128)/256.,
    0.25, 29/256.,  (186-128)/256., (119-128)/256.,
    0.38, 119/256., (194-128)/256.,  (53-128)/256.,
    0.60, 111/256.,  (73-128)/256.,  (59-128)/256.,
    0.73, 205/256.,  (19-128)/256., (149-128)/256.,
    0.86, 135/256.,  (83-128)/256., (200-128)/256.,
    1.00, 73/256.,   (95-128)/256., (225-128)/256.
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  moreland = matrix(c(
    0.00, 44/256.,  (181-128)/256., (112-128)/256.,
    0.13, 126/256., (177-128)/256., (106-128)/256.,
    0.25, 164/256., (163-128)/256., (109-128)/256.,
    0.38, 200/256., (140-128)/256., (120-128)/256.,
    0.60, 201/256., (117-128)/256., (141-128)/256.,
    0.73, 177/256., (103-128)/256., (165-128)/256.,
    0.86, 136/256., (100-128)/256., (183-128)/256.,
    1.00, 68/256.,  (117-128)/256., (203-128)/256.
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  nebulae = matrix(c(
    0.00, 10/256.,  (134-128)/256., (132-128)/256.,
    0.23, 21/256.,  (137-128)/256., (130-128)/256.,
    0.45, 35/256.,  (134-128)/256., (134-128)/256.,
    0.57, 51/256.,  (130-128)/256., (139-128)/256.,
    0.67, 104/256., (116-128)/256., (162-128)/256.,
    0.77, 120/256., (105-128)/256., (188-128)/256.,
    0.87, 140/256., (105-128)/256., (188-128)/256.,
    1.00, 1,        0,              0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  fire = matrix(c(
    0.00, 0,            0,              0,
    0.23, 44/256.,  (132-128)/256., (127-128)/256.,
    0.45, 62/256.,  (116-128)/256., (140-128)/256.,
    0.57, 75/256.,  (105-128)/256., (152-128)/256.,
    0.67, 95/256.,   (91-128)/256., (166-128)/256.,
    0.77, 126/256.,  (74-128)/256., (172-128)/256.,
    0.87, 164/256.,  (73-128)/256., (162-128)/256.,
    1.00, 1,            0,              0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  fiery = matrix(c(
    0.00, 0,            0,              0,
    0.23, 36/256.,  (116-128)/256., (163-128)/256.,
    0.45, 52/256.,  (102-128)/256., (200-128)/256.,
    0.57, 116/256.,  (84-128)/256., (196-128)/256.,
    0.67, 157/256.,  (67-128)/256., (181-128)/256.,
    0.77, 193/256.,  (40-128)/256., (155-128)/256.,
    0.87, 221/256., (101-128)/256., (134-128)/256.,
    1.00, 1,            0,              0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  fruit = matrix(c(
    0.00, 0,            0,              0,
    0.20, 29/256.,  (136-128)/256., (119-128)/256.,
    0.30, 60/256.,  (119-128)/256.,  (90-128)/256.,
    0.40, 85/256.,   (91-128)/256.,  (85-128)/256.,
    0.50, 116/256.,  (70-128)/256., (105-128)/256.,
    0.60, 151/256.,  (50-128)/256., (146-128)/256.,
    0.70, 191/256.,  (63-128)/256., (178-128)/256.,
    1.00, 98/256.,   (80-128)/256., (221-128)/256.
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  cool = matrix(c(
    0.00, 0, 0,   0,
    0.15, 0, .5, -.5,
    1.00, 1, -.5, .5
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  magma_ff = matrix(c(
    0.00, 0,            0,              0,
    0.10, 23/256.,  (175-128)/256., (120-128)/256.,
    0.23, 43/256.,  (158-128)/256., (144-128)/256.,
    0.35, 85/256.,  (138-128)/256., (179-128)/256.,
    0.48, 96/256.,  (128-128)/256., (189-128)/256.,
    0.64, 128/256., (103-128)/256., (214-128)/256.,
    0.92, 205/256.,  (80-128)/256., (152-128)/256.,
    1.00, 1,            0,              0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  green = matrix(c(
    0.00, 0,  0, 0,
    0.75, .5, 0, -.5,
    1.00, 1,  0, 0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  viridis_ff = matrix(c(
    0.00, 0,             0,                0,
    0.10, 0x39/255., (0x9D-128)/255.,  (0x8F-128)/255.,
    0.23, 0x5C/255., (0x9A-128)/255.,  (0x68-128)/255.,
    0.35, 0x69/255., (0x93-128)/255.,  (0x57-128)/255.,
    0.48, 0x76/255., (0x88-128)/255.,  (0x4B-128)/255.,
    0.64, 0x8A/255., (0x72-128)/255.,  (0x4F-128)/255.,
    0.80, 0xA3/255., (0x50-128)/255.,  (0x66-128)/255.,
    1.00, 0xCC/255., (0x2F-128)/255.,  (0x87-128)/255.
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  plasma_ff = matrix(c(
    0.00, 0,             0,                0,
    0.10, 0x27/255., (0xC2-128)/255.,  (0x82-128)/255.,
    0.58, 0x5B/255., (0x9A-128)/255.,  (0xAE-128)/255.,
    0.70, 0x89/255., (0x44-128)/255.,  (0xAB-128)/255.,
    0.80, 0xB4/255., (0x2B-128)/255.,  (0x9E-128)/255.,
    0.91, 0xD2/255., (0x38-128)/255.,  (0x92-128)/255.,
    1.00, 1,             0,                0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  cividis = matrix(c(
    0.00, 0,             0,                0,
    0.20, 0x28/255., (0x98-128)/255.,  (0x6F-128)/255.,
    0.50, 0x48/255., (0x95-128)/255.,  (0x74-128)/255.,
    0.63, 0x69/255., (0x84-128)/255.,  (0x7F-128)/255.,
    0.76, 0x89/255., (0x75-128)/255.,  (0x84-128)/255.,
    0.90, 0xCE/255., (0x35-128)/255.,  (0x95-128)/255.,
    1.00, 1,             0,                0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v'))),

  terrain = matrix(c(
    0.00, 0, 0,   0,
    0.15, 0, .5,  0,
    0.60, 1, -.5, -.5,
    0.85, 1, -.5, .5,
    1.00, 1, 0,   0
  ), byrow = TRUE, ncol = 4, dimnames = list(NULL, c('pos', 'y', 'u', 'v')))
)

#' Full-range BT.601 YUV to RGB conversion
#'
#' @param y Luma component [0, 1]
#' @param u U chroma component
#' @param v V chroma component
#'
#' @return Numeric vector of length 3 (R, G, B) clipped to [0, 1]
yuv_to_rgb <- function(y, u, v) {
  r <- y + 1.402 * v
  g <- y - 0.344136 * u - 0.714136 * v
  b <- y + 1.772 * u
  pmax(0, pmin(1, c(r, g, b)))
}

#' Build ffmpeg colormaps from YUV anchor tables
#'
#' Converts YUV anchor tables to interpolated colormap functions.
#' Names get an 'ff_' prefix so they never shadow matplotlib's built-ins.
#'
#' @return List of colormap functions
#' @keywords internal
build_ffmpeg_cmaps <- function() {
  objs <- list()
  names <- character()

  for (key in names(FFMPEG_COLOR_TABLES)) {
    table <- FFMPEG_COLOR_TABLES[[key]]
    positions <- table[, 'pos']
    colors <- t(apply(table[, c('y', 'u', 'v')], 1, function(row) {
      yuv_to_rgb(row[1], row[2], row[3])
    }))
    colors_hex <- rgb(colors[, 1], colors[, 2], colors[, 3])

    # Create interpolating function
    name <- paste0('ff_', key)
    objs[[name]] <- colormap_function(positions, colors_hex)
    names <- c(names, name)
  }

  list(objects = objs, names = names)
}

#' Create a colormap interpolation function
#'
#' @param positions Numeric vector of positions in [0, 1]
#' @param colors Character vector of hex colors matching positions
#'
#' @return Function that maps values in [0, 1] to hex colors
colormap_function <- function(positions, colors) {
  function(x) {
    x <- pmax(0, pmin(1, x))
    idx <- findInterval(x, positions)
    idx <- pmax(1, pmin(length(positions) - 1, idx))

    pos1 <- positions[idx]
    pos2 <- positions[idx + 1]
    t <- (x - pos1) / (pos2 - pos1)
    t <- pmax(0, pmin(1, t))

    col1 <- colors[idx]
    col2 <- colors[idx + 1]

    rgb1 <- col2rgb(col1) / 255
    rgb2 <- col2rgb(col2) / 255

    r <- rgb1[1, ] + t * (rgb2[1, ] - rgb1[1, ])
    g <- rgb1[2, ] + t * (rgb2[2, ] - rgb1[2, ])
    b <- rgb1[3, ] + t * (rgb2[3, ] - rgb1[3, ])

    rgb(r, g, b)
  }
}

# Build the colormap objects and names
.cmap_data <- build_ffmpeg_cmaps()
CMAP_OBJECTS <- .cmap_data$objects
FFMPEG_CMAPS <- .cmap_data$names

# Combined list of all available colormaps
CMAPS <- c(MPL_CMAPS, FFMPEG_CMAPS)

#' Resolve a colormap by name
#'
#' Returns a colormap function for the given name.
#'
#' @param name Character string or colormap function.
#'   Accepts an ffmpeg-palette name ('ff_*') or a matplotlib built-in name.
#'   If already a function, returns it unchanged.
#'
#' @return A colormap function that maps values in [0, 1] to hex colors
#'
#' @examples
#' cmap <- resolve_cmap('ff_rainbow')
#' colors <- cmap(seq(0, 1, length.out = 256))
#'
#' @export
resolve_cmap <- function(name) {
  if (is.function(name)) {
    return(name)
  }

  if (name %in% names(CMAP_OBJECTS)) {
    return(CMAP_OBJECTS[[name]])
  }

  # For matplotlib built-ins, require viridisLite or ggplot2
  if (name %in% MPL_CMAPS) {
    warning(sprintf(
      "Matplotlib colormap '%s' requires viridisLite or ggplot2 package. ",
      "Returning NULL. Install with: install.packages('viridisLite')",
      name
    ))
    return(NULL)
  }

  stop(sprintf("Unknown colormap: '%s'", name))
}

#' Sample colors from a colormap
#'
#' @param name Character string naming the colormap
#' @param n Number of colors to sample
#'
#' @return Character vector of hex colors
#'
#' @examples
#' colors <- sample_colormap('ff_rainbow', 100)
#' image(matrix(1:100, ncol = 1), col = colors)
#'
#' @export
sample_colormap <- function(name, n = 256) {
  cmap <- resolve_cmap(name)
  if (is.null(cmap)) return(NULL)
  cmap(seq(0, 1, length.out = n))
}
