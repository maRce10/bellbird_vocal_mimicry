# Post-render step (see _quarto.yml): Quarto embeds images and audio in presentation.html
# but leaves reveal.js background videos as links to files. This stores each video in the
# page and adds a script that turns it into a blob: URL when the deck opens, so the deck
# stays a single self-contained file (a data: URL cannot be used directly, because
# reveal.js splits background video sources on commas).
html_file <- "presentation.html"
if (file.exists(html_file)) {
  html <- readChar(html_file, file.size(html_file), useBytes = TRUE)
  refs <- unique(regmatches(html, gregexpr('data-background-video="[^"]+"', html, useBytes = TRUE))[[1]])
  n <- 0
  for (ref in refs) {
    src <- sub('^data-background-video="([^"]+)"$', "\\1", ref)
    if (!file.exists(src)) next
    html <- gsub(ref, paste0('data-background-video-b64="', base64enc::base64encode(src), '"'), html,
                 fixed = TRUE, useBytes = TRUE)
    n <- n + 1
  }
  if (n > 0) {
    js <- paste0(
      "<script>(function () {",
      "document.querySelectorAll('section[data-background-video-b64]').forEach(function (s) {",
      "var b = atob(s.getAttribute('data-background-video-b64')), a = new Uint8Array(b.length);",
      "for (var i = 0; i < b.length; i++) a[i] = b.charCodeAt(i);",
      "s.setAttribute('data-background-video', URL.createObjectURL(new Blob([a], {type: 'video/mp4'})));",
      "s.removeAttribute('data-background-video-b64');",
      "});",
      # the deck sets auto-play-media: false, so background videos are started here, from the
      # beginning, when their slide is entered or the deck opens on it. If the browser blocks
      # sound, the video plays muted and a click on the slide turns the sound on.
      "function playBg(slide) {",
      "var bg = slide && Reveal.getSlideBackground(slide), v = bg && bg.querySelector('video');",
      "if (!v) return;",
      # start time in seconds from the slide's video-inicio attribute (default 0)
      "v.currentTime = parseFloat(slide.getAttribute('data-video-inicio')) || 0; v.muted = false;",
      "v.play().catch(function () {",
      "v.muted = true; v.play().catch(function () {});",
      "document.addEventListener('click', function () { v.muted = false; }, {once: true});",
      "});",
      "}",
      # a .video-boton button on the slide, or a click anywhere on it, plays or pauses the video;
      # the button shows the action available (play or pause)
      "function bgVideo(slide) { var bg = slide && Reveal.getSlideBackground(slide); return bg && bg.querySelector('video'); }",
      "function syncButton(slide) {",
      "var b = slide && slide.querySelector('.video-boton'), v = bgVideo(slide);",
      "if (b && v) b.innerHTML = v.paused ? '&#9654;' : '&#10074;&#10074;';",
      "}",
      "if (window.Reveal) {",
      "Reveal.on('slidechanged', function (e) { playBg(e.currentSlide); });",
      "var start = function () {",
      "Reveal.sync(); playBg(Reveal.getCurrentSlide());",
      "document.querySelectorAll('section[data-background-video]').forEach(function (s) {",
      "var v = bgVideo(s);",
      "if (v) ['play', 'pause', 'ended'].forEach(function (ev) { v.addEventListener(ev, function () { syncButton(s); }); });",
      "s.addEventListener('click', function (e) {",
      "if (e.target.closest('a')) return;",
      "var v = bgVideo(s); if (!v) return;",
      "v.muted = false;",
      "if (v.paused) v.play().catch(function () {}); else v.pause();",
      "});",
      "});",
      "};",
      "if (Reveal.isReady && Reveal.isReady()) start(); else Reveal.on('ready', start);",
      "}",
      "})();</script>")
    # before the last </body> (the page's own; scripts in the page contain the string too)
    parts <- strsplit(html, "</body>", fixed = TRUE, useBytes = TRUE)[[1]]
    k <- length(parts)
    html <- paste0(paste(parts[-k], collapse = "</body>"), js, "\n</body>", parts[k])
  }
  writeChar(html, html_file, eos = NULL, useBytes = TRUE)
}
