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

macro(get_skbuild_python_path)
    find_package(Python REQUIRED COMPONENTS Interpreter)
    # scikit-build-core installs C++ artifacts (headers, libs, CMake package
    # configs) under the platlib dir (.../lib/pythonX.Y/site-packages), not
    # sys.prefix itself -- sys.prefix is one directory too shallow for
    # find_package() to ever match anything installed there.
    execute_process(
        COMMAND "${Python_EXECUTABLE}" -c
            "import sysconfig; print(sysconfig.get_path('platlib'))"
        OUTPUT_VARIABLE _tp_py_platlib
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _tp_platlib_rc
    )
    if(NOT _tp_platlib_rc EQUAL 0)
        message(FATAL_ERROR "Could not query sysconfig.get_path('platlib') from Python")
    endif()
    set(CMAKE_PREFIX_PATH "${_tp_py_platlib};${CMAKE_PREFIX_PATH}")
    # Exposed separately (rather than relying on callers to re-derive it from
    # CMAKE_PREFIX_PATH) so dependency lookups that want to search *only*
    # this location -- not the rest of CMAKE_PREFIX_PATH's broader, unscoped
    # system search path (Homebrew, /usr/local, ...), which can accidentally
    # match an unrelated same-named package -- can pass it explicitly via
    # PATHS ... NO_DEFAULT_PATH.
    set(NWX_VENV_SITE_PACKAGES "${_tp_py_platlib}")
endmacro()

get_skbuild_python_path()
