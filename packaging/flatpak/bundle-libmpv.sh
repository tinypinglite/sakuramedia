#!/usr/bin/env bash
set -euo pipefail

bundle="${1:-build/linux/x64/release/bundle}"
libdir="${bundle}/lib"

if [ ! -x "${bundle}/sakuramedia" ]; then
  echo "error: Linux executable not found: ${bundle}/sakuramedia" >&2
  exit 1
fi
if ! command -v patchelf >/dev/null 2>&1; then
  echo "error: patchelf is required to bundle libmpv" >&2
  exit 1
fi

mpv_path="$(ldconfig -p | awk '$1 == "libmpv.so.2" { print $NF; exit }')"
if [ -z "${mpv_path}" ]; then
  echo "error: libmpv.so.2 not found; install libmpv-dev first" >&2
  exit 1
fi

deps_file="$(mktemp)"
copied_file="$(mktemp)"
cleanup() {
  rm -f "${deps_file}" "${copied_file}"
}
trap cleanup EXIT

ldd "${mpv_path}" >"${deps_file}"
if grep -q 'not found' "${deps_file}"; then
  echo "error: libmpv has unresolved dependencies:" >&2
  cat "${deps_file}" >&2
  exit 1
fi

is_runtime_lib() {
  case "$1" in
    libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|libutil.so.*|ld-linux*.so.*|linux-vdso.so.*|libgcc_s.so.*|libstdc++.so.*)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while IFS= read -r line; do
  case "${line}" in
    *"=> /"*)
      dep="$(awk '{ print $3 }' <<<"${line}")"
      ;;
    /*" (0x"*)
      dep="$(awk '{ print $1 }' <<<"${line}")"
      ;;
    *)
      continue
      ;;
  esac

  [ -n "${dep}" ] || continue
  name="$(basename "${dep}")"
  if is_runtime_lib "${name}"; then
    continue
  fi

  cp -Lf "${dep}" "${libdir}/${name}"
  printf '%s\n' "${name}" >>"${copied_file}"
done <"${deps_file}"

if [ ! -e "${libdir}/libmpv.so.2" ]; then
  cp -Lf "${mpv_path}" "${libdir}/libmpv.so.2"
  printf '%s\n' libmpv.so.2 >>"${copied_file}"
fi
ln -sf libmpv.so.2 "${libdir}/libmpv.so"

sort -u "${copied_file}" | while IFS= read -r name; do
  patchelf --set-rpath '$ORIGIN' "${libdir}/${name}"
done

for plugin in "${libdir}"/*_plugin.so; do
  [ -e "${plugin}" ] || continue
  patchelf --set-rpath '$ORIGIN' "${plugin}"
done

echo "Bundled libmpv and its dependency closure from ${mpv_path}"
du -sh "${libdir}/libmpv.so.2"
