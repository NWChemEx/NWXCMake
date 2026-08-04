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
include(FetchContent)

# Libint2 builds a real (compiled) library from its own CMakeLists. Disable the
# parts we don't use before add_subdirectory. CACHE FORCE so our values win over
# the subproject's option() defaults (policy CMP0077).
set(ENABLE_FORTRAN OFF CACHE BOOL "" FORCE)
set(ENABLE_MPFR    OFF CACHE BOOL "" FORCE)
set(LIBINT2_PYTHON OFF CACHE BOOL "" FORCE)

FetchContent_Declare(
    libint2
    URL https://github.com/evaleev/libint/releases/download/v2.11.0/libint-2.11.0.tgz
)

# Drive MakeAvailable here (instead of letting get_dependencies batch it) so we
# can build with tests off without leaving the parent project's BUILD_TESTING
# clobbered. Opt out of the batched call via _gd_uses_fc below.
set(_gd_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)

# When some other dependency in the same build (e.g. SCF's own gauxc/eigen
# fetch) has already declared a FetchContent dependency named "eigen",
# libint2's own internal Eigen detection reuses that already-populated
# source dir but wraps it in its own plain (non-IMPORTED) "libint2_Eigen"
# INTERFACE target, which it then unconditionally exports via its own
# install(EXPORT ...) -- and that export fails CMake's generate-time check
# because the wrapped include dir is a build-tree path. Suppress libint2's
# own install rules while it's being added; we only need its build-tree
# targets, never its installed package config.
set(_gd_skip_install_backup "${CMAKE_SKIP_INSTALL_RULES}")
set(CMAKE_SKIP_INSTALL_RULES ON)

# Unlike most well-behaved CMake projects, libint2's own CMakeLists.txt
# registers its "libint2/..." CTest tests (eritest, unit, hf, hf++, ...)
# unconditionally -- it never checks BUILD_TESTING, so backing that
# variable off above has no effect on them. They also assume libint2's own
# build tree layout/build type and fail outright when re-triggered from a
# consumer's ctest run (e.g. "include could not find requested file:
# nwx_set_version"). set_tests_properties() can't reach into libint2's
# directory scope after the fact to disable them (CMake only lets a
# directory manage tests it registered itself), so intercept add_test()
# for the duration of this fetch and mark each test DISABLED right where
# it's registered instead -- that call executes in the *caller's* (i.e.
# libint2's) directory scope, so it can see the test. Still calling
# through to the real add_test (rather than a no-op) matters: libint2
# immediately follows several add_test() calls with its own
# set_tests_properties() (e.g. FIXTURES_SETUP), which would itself error
# out "Can not find test" if the test were never actually created. The
# first override of a built-in command makes the real implementation
# callable as "_add_test"; capture that once and gate on a flag so this
# can be turned back on afterward without re-shadowing (a second
# `function(add_test)` would just rename *this* wrapper to "_add_test",
# losing the real one).
set(_libint2_suppress_add_test TRUE)
function(add_test)
    _add_test(${ARGN})
    if(_libint2_suppress_add_test)
        list(GET ARGN 0 _libint2_add_test_first_arg)
        if(_libint2_add_test_first_arg STREQUAL "NAME")
            list(GET ARGN 1 _libint2_add_test_name)
        else()
            set(_libint2_add_test_name "${_libint2_add_test_first_arg}")
        endif()
        set_tests_properties(${_libint2_add_test_name} PROPERTIES DISABLED TRUE)
    endif()
endfunction()

FetchContent_MakeAvailable(libint2)
set(CMAKE_SKIP_INSTALL_RULES "${_gd_skip_install_backup}")
unset(_gd_skip_install_backup)
set(_libint2_suppress_add_test FALSE)

# CMAKE_SKIP_INSTALL_RULES stops libint2 from writing its own
# cmake_install.cmake, but the parent directory's generated cmake_install.cmake
# still contains an unconditional include() of that path regardless -- so
# `cmake --install` fails with "include could not find requested file"
# unless something is there. Stand in with a no-op so the include succeeds.
if(NOT EXISTS "${libint2_BINARY_DIR}/cmake_install.cmake")
    file(WRITE "${libint2_BINARY_DIR}/cmake_install.cmake"
         "# Intentionally left blank: libint2's install rules are suppressed.\n")
endif()

# Suppressing libint2's install rules above also throws out the plain
# install(TARGETS ...) that would have put its compiled .dylib/.so next to
# consumers -- without it, anything linking libint2 dlopens fine at build
# time but fails at runtime once installed (library not loaded: libint2...).
# Re-add just the binary install (no EXPORT set, so it can't hit the
# wrapped-Eigen generate-time error that all this is working around).
if(TARGET libint2)
    install(TARGETS libint2 LIBRARY DESTINATION lib RUNTIME DESTINATION bin)
endif()
if(TARGET libint2_cxx)
    install(TARGETS libint2_cxx LIBRARY DESTINATION lib RUNTIME DESTINATION bin)
endif()

set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
unset(_gd_bt_backup)

# Libint2's config exports Libint2::int2 (C library) / Libint2::cxx (C++ API);
# consumers link the C++ API target.
set(_gd_target_libint2 "Libint2::int2")
set(_gd_uses_fc FALSE)
