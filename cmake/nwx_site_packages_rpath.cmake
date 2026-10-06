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
# Adds every site-packages ``lib/`` directory to a target's build-tree rpath.
#
# When an ecosystem dependency resolves from an installed wheel, the
# build-tree rpath CMake derives from the link line points at wherever that
# wheel was found. Under pip's isolated build (a plain ``pip install -e .``)
# that is a temporary ``pip-build-env-*/overlay`` directory, which pip deletes
# as soon as the build finishes. Anything run from the build tree afterwards
# -- the C++ test executables, in particular -- then fails to load with e.g.
# "dyld: Library not loaded: @rpath/libutilities.dylib".
#
# The same dependency wheels are installed into the venv itself as runtime
# dependencies, which ``get_skbuild_python_path()`` also lists (the
# interpreter's platlib). Appending each listed directory's ``lib/`` gives the
# loader a location that still exists. Directories that are gone at run time
# are skipped by the loader, so listing the temporary ones too is harmless.
#
# Applied to libraries as well as executables: on Linux an executable's
# RUNPATH only covers its *direct* dependencies, so a build-tree library
# linking a wheel's library needs the entry itself. macOS searches the rpaths
# of the whole load chain, so there the executable's entry alone would do.
#
# A no-op when no site-packages directories were recorded, i.e. when
# get_dependencies() never ran and nothing can have come from a wheel.
#
# :param nasp_target: Target to add the build rpath entries to.
# :type nasp_target: target
#]]
function(nwx_add_site_packages_build_rpath nasp_target)
    get_property(_nasp_dirs GLOBAL PROPERTY NWX_SITE_PACKAGES_DIRS)
    if(NOT _nasp_dirs)
        return()
    endif()
    set(_nasp_rpath)
    foreach(_nasp_dir IN LISTS _nasp_dirs)
        list(APPEND _nasp_rpath "${_nasp_dir}/lib")
    endforeach()
    set_property(TARGET ${nasp_target}
        APPEND PROPERTY BUILD_RPATH ${_nasp_rpath}
    )
endfunction()
