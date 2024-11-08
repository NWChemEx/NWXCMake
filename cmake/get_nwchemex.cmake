cmaize_find_or_build_dependency(
    nwchemex
    URL github.com/NWChemEx/NWChemEx
    BUILD_TARGET nwchemex
    FIND_TARGET nwx::nwchemex
    CMAKE_ARGS BUILD_TESTING=OFF
)   