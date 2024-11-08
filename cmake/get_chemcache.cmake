cmaize_find_or_build_dependency(
    chemcache 
    URL github.com/NWChemEx/ChemCache
    BUILD_TARGET chemcache
    FIND_TARGET nwx::chemcache
    CMAKE_ARGS BUILD_TESTING=OFF
               BUILD_PYBIND11_PYBINDINGS=${BUILD_PYBIND11_PYBINDINGS}
)