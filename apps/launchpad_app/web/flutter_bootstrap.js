{{flutter_js}}
{{flutter_build_config}}

// Engine configuration for a build that asks nothing of a third party.
//
// fontFallbackBaseUrl: when text contains characters the bundled typeface
// cannot draw, the engine fetches a fallback font from this address. Its
// default is a Google-hosted one. Pointing it at this site's own origin means
// the request never leaves it. No fallback fonts are hosted there yet, so
// such characters are drawn as empty boxes; see docs/release/web-hosting.md
// for the trade-off and how to host the fonts.
//
// tool/build_web.sh rewrites the marked line when a build is deliberately
// made with --allow-google-fonts.
_flutter.loader.load({
  config: {
    fontFallbackBaseUrl: 'fallback-fonts/', // FONT_FALLBACK_BASE
  },
});
