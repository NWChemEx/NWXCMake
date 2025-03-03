cmaize_find_or_build_dependency(
    integrals
    URL github.com/NWChemEx/integrals
    BUILD_TARGET integrals
    FIND_TARGET nwx::integrals
    CMAKE_ARGS BUILD_TESTING=OFF
               BUILD_PYBIND11_PYBINDINGS=${BUILD_PYBIND11_PYBINDINGS}
               ENABLE_SIGMA=${ENABLE_SIGMA}
)