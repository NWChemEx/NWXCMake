cmaize_find_or_build_dependency(
    tensorwrapper
    URL github.com/NWChemEx/TensorWrapper
    BUILD_TARGET tensorwrapper
    FIND_TARGET nwx::tensorwrapper
    CMAKE_ARGS BUILD_TESTING=OFF
               BUILD_PYBIND11_PYBINDINGS=${BUILD_PYBIND11_PYBINDINGS}
               ENABLE_SIGMA=${ENABLE_SIGMA}
)