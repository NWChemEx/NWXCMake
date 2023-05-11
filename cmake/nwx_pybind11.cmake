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

function(find_pybind11 fp_targets)

    set("${fp_targets}" pybind11 Python::Python PARENT_SCOPE)
endfunction()

#[[[ Wraps the process of compiling Python bindings.
#
#    This function will create a CMake target "py_${npm_module_name}". The
#    resulting bindings will live in a shared library called
#    "${npm_module_name}.so", *i.e.* the C++ target with no "lib" prefix. As
#    long as "${npm_module_name}.so" is in your Python path, you should be able
#    to load the bindings.
#
#   :param npm_module_name: The name of the resulting Python module. The
#                           corresponding target created by this function will
#                           be named ``py_${npm_module_name}``
#   :param \*args: The arguments to forward to ``cmaize_add_library``.
#]]
function(nwx_add_pybind11_module npm_module_name)
    if("${BUILD_PYBIND11_PYBINDINGS}")
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
        set_target_properties(
            "${_npm_py_target_name}"
            PROPERTIES
            PREFIX ""
            LIBRARY_OUTPUT_NAME "${npm_module_name}"
        )
        cmaize_add_package("${_npm_py_target_name}" NAMESPACE nwx::)
    endif()
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
#   :param npt_name: The name for the test. This will be the name CTest
#                    associates with the test.
#   :param npt_driver: The name of the Python module responsible for driving
#                      the test. It is strongly recommended that you pass the
#                      full path to the Python module.
#]]
function(nwx_pybind11_tests npt_name npt_driver)
    if("${BUILD_PYBIND11_PYBINDINGS}")
        if("${BUILD_TESTING}")
            add_test(
                NAME "${npt_name}"
                COMMAND Python::Interpreter "${npt_driver}"
            )
            set_tests_properties(
                "${npt_name}"
                PROPERTIES ENVIRONMENT "PYTHONPATH=${CMAKE_BINARY_DIR}"
            )
        endif()
    endif()
endfunction()
