# Copyright 2026 NWChemEx-Project
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

#[[[
# Locates the system MPI installation for C++.
#
# On success the imported target ``MPI::MPI_CXX`` and the usual
# ``MPIEXEC_EXECUTABLE`` / ``MPIEXEC_NUMPROC_FLAG`` variables are made available
# for linking libraries and launching parallel tests (see
# :cmake:command:`nwx_mpi_test`). Also defines ``OMPI_SKIP_MPICXX`` on
# ``MPI::MPI_CXX`` (as a usage requirement, so it propagates to anything that
# links it) to work around an OpenMPI C++-bindings header issue; harmless
# no-op for non-OpenMPI implementations.
#
# .. code-block:: cmake
#
#    include(nwx_find_mpi)
#    nwx_find_mpi()
#    nwx_library(my_lib "cxx/include" "cxx/src" MPI::MPI_CXX)
#]]
macro(nwx_find_mpi)
    find_package(MPI REQUIRED COMPONENTS CXX)

    if(TARGET MPI::MPI_CXX)
        target_compile_definitions(MPI::MPI_CXX INTERFACE OMPI_SKIP_MPICXX)
    endif()
endmacro()
