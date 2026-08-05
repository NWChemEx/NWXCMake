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
include(CTest)

#[[[
# Registers a CTest test that runs an existing test executable under ``mpiexec``.
#
# This is a thin wrapper over the ``add_test(... ${MPIEXEC_EXECUTABLE} ...)``
# pattern so repositories don't have to hand-write the launcher invocation. The
# executable is typically one already built/registered by
# :cmake:command:`catch2_tests_from_dir`; this simply adds a second, parallel
# invocation of it. Requires :cmake:command:`nwx_find_mpi` to have run.
#
# :param nmt_test_name: Name to register the CTest test under.
# :type nmt_test_name: desc
# :param nmt_exe: Target (or path) of the test executable to launch.
# :type nmt_exe: target
# :keyword NPROC: Number of MPI ranks to launch with. Defaults to ``2``.
# :type NPROC: int
#
# .. code-block:: cmake
#
#    include(nwx_mpi_test)
#    nwx_mpi_test(test_foo_under_mpi test_foo NPROC 2)
#]]
function(nwx_mpi_test nmt_test_name nmt_exe)
    if(NOT BUILD_TESTING)
        return()
    endif()

    set(_nmt_options)
    set(_nmt_one_value NPROC)
    set(_nmt_multi_value)
    cmake_parse_arguments(
        NMT "${_nmt_options}" "${_nmt_one_value}" "${_nmt_multi_value}" ${ARGN}
    )
    if(NOT NMT_NPROC)
        set(NMT_NPROC 2)
    endif()

    add_test(
        NAME "${nmt_test_name}"
        COMMAND "${MPIEXEC_EXECUTABLE}" "${MPIEXEC_NUMPROC_FLAG}" "${NMT_NPROC}"
                "$<TARGET_FILE:${nmt_exe}>"
    )
endfunction()
