cmaize_find_or_build_dependency(
    gauxc
    URL github.com/wavefunction91/GauXC
    BUILD_TARGET gauxc
    FIND_TARGET gauxc::gauxc
    CMAKE_ARGS BUILD_TESTING=OFF 
               GAUXC_ENABLE_HDF5=OFF
)