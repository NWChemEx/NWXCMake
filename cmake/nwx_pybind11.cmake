# Copyright 2023 NWChemEx-Project
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

#[[[ @module NWChemEx pybind11 helpers
#
# This module:
#    1. Wraps the process of finding pybind11 in the appropriate configuration.
#    2. Defines a function ``nwx_pybind11_module`` to facilitate making a
#       Python module from an NWChemEx-like library
#    3. Defines a function ``nwx_python_tests`` to facilitate registering
#       Python-based tests with CTest
#
#  All functionality in this CMake module is protected behind the
#  ``BUILD_PYBIND11_PYBINDINGS`` variable. If ``BUILD_PYBIND11_PYBINDINGS``
#  is not set to a truth-y value, the functions in this module are no-ops.
#
#]]

include_guard()

#[[[ Wraps the process of compiling Python bindings.
#
#    This function will create a CMake target "py_${module_name}". The
#    resulting bindings will live in a shared library called
#    "${module_name}.so", *i.e.* the C++ target with no "lib" prefix. As
#    long as "${module_name}.so" is in your Python path, you should be able
#    to load the bindings.
#
#   :param module_name: The name of the resulting Python module. The
#                       corresponding target created by this function will
#                       be named ``py_${module_name}``
#   :param \*args: The arguments to forward to ``cmaize_add_library``.
#]]
function(nwx_add_pybind11_module npm_module_name)
    if(NOT "${BUILD_PYBIND11_PYBINDINGS}")
        return()
    endif()
    if("${NWX_MODULE_DIRECTORY}" STREQUAL "")
        message(
            FATAL_ERROR "NWX_MODULE_DIRECTORY must be set to the directory "
                        "where you would like the Python modules installed."
        )
    endif()

    cmaize_find_or_build_dependency(
        pybind11
        URL github.com/pybind/pybind11
        BUILD_TARGET pybind11_headers
        FIND_TARGET pybind11::embed
        CMAKE_ARGS PYBIND11_INSTALL=ON
                   PYBIND11_FINDPYTHON=ON
    )

    set(_npm_py_target_name "py_${npm_module_name}")
    cmaize_add_library(
        "${_npm_py_target_name}"
        ${ARGN}
    )
    target_include_directories(
        "${_npm_py_target_name}" PUBLIC pybind11_headers Python::Python
    )
    target_link_libraries(
        "${_npm_py_target_name}" PUBLIC pybind11::embed Python::Python
    )

    # The way we set RPATHs here is higly tied to how CMaize installs things
    # at present. If CMaize changes, this code will likely need to change too
    set(_npm_root_install "${CMAKE_INSTALL_PREFIX}/lib/${PROJECT_NAME}")
    set(_npm_rpath "${_npm_root_install}:${_npm_root_install}/external/lib")
    set(_npm_rpath "${_npm_rpath}:${_npm_root_install}/external/tmp")

    set_target_properties(
        "${_npm_py_target_name}"
        PROPERTIES
        PREFIX ""
        LIBRARY_OUTPUT_NAME "${npm_module_name}"
        INSTALL_RPATH "${_npm_rpath}"
    )
    if(APPLE) # Handles Mac/Python library suffix confusion
        set_target_properties(
            "${_npm_py_target_name}"
            PROPERTIES
            SUFFIX ".so"
        )
    endif()
    install(
        TARGETS "${_npm_py_target_name}"
        DESTINATION "${NWX_MODULE_DIRECTORY}"
    )
endfunction()

#[[[ Wraps the process of registering Python-based tests with CTest
#
#   Calling this function will register a new Python-based test which can be
#   run with the CTest command.
#
#   This function assumes that your Python tests are governed by running a
#   Python module. More specifically it assumes that running a command like:
#
#   .. code-block::
#
#      python /path/to/some_module.py
#
#   will run your tests.
#
#   .. note::
#
#      The resulting test actually uses the Python interpreter that
#      ``nwx_pybind11_module`` found, *i.e.*, the raw ``python`` call is only
#      shown for clarity, not accuracy.
#
#   .. note::
#
#      This function assumes your test is a Python module, *i.e.*, a Python
#      script, and NOT a Python package, *i.e.*, a directory with an
#      ``__init__.py`` file.
#
#   :param name: The name for the test. This will be the name CTest
#                associates with the test.
#   :param driver: The name of the Python module responsible for driving
#                  the test. It is strongly recommended that you pass the
#                  full path to the Python module.
#]]
function(nwx_pybind11_tests npt_name npt_driver)
    if(NOT "${BUILD_PYBIND11_PYBINDINGS}")
        return()
    endif()

    set(_npt_options "")
    set(_npt_one_val "")
    set(_npt_lists SUBMODULES)
    cmake_parse_arguments(
        "_npt" "${_npt_options}" "${_npt_one_val}" "${_npt_lists}" ${ARGN}
    )

    if("${BUILD_TESTING}")
        add_test(
            NAME "${npt_name}"
            COMMAND Python::Interpreter "${npt_driver}"
        )
        set(_npt_py_path "PYTHONPATH=${CMAKE_BINARY_DIR}")
        foreach(_npt_submod ${_npt_SUBMODULES})
            message("${_npt_submod}")
        endforeach()
        set_tests_properties(
            "${npt_name}"
            PROPERTIES ENVIRONMENT "${_npt_py_path}"
        )
    endif()
endfunction()