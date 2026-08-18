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

# Resolution order: (1) a pre-installed copy reachable via the caller's own
# CMAKE_PREFIX_PATH (e.g. a hand-built or system-package GauXC), (2) a
# previous build's copy already installed into the active venv's
# site-packages (NWX_VENV_SITE_PACKAGES, set by get_skbuild_python_path()),
# (3) fetch and build from source. CMAKE_FIND_PACKAGE_NO_PACKAGE_REGISTRY is
# already forced ON globally (get_dependencies.cmake), so step (1) can't
# resolve against a stale ~/.cmake/packages entry -- only CMAKE_PREFIX_PATH
# and the normal default search locations.
find_package(gauxc CONFIG QUIET)
if(TARGET gauxc::gauxc)
    set(_gd_target_gauxc "gauxc::gauxc")
    set(_gd_uses_fc FALSE)
    return()
endif()

# Step (2): reuse a previous build's copy instead of re-cloning and
# rebuilding GauXC (and its own transitively-fetched ExchCXX/IntegratorXX/
# libxc) from source every time. Scoped to exactly that directory
# (NO_DEFAULT_PATH) so this can never accidentally match an unrelated
# system-wide install (e.g. Homebrew).
if(NWX_VENV_SITE_PACKAGES)
    # GauXC's own (unrelated, unscoped) internal find_package() calls for its
    # own transitive deps can leave a stale/negative <Pkg>_DIR cache entry
    # behind from an earlier point in this same configure; clear it first so
    # our scoped lookup below always gets a fresh, authoritative search
    # instead of silently reusing that unrelated result.
    unset(gauxc_DIR CACHE)
    find_package(gauxc CONFIG QUIET
        PATHS "${NWX_VENV_SITE_PACKAGES}" NO_DEFAULT_PATH
    )
endif()
if(TARGET gauxc::gauxc)
    set(_gd_target_gauxc "gauxc::gauxc")
    set(_gd_uses_fc FALSE)
    return()
endif()

# GauXC builds a real library from its own CMakeLists. Turn off HDF5 before
# add_subdirectory (CACHE FORCE so our value wins over its option() default,
# policy CMP0077).
set(GAUXC_ENABLE_HDF5 OFF CACHE BOOL "" FORCE)

# GauXC transitively fetches its own libxc/ExchCXX/IntegratorXX, some of
# which predate CMake 3.5's cmake_minimum_required() floor (same situation
# as libfort.cmake); newer CMake releases refuse to configure those at all
# otherwise. Only relaxes the check for projects that don't request a range
# of their own; doesn't change policy behavior for our own CMakeLists.txt.
if(NOT DEFINED CMAKE_POLICY_VERSION_MINIMUM)
    set(CMAKE_POLICY_VERSION_MINIMUM 3.5)
endif()

