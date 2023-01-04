# Copyright 2022 NWChemEx-Project
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

# - Try to find LibInt
#
#  In order to aid find_package the user may set LIBINT_ROOT_DIR to the root of
#  the installed libint.
#
#  Once done this will define
#  LIBINT_FOUND - System has Libint
#  LIBINT_INCLUDE_DIR - The Libint include directories
#  LIBINT_LIBRARY - The libraries needed to use Libint

#Prefer LIBINT_ROOT_DIR if the user specified it
if(NOT DEFINED LIBINT_ROOT_DIR)
    find_package(PkgConfig)
    pkg_check_modules(PC_LIBINT QUIET libint2)
endif()

find_path(LIBINT_INCLUDE_DIR libint2.hpp
          HINTS ${PC_LIBINT_INCLUDEDIR}
          ${PC_LIBINT_INCLUDE_DIRS}
          PATHS ${LIBINT_ROOT_DIR}
          PATH_SUFFIXES libint2)

find_library(LIBINT_LIBRARY NAMES int2
             HINTS ${PC_LIBINT_LIBDIR}
             ${PC_LIBINT_LIBRARY_DIRS}
             PATHS ${LIBINT_ROOT_DIR}
             )

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(libint DEFAULT_MSG
                                  LIBINT_LIBRARY LIBINT_INCLUDE_DIR)

#if (LibInt_FOUND)
#    find_package(Eigen3 REQUIRED)
#endif()

set(LIBINT_LIBRARIES ${LIBINT_LIBRARY})
set(LIBINT_INCLUDE_DIRS ${LIBINT_INCLUDE_DIR})# ${EIGEN3_INCLUDE_DIRS})
