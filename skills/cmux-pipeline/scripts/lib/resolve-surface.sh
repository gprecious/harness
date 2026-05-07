#!/usr/bin/env bash
# scripts/lib/resolve-surface.sh — shared helper for pane->surface ref resolution
#
# cmux 0.62.2 quirk: many "send"/"read" commands accept a flag named --pane (or
# --panel) but actually require a SURFACE ref, not a pane ref. Passing pane:N
# directly returns "Error: invalid_params: Surface is not a terminal".
#
# This helper converts pane:N -> surface:N by querying cmux. surface:N refs and
# UUIDs that already resolve are passed through unchanged. UUIDs that look like
# pane refs are also probed via list-pane-surfaces; if that fails, the original
# value is returned (caller will get cmux's error).
#
# Usage (sourced):
#   source "$(dirname "$0")/lib/resolve-surface.sh"
#   surface_ref=$(resolve_surface "$pane_ref") || exit 1
#
# Returns the surface ref on stdout. On failure, prints an error to stderr and
# returns non-zero.

resolve_surface() {
  local pane_ref="$1"
  if [ -z "$pane_ref" ]; then
    echo "resolve_surface: pane ref required" >&2
    return 1
  fi

  case "$pane_ref" in
    surface:*)
      # Already a surface ref — pass through.
      echo "$pane_ref"
      return 0
      ;;
    pane:*)
      local surface
      surface=$(cmux list-pane-surfaces --pane "$pane_ref" 2>/dev/null \
        | grep -oE 'surface:[0-9]+' | head -1)
      if [ -z "$surface" ]; then
        echo "resolve_surface: could not resolve $pane_ref to a surface ref" >&2
        return 1
      fi
      echo "$surface"
      return 0
      ;;
    *)
      # Assume UUID; try as a pane ref via list-pane-surfaces. If that fails,
      # fall back to passing the original through (likely already a surface UUID).
      local surface
      surface=$(cmux list-pane-surfaces --pane "$pane_ref" 2>/dev/null \
        | grep -oE 'surface:[0-9]+' | head -1)
      if [ -n "$surface" ]; then
        echo "$surface"
      else
        echo "$pane_ref"
      fi
      return 0
      ;;
  esac
}
