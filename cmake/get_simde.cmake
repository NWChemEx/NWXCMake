cmaize_find_or_build_dependency(
    simde
    URL github.com/NWChemEx/SimDE
    BUILD_TARGET simde
    FIND_TARGET nwx::simde
    CMAKE_ARGS BUILD_TESTING=OFF
               BUILD_PYBIND11_PYBINDINGS=${BUILD_PYBIND11_PYBINDINGS}
               ENABLE_SIGMA=${ENABLE_SIGMA}
)