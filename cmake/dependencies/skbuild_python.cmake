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
    # configs) under a site-packages directory (.../lib/pythonX.Y/
    # site-packages), not sys.prefix itself -- sys.prefix is one directory
    # too shallow for find_package() to ever match anything installed there.
    #
    # sysconfig's platlib alone is not enough. pip's isolated build env (what
    # cibuildwheel and a `pip install` from the sdist both use) installs
    # build-system.requires into a separate overlay prefix that is only on
    # sys.path; platlib still names the outer interpreter's site-packages.
    # Searching only platlib there means an ecosystem wheel listed in
    # build-system.requires is never found and the dependency silently falls
    # back to git master. So every site-packages directory on sys.path is
    # searched, in sys.path order, with platlib appended as a fallback.
    # Under pip isolation the outer site-packages is not on sys.path, so a
    # stale wheel installed there cannot shadow the build requirements.
    execute_process(
        COMMAND "${Python_EXECUTABLE}" -c
            "import os, sys, sysconfig
dirs = [p for p in sys.path
        if os.path.basename(p) in ('site-packages', 'dist-packages')]
dirs.append(sysconfig.get_path('platlib'))
out = []
for d in dirs:
    d = os.path.realpath(d)
    if os.path.isdir(d) and d not in out:
        out.append(d)
sys.stdout.write(';'.join(out))"
        OUTPUT_VARIABLE _tp_py_site_dirs
        OUTPUT_STRIP_TRAILING_WHITESPACE
        RESULT_VARIABLE _tp_site_dirs_rc
    )
    if(NOT _tp_site_dirs_rc EQUAL 0 OR NOT _tp_py_site_dirs)
        message(FATAL_ERROR "Could not query site-packages directories from Python")
    endif()
    list(PREPEND CMAKE_PREFIX_PATH ${_tp_py_site_dirs})
    # Exposed separately (rather than relying on callers to re-derive it from
    # CMAKE_PREFIX_PATH) so dependency lookups that want to search *only*
    # these locations -- not the rest of CMAKE_PREFIX_PATH's broader, unscoped
    # system search path (Homebrew, /usr/local, ...), which can accidentally
    # match an unrelated same-named package -- can pass it explicitly via
    # PATHS ... NO_DEFAULT_PATH. This is a list; expand it unquoted.
    set(NWX_VENV_SITE_PACKAGES ${_tp_py_site_dirs})
endmacro()

get_skbuild_python_path()
