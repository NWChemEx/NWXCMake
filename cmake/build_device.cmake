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

include_guard()

function(build_device)

    # language settings for CUDA
    if( BUILD_CUDA_BINDINGS )
      enable_language( CUDA )
      find_package( CUDAToolkit REQUIRED )

      if(NOT DEFINED CMAKE_CUDA_STANDARD)
        set(CMAKE_CUDA_STANDARD 11)
        set(CMAKE_CUDA_STANDARD_REQUIRED ON)
      endif()
    endif( BUILD_CUDA_BINDINGS )

    # language settings for HIP
    if( BUILD_HIP_BINDINGS )
      enable_language( HIP )
    endif()

    # language settings for SYCL
    if( BUILD_SYCL_BINDINGS )
      unset(CMAKE_CXX_STANDARD PARENT_SCOPE)
      set(CMAKE_CXX_STANDARD 17)
    endif()

endfunction()       

# Call the function we just wrote to get CMakePP
build_device()