# GauXC's own CMakeLists calls find_package(OpenMP REQUIRED) for both C and
# CXX. AppleClang has no built-in OpenMP runtime, so FindOpenMP.cmake can't
# find it there without explicit hints -- point it at Homebrew's libomp (the
# standard workaround) when nothing has hinted OpenMP already. Checked by
# truthiness, not DEFINED: a prior failed find_package(OpenMP) in this same
# build tree (e.g. from a nested FetchContent'd subproject) can leave
# OpenMP_C_FLAGS cached as the literal string "NOTFOUND", which DEFINED
# would count as "already hinted" and skip this block, permanently blocking
# GauXC's own OpenMP detection on every later reconfigure.
if(APPLE AND NOT OpenMP_C_FLAGS AND NOT OpenMP_CXX_FLAGS)
    find_program(_gd_brew_exe brew)
    if(_gd_brew_exe)
        execute_process(
            COMMAND "${_gd_brew_exe}" --prefix libomp
            OUTPUT_VARIABLE _gd_libomp_prefix
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
    endif()
    if(_gd_libomp_prefix AND EXISTS "${_gd_libomp_prefix}/include/omp.h")
        set(OpenMP_C_FLAGS "-Xpreprocessor -fopenmp -I${_gd_libomp_prefix}/include")
        set(OpenMP_C_LIB_NAMES "omp")
        set(OpenMP_CXX_FLAGS "-Xpreprocessor -fopenmp -I${_gd_libomp_prefix}/include")
        set(OpenMP_CXX_LIB_NAMES "omp")
        set(OpenMP_omp_LIBRARY "${_gd_libomp_prefix}/lib/libomp.dylib")
    endif()
    unset(_gd_libomp_prefix)
    unset(_gd_brew_exe CACHE)
endif()

# GauXC's vendored linalg-cmake-modules (github.com/wavefunction91/linalg-cmake-modules)
# prepends "Accelerate" to BLAS_PREFERENCE_LIST on Darwin, so it always wins
# over Homebrew's OpenBLAS -- even though CI installs openblas and points
# CMAKE_PREFIX_PATH at it -- because Accelerate is a system framework that
# links successfully with no hint needed. Accelerate is then linked via its
# legacy vecLib/CLAPACK interface (no -DACCELERATE_NEW_LAPACK), which has
# known ABI divergences from standard LAPACK for generalized-eigenvalue
# routines (dsygv/zhegv) -- the confirmed cause of macOS-only segfaults in
# SCF's eigensolver tests. Force OpenBLAS instead by excluding Accelerate from
# the preference list; LAPACK follows automatically since OpenBLAS provides a
# full LAPACK linker too (see FindLAPACK.cmake's BLAS_HAS_LAPACK check).
if(APPLE AND NOT BLAS_PREFERENCE_LIST)
    find_program(_gd_brew_exe brew)
    if(_gd_brew_exe)
        execute_process(
            COMMAND "${_gd_brew_exe}" --prefix openblas
            OUTPUT_VARIABLE _gd_openblas_prefix
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
        )
    endif()
    if(_gd_openblas_prefix)
        list(APPEND CMAKE_PREFIX_PATH "${_gd_openblas_prefix}")
    endif()
    set(BLAS_PREFERENCE_LIST "OpenBLAS" CACHE STRING "" FORCE)
    unset(_gd_openblas_prefix)
    unset(_gd_brew_exe CACHE)
endif()

FetchContent_Declare(
    gauxc
    GIT_REPOSITORY https://github.com/wavefunction91/GauXC
    GIT_TAG        71008cffd5d13d5ee813fb13d14d8bf7b06b8f6e
)

# Drive MakeAvailable here (instead of letting get_dependencies batch it) so we
# can build the subproject with tests off without leaving the parent project's
# BUILD_TESTING clobbered. Opt out of the batched call via _gd_uses_fc below.
set(_gd_bt_backup "${BUILD_TESTING}")
set(BUILD_TESTING OFF CACHE BOOL "" FORCE)
FetchContent_MakeAvailable(gauxc)
set(BUILD_TESTING "${_gd_bt_backup}" CACHE BOOL "" FORCE)
unset(_gd_bt_backup)

# GauXC and its transitively-fetched ExchCXX unconditionally add -Wall
# -Wextra -Wpedantic -Wnon-virtual-dtor -Wshadow as PRIVATE compile options
# to their own sources (gauxc-src/src/CMakeLists.txt,
# exchcxx-src/src/CMakeLists.txt), with no option() to opt out. That floods
# the build log with warnings from code we don't maintain. Append -w after
# their own flags on each target: it's added later, so for GCC/Clang/
# AppleClang it wins over their earlier -W* flags and silences the noise
# for just these two targets' own compilation -- everything else (including
# SCF's own code, since these are PRIVATE and don't propagate) is unaffected.
foreach(_gd_noisy_target gauxc exchcxx)
    if(TARGET ${_gd_noisy_target})
        target_compile_options(${_gd_noisy_target} PRIVATE
            $<$<AND:$<COMPILE_LANGUAGE:CXX>,$<CXX_COMPILER_ID:GNU,Clang,AppleClang>>:-w>
        )
    endif()
endforeach()
unset(_gd_noisy_target)

set(_gd_target_gauxc "gauxc::gauxc")
set(_gd_uses_fc FALSE)
