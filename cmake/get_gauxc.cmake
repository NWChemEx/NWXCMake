cmaize_find_or_build_dependency(
    gauxc
    URL github.com/wavefunction91/GauXC
    VERSION 71008cffd5d13d5ee813fb13d14d8bf7b06b8f6e
    BUILD_TARGET gauxc
    FIND_TARGET gauxc::gauxc
    CMAKE_ARGS BUILD_TESTING=OFF 
               GAUXC_ENABLE_HDF5=OFF
)
