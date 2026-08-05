# Copyright 2025 NWChemEx-Project
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
include(FetchContent)

function(get_dependencies)
    set(_gd_targets)
    set(_gd_fc_names)
    if(SKBUILD)
        include(dependencies/skbuild_python)
    endif()

    # Dependencies found via find_package() below (gauxc, libxc, gau2grid,
    # ...) must only ever resolve against CMAKE_PREFIX_PATH (the active
    # venv, populated by get_skbuild_python_path() above) -- never against
    # the CMake User/System Package Registry (~/.cmake/packages), which
    # holds export(PACKAGE ...) entries pointing at whichever build tree
    # produced them. Those build trees (e.g. some other repo's build/_deps)
    # can be deleted at any time, so a registry hit can resolve to a target
    # whose files no longer exist -- exactly the kind of stale-match bug
    # this avoids.
    set(CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY ON CACHE BOOL
        "Never resolve find_package() against ~/.cmake/packages")
    set(CMAKE_EXPORT_NO_PACKAGE_REGISTRY ON CACHE BOOL
        "Never let export(PACKAGE ...) write to ~/.cmake/packages")
    foreach(depend_i ${ARGN})
        message(STATUS "Fetching dependency: ${depend_i}")
        set(_gd_uses_fc TRUE)
        include(dependencies/${depend_i})
        if(_gd_uses_fc)
            list(APPEND _gd_fc_names ${depend_i})
        endif()
        # Publish the dep-name → CMake-target mapping as a CACHE INTERNAL so
        # nwx_library (and any other NWXCMake helper) can resolve short names
        # to real targets without the caller having to know the target name.
        # Dep files set _gd_target_<name> to override; ecosystem deps (utilities,
        # parallelzone, …) default to the dep name itself as the target.
        if(DEFINED _gd_target_${depend_i})
            set(NWX_DEP_TARGET_${depend_i} "${_gd_target_${depend_i}}"
                CACHE INTERNAL "CMake target for NWX dep '${depend_i}'")
        elseif(NOT DEFINED CACHE{NWX_DEP_TARGET_${depend_i}})
            set(NWX_DEP_TARGET_${depend_i} "${depend_i}"
                CACHE INTERNAL "CMake target for NWX dep '${depend_i}'")
        endif()
    endforeach()

    if(_gd_fc_names)
        # Ecosystem deps (utilities, parallelzone, ...) are pulled in via
        # FetchContent_MakeAvailable, which runs their CMakeLists.txt as a
        # subdirectory of this build -- sharing this project's BUILD_TESTING
        # / INTEGRATION_TESTING cache variables verbatim. Left alone, a
        # developer build (DEVELOPER_SETUP=ON, both ON) would also configure
        # and register every dependency's own unit *and* integration tests.
        # Force both off for the duration of the fetch, then restore, so
        # only this project's own tests are built (mirrors the per-dependency
        # BUILD_TESTING backup/restore already used by libxc.cmake et al.,
        # extended here to cover INTEGRATION_TESTING too).
        set(_gd_bt_backup "${BUILD_TESTING}")
        set(_gd_it_backup "${INTEGRATION_TESTING}")
        set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
        set(INTEGRATION_TESTING OFF CACHE BOOL "" FORCE)
        FetchContent_MakeAvailable(${_gd_fc_names})
        set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
        set(INTEGRATION_TESTING "${_gd_it_backup}" CACHE BOOL "" FORCE)
        unset(_gd_bt_backup)
        unset(_gd_it_backup)
    endif()

    # Record the build-tree location of any fetched dependency's own pybind11
    # module (named "<dep>_python" by nwx_python_module, e.g. parallelzone
    # fetched as a source dependency of this project also builds
    # parallelzone_python). nwx_python_test reads this global property to put
    # such modules on PYTHONPATH for CTest -- they aren't installed anywhere
    # on the ambient dev matrix's Python, only $ENV{PYTHONPATH} at CMake
    # configure time, which is generally empty then.
    foreach(depend_i ${_gd_fc_names})
        if(TARGET ${depend_i}_python)
            set_property(GLOBAL APPEND PROPERTY NWX_PYTHON_MODULE_DIRS
                "$<TARGET_FILE_DIR:${depend_i}_python>"
            )
        endif()
    endforeach()

    set(GET_DEPENDENCIES_TARGETS "${_gd_targets}" PARENT_SCOPE)
endfunction()
