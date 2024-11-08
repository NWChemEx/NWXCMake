cmaize_find_or_build_dependency(
    tamm
    URL github.com/NWChemEx-Project/TAMM
    VERSION main
    BUILD_TARGET tamm
    FIND_TARGET tamm::tamm
    CMAKE_ARGS MODULES="DFT"
)