# Copyright 2022 NWChemEx-Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

################################################################################
#
# The master version of this file lives at
# NWChemEx-Project/DeveloperTools/cmake/build_papi.cmake. The version contained in
# all other NWChemEx-Project repositories  is a synchronized copy of the master
# version. Any changes made to the non-master version will be lost the next time
# the master version is updated. To make changes please make them to the master
# version.
#
################################################################################

include_guard()

function(build_papi)

       if( BUILD_CUDA_BINDINGS OR BUILD_HIP_BINDINGS )
         set( BUILD_DEVICE TRUE CACHE BOOL "Enable Device Code" )
       else()
         set( BUILD_DEVICE FALSE CACHE BOOL "Enable Device Code" )
       endif()

       if( BUILD_CUDA_BINDINGS )
         set(PAPI_COMPONENTS cuda)
         set(ENV{PAPI_CUDA_ROOT} "${CUDAToolkit_LIBRARY_ROOT}")
         set(ENV{PAPI_CUDA_CUPTI} "${CUDAToolkit_LIBRARY_ROOT}/extras/CUPTI/lib64/libcupti.so")
       endif( BUILD_CUDA_BINDINGS )

       if( BUILD_HIP_BINDINGS )
         set(GPU_TARGETS "gfx906,gfx908,gfx90a" CACHE STRING "GPU targets to compile for")

         set(PAPI_COMPONENTS rocm)
         set(ENV{PAPI_ROCM_ROOT} ${ROCM_PATH})
       endif( BUILD_HIP_BINDINGS )

       include(ExternalProject)

       ExternalProject_Add(papi
         UPDATE_DISCONNECTED True
         SOURCE_DIR _deps/papi-src
         INSTALL_DIR _deps/papi-build
         SOURCE_SUBDIR "src"
         GIT_REPOSITORY https://bitbucket.org/icl/papi.git
         GIT_TAG master
         UPDATE_COMMAND ""
         PATCH_COMMAND ""
         CONFIGURE_COMMAND ./configure --with-components=${PAPI_COMPONENTS} --prefix=<INSTALL_DIR>
         BUILD_COMMAND     ${CMAKE_MAKE_PROGRAM}
         INSTALL_COMMAND   ${CMAKE_MAKE_PROGRAM} install
         BUILD_IN_SOURCE True
         LOG_DOWNLOAD OFF
         LOG_BUILD OFF
       )

       # Prepare PAPI
       ExternalProject_Get_Property(papi install_dir)
       set(PAPI_INCLUDE_DIR ${install_dir}/include)
       set(PAPI_LIBRARY_PATH ${install_dir}/lib/libpapi.a)
       file(MAKE_DIRECTORY ${PAPI_INCLUDE_DIR})
       #add_library(papi STATIC IMPORTED)
       include_directories(${PAPI_INCLUDE_DIR})
       set_property(TARGET papi PROPERTY IMPORTED_LOCATION ${PAPI_LIBRARY_PATH})
       set_property(TARGET papi APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${PAPI_INCLUDE_DIR})
       # Dependencies
       add_dependencies(papi papi)

endfunction()

# Call the function we just wrote to get CMakePP
build_papi()
