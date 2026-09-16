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
# Identifies which C++ standard library the active compiler will use, and in
# which ABI mode.
#
# Two things decide whether one binary can link another's C++ symbols:
#
# * **Which library.** libc++ spells ``std::string`` ``NSt3__112basic_string``;
#   libstdc++ spells it ``NSt7__cxx1112basic_string``. Never interchangeable.
# * **Which ABI mode of it.** libstdc++ additionally has the pre- and
#   post-C++11 ``std::string`` ABIs selected by ``_GLIBCXX_USE_CXX11_ABI``
#   (``Ss`` vs ``NSt7__cxx11...``), and libc++ has independent implementations
#   that agree on mangling but not on layout -- the SDK's versus Homebrew
#   LLVM's, which links cleanly and then aborts in dyld.
#
# Neither is visible in a wheel's platform tag, so it has to be measured.
# Reported as a "kind" (``libc++``/``libstdc++``) and a "version" token
# (``_LIBCPP_VERSION``, or the ``_GLIBCXX_USE_CXX11_ABI`` value).
#
# :param ncs_kind_var: Name of the variable to receive the kind.
# :param ncs_ver_var:  Name of the variable to receive the version token.
#]]
function(nwx_detect_cxx_stdlib ncs_kind_var ncs_ver_var)
    # The markers live in the standard library's own <__config>/<c++config.h>,
    # which only a real header pulls in -- preprocessing an empty file would
    # report nothing.
    set(_ncs_probe "${CMAKE_CURRENT_BINARY_DIR}/nwx_stdlib_probe.cpp")
    file(WRITE "${_ncs_probe}" "#include <string>\n")

    # CMAKE_CXX_FLAGS is included because it can carry the very thing being
    # measured (e.g. -stdlib=libc++, -D_GLIBCXX_USE_CXX11_ABI=0).
    separate_arguments(_ncs_flags NATIVE_COMMAND "${CMAKE_CXX_FLAGS}")
    execute_process(
        COMMAND "${CMAKE_CXX_COMPILER}" ${_ncs_flags} -x c++ -E -dM "${_ncs_probe}"
        OUTPUT_VARIABLE _ncs_defines
        ERROR_QUIET
        RESULT_VARIABLE _ncs_rc
    )
    file(REMOVE "${_ncs_probe}")

    set(_ncs_kind "unknown")
    set(_ncs_ver "unknown")
    if(_ncs_rc EQUAL 0)
        if(_ncs_defines MATCHES "_LIBCPP_VERSION[ \t]+([0-9]+)")
            set(_ncs_kind "libc++")
            set(_ncs_ver "${CMAKE_MATCH_1}")
        elseif(_ncs_defines MATCHES "_GLIBCXX_USE_CXX11_ABI[ \t]+([0-9]+)")
            set(_ncs_kind "libstdc++")
            set(_ncs_ver "cxx11abi=${CMAKE_MATCH_1}")
        endif()
    endif()

    set(${ncs_kind_var} "${_ncs_kind}" PARENT_SCOPE)
    set(${ncs_ver_var} "${_ncs_ver}" PARENT_SCOPE)
endfunction()
