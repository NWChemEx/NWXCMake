cmaize_find_or_build_dependency(
    chemist
    URL github.com/NWChemEx/chemist
    BUILD_TARGET chemist
    FIND_TARGET nwx::chemist
    CMAKE_ARGS BUILD_TESTING=OFF
               BUILD_PYBIND11_PYBINDINGS=${BUILD_PYBIND11_PYBINDINGS}
)