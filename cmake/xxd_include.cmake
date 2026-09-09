# cmake -DXXD=<xxd> -DIN=<file> -DOUT=<file> -P cmake/xxd_include.cmake
#
# Runs `xxd --include IN` and writes stdout to OUT. The regen-headers target needs this
# because add_custom_command cannot redirect, and doing it through `cmd /c` / `sh -c`
# breaks as soon as a path contains a space (xxd ships under "C:\Program Files\Git").
# IN must stay relative to the repo root: xxd derives the array name from the path it is
# given, so images/bar_blue.png is what produces `images_bar_blue_png`.

execute_process(
  COMMAND "${XXD}" --include "${IN}"
  OUTPUT_FILE "${OUT}"
  RESULT_VARIABLE _rc
  ERROR_VARIABLE _err)
if(NOT _rc EQUAL 0)
  message(FATAL_ERROR "xxd --include ${IN} failed (${_rc}): ${_err}")
endif()
