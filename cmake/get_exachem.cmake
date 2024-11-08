cmaize_find_or_build_dependency(
    exachem
    URL github.com/ExaChem/exachem
    VERSION main
    BUILD_TARGET exachem
    FIND_TARGET exachem::exachem
    CMAKE_ARGS MODULES="DFT"
)