# Copyright 2023 NWChemEx
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
#   :param INSTALL: (optional) Boolean to enable/disable installation of
#                       the module. If not defined module will be installed.
#   :param \*args: The arguments to forward to ``cmaize_add_library``.
#]]
function(nwx_add_pybind11_module npm_module_name)
    set(options)
    set(oneValueArgs INSTALL)
    set(multiValueArgs)
    cmake_parse_arguments(NWX_ADD_PYBIND11_MODULE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT "${BUILD_PYBIND11_PYBINDINGS}")
        return()
    endif()
    if("${NWX_MODULE_DIRECTORY}" STREQUAL "")
        message(
            FATAL_ERROR "NWX_MODULE_DIRECTORY must be set to the directory "
                        "where you would like the Python modules installed."
        )
    endif()

    find_package(Python COMPONENTS Interpreter Development)

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
        ${NWX_ADD_PYBIND11_MODULE_UNPARSED_ARGUMENTS}
    )
    target_include_directories(
        "${_npm_py_target_name}" PUBLIC pybind11_headers Python::Python
    )
    target_link_libraries(
        "${_npm_py_target_name}" PUBLIC pybind11::embed Python::Python
    )

    string(FIND "${npm_module_name}" "py_" _npm_py_in_module_name)
    if(_npm_py_in_module_name)

        # Fetch the install paths of the dependencies from CMaize
        # Ideally, this would only need to get the install path of the
        # immediate dependencies, but that is not working for some reason.
        # Instead, we are grabbing the install path and install rpath of
        # immediate dependencies, which contains deeper dependencies' install
        # paths. This bloats the rpath in the target with a lot of
        # (theoretically) redundant information, but it is necessary right now.
        cpp_get_global(_project CMAIZE_TOP_PROJECT)
        CMaizeProject(get_target "${_project}" _tgt "${npm_module_name}")
        CMaizeTarget(GET "${_tgt}" _npm_dep_install_path install_path)
        CMaizeTarget(GET_PROPERTY "${_tgt}" _npm_dep_install_rpath INSTALL_RPATH)

        list(APPEND _npm_install_rpath ${_npm_dep_install_path})
        list(APPEND _npm_install_rpath ${_npm_dep_install_rpath})
    endif()

    set_target_properties(
        "${_npm_py_target_name}"
        PROPERTIES
        PREFIX ""
        LIBRARY_OUTPUT_NAME "${npm_module_name}"
        INSTALL_RPATH "${_npm_install_rpath}"
    )
    if(APPLE) # Handles Mac/Python library suffix confusion
        set_target_properties(
            "${_npm_py_target_name}"
            PROPERTIES
            SUFFIX ".so"
        )
    endif()
    if(NOT DEFINED NWX_ADD_PYBIND11_MODULE_INSTALL OR NWX_ADD_PYBIND11_MODULE_INSTALL)
        install(
            TARGETS "${_npm_py_target_name}"
            DESTINATION "${NWX_MODULE_DIRECTORY}"
        )
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
#   :param name: The name for the test. This will be the name CTest
#                associates with the test.
#   :param driver: The name of the Python module responsible for driving
#                  the test. It is strongly recommended that you pass the
#                  full path to the Python module.
#
#   **Keyword Arguments**
#
#   :keyword SUBMODULES: A list of other NWChemEx Python submodules which must
#                        be found in order for the test to run. For now, it is
#                        assumed that CMaize built the submodules, or they are
#                        installed in a place which is in the user's PYTHONPATH.
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
        include(CTest)
        # Build the PYTHONPATH for the test
        # N.B. This presently assumes we're building the Python submodules we
        #      need or they are installed in ${NWX_MODULE_DIRECTORY}
        set(_npt_py_path "PYTHONPATH=${NWX_MODULE_DIRECTORY}")
        set(_npt_py_path "${_npt_py_path}:${CMAKE_BINARY_DIR}")
        foreach(_npt_submod ${_npt_SUBMODULES})
            set(_npt_dep_dir "${CMAKE_BINARY_DIR}/_deps/${_npt_submod}-build")
            set(_npt_py_path "${_npt_py_path}:${_npt_dep_dir}")
        endforeach()
        if(NOT "${NWX_PYTHON_EXTERNALS}" STREQUAL "")
            set(_npt_py_path "${_npt_py_path}:${NWX_PYTHON_EXTERNALS}")
        endif()

        add_test(
            NAME "${npt_name}"
            COMMAND Python::Interpreter "${npt_driver}"
        )

        set_tests_properties(
            "${npt_name}"
            PROPERTIES ENVIRONMENT "${_npt_py_path}"
        )
    endif()
endfunction()
