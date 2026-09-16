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

#[[[
# Refuses, loudly and early, to link the published macOS wheels with GCC.
#
# The macOS wheels are built by cibuildwheel with AppleClang, so every C++
# library in them is compiled against **libc++**. Homebrew's GCC uses its own
# **libstdc++** and has no working libc++ mode on macOS. The two spell
# ``std::string`` differently in the mangled ABI --
# ``NSt3__112basic_string...`` versus ``NSt7__cxx1112basic_string...`` -- so
# nothing GCC compiles can resolve a symbol the wheels export.
#
# Without this check the failure surfaces far from its cause: macOS links
# lazily (``Python::Module`` implies ``-undefined dynamic_lookup``), so the
# build *succeeds* and the first symptom is a ``dyld: symbol not found in flat
# namespace`` abort when a test runs. That cost a full CI cycle to diagnose.
#
# Not a Linux problem: there, clang consumes GCC's own libstdc++ headers and
# links the same ``libstdc++.so.6``, so both compilers share one runtime and
# agree on the mangling.
#
# Called once from :cmake:command:`get_dependencies`, straight after
# ``get_skbuild_python_path()`` establishes ``NWX_VENV_SITE_PACKAGES`` -- the
# single point every wheel resolution passes through.
#]]
macro(nwx_assert_wheel_toolchain_supported)
    # Only meaningful once a C++ compiler is known, and only when wheels are
    # actually reachable: a GCC build with no NWX wheels installed is fine,
    # and so is one that has opted out of them.
    if(APPLE
       AND CMAKE_CXX_COMPILER_ID STREQUAL "GNU"
       AND NWX_VENV_SITE_PACKAGES
       AND NOT NWX_ECOSYSTEM_FROM_SOURCE
       AND EXISTS "${NWX_VENV_SITE_PACKAGES}/lib/cmake")
        message(FATAL_ERROR
            "Refusing to build: on macOS the installed NWChemEx wheels cannot "
            "be used with GCC.\n"
            "  compiler        : ${CMAKE_CXX_COMPILER_ID} "
            "${CMAKE_CXX_COMPILER_VERSION}\n"
            "  wheels found in : ${NWX_VENV_SITE_PACKAGES}/lib/cmake\n"
            "The macOS wheels are built with AppleClang against libc++; GCC on "
            "macOS uses libstdc++.\n\n"
            "Pick one:\n"
            "  * Build with Clang, which is what the macOS wheels support.\n"
            "  * Keep GCC and build the whole ecosystem from source, ignoring "
            "the installed wheels:\n"
            "        cmake -DNWX_ECOSYSTEM_FROM_SOURCE=ON ...\n"
            "Linux is unaffected: clang there uses GCC's libstdc++, so both "
            "compilers share one C++ runtime."
        )
    endif()
endmacro()
