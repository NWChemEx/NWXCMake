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
# Writes the ``<name>Config.cmake`` that ships next to ``<name>Targets.cmake``.
#
# A package config file is required to ``find_dependency()`` its own public
# dependencies before including its targets file. Ours did not, which made
# every published wheel's config unusable as soon as anything actually
# resolved from one:
#
# ``install(EXPORT)`` writes the link interface verbatim, so
# ``simdeTargets.cmake`` declares ``nwx::simde`` with
# ``INTERFACE_LINK_LIBRARIES "nwx::chemist;nwx::pluginplay"``. With nothing
# having created those targets, CMake's own generated boilerplate sets
# ``simde_FOUND FALSE`` -- which ``nwx_ecosystem_dependency`` correctly
# detects, falling through to a source build -- but the half-built
# ``nwx::simde`` IMPORTED target is *left behind*, and CMake fails at
# **generate** time on its dangling link interface:
#
#   The link interface of target "nwx::simde" contains: nwx::chemist
#   but the target was not found.
#
# Emitting the ``find_dependency()`` calls fixes it at the source: the
# dependencies exist, the FOUND check passes, and the package resolves from
# its wheel as intended.
#
# :param wcf_file: Path of the config file to write.
# :type wcf_file: desc
# :param wcf_name: Name of the target/package being installed. Passed
#                  explicitly rather than read out of the caller's scope.
# :type wcf_name: desc
#]]
function(write_config_file wcf_file wcf_name)
    # Public dependencies, recovered from the link interface that
    # install(EXPORT) is about to write out verbatim. EVERY namespaced target
    # in it has to be found here, not just the ecosystem ones: parallelzone,
    # for instance, publicly links spdlog::spdlog and cereal::cereal, and a
    # config that found only its nwx:: deps still reports
    # parallelzone_FOUND FALSE.
    #
    # Namespace-to-package mapping follows the usual CMake convention that a
    # package exports into a namespace named after itself (spdlog::spdlog ->
    # spdlog, Boost::boost -> Boost). The ecosystem's own nwx:: namespace is
    # the exception -- it is shared by every package -- so there the target
    # name is what identifies the package.
    #
    # Un-namespaced entries are skipped: they are either plain system
    # libraries (-lm, /usr/lib/libfoo.a) or targets built in this same
    # project, neither of which is find_package()-able. Generator expressions
    # are skipped because they cannot be evaluated at configure time.
    set(_wcf_deps)
    get_target_property(_wcf_links ${wcf_name} INTERFACE_LINK_LIBRARIES)
    if(_wcf_links)
        foreach(_wcf_link IN LISTS _wcf_links)
            if(_wcf_link MATCHES "\\$<")
                continue()
            elseif(_wcf_link MATCHES "^nwx::(.+)$")
                list(APPEND _wcf_deps "${CMAKE_MATCH_1}")
            elseif(_wcf_link MATCHES "^([^:]+)::")
                list(APPEND _wcf_deps "${CMAKE_MATCH_1}")
            elseif(DEFINED CACHE{NWX_DEP_TARGET_${_wcf_link}})
                # An un-namespaced entry that get_dependencies() resolved:
                # a dependency built from source in this very build tree.
                #
                # This is the normal case for a wheel. build-system.requires
                # carries no ecosystem packages, so nothing resolves as an
                # installed wheel and nwx_ecosystem_dependency falls through to
                # its git-master branch, which appends the bare target name
                # (nwx_ecosystem_dependency.cmake:176); nwx_library then links
                # a plain "utilities", not "nwx::utilities".
                #
                # The exported file does not look like that. install(EXPORT)
                # rewrites such a target to the name it is exported under, so
                # <name>Targets.cmake ends up saying nwx::utilities. Reading
                # the property here, before that rewrite, is the one place the
                # bare form is visible -- and skipping it silently dropped
                # exactly the ecosystem dependencies this function exists to
                # declare. nwchemex-pluginplay 1.0.64 shipped that way: its
                # config emitted Boost alone while its own targets file
                # referenced nwx::utilities and nwx::parallelzone, so
                # pluginplay_FOUND came back FALSE.
                #
                # NWX_DEP_TARGET_<name> is the cache entry get_dependencies()
                # writes for everything it resolves, so its presence is what
                # separates a dependency from a target belonging to this
                # project (which needs no find_dependency and has no config to
                # find).
                list(APPEND _wcf_deps "${_wcf_link}")
            endif()
        endforeach()
    endif()
    if(_wcf_deps)
        list(REMOVE_DUPLICATES _wcf_deps)
    endif()

    # Every emitted variable is suffixed with the package name. A config file
    # is include()d into its *caller's* scope, so a bare _IL_CONFIG_DIR is a
    # single shared slot: as soon as find_dependency() nests one config inside
    # another, the inner one overwrites the outer's value and the outer then
    # include()s its targets file out of the wrong directory. Harmless while
    # no config ever included another; a latent trap the moment one does.
    set(_wcf_dir_var "_IL_${wcf_name}_CONFIG_DIR")

    file(WRITE "${wcf_file}" "") # Erases it if it already exists
    file(APPEND
        "${wcf_file}"
        "get_filename_component(${_wcf_dir_var} "
        "\"\${CMAKE_CURRENT_LIST_FILE}\" PATH)\n"
    )

    # Stamp the C++ standard library this package was BUILT against, and make
    # the config verify it against whatever the consumer is using. Nothing in
    # a wheel's platform tag records this, so without the stamp a mismatch is
    # discovered as an undefined-symbol link error (Linux) or, worse, a
    # successful link followed by a "symbol not found in flat namespace" abort
    # at run time (macOS, which resolves lazily).
    #
    # Emitted self-contained rather than delegating to NWXCMake: a config must
    # keep working for a consumer who has no nwxcmake importable, and leaf
    # packages skip the locator block below entirely because they have no
    # dependencies.
    include(nwx_cxx_stdlib)
    nwx_detect_cxx_stdlib(_wcf_stdlib_kind _wcf_stdlib_ver)
    file(APPEND
        "${wcf_file}"
        "\n"
        "# C++ standard library this package was built against.\n"
        "set(${wcf_name}_BUILT_WITH_STDLIB \"${_wcf_stdlib_kind}\")\n"
        "set(${wcf_name}_BUILT_WITH_STDLIB_VERSION \"${_wcf_stdlib_ver}\")\n"
        "if(CMAKE_CXX_COMPILER AND NOT ${wcf_name}_SKIP_ABI_CHECK)\n"
        "    set(_IL_${wcf_name}_PROBE \"\${CMAKE_CURRENT_BINARY_DIR}/nwx_stdlib_probe_${wcf_name}.cpp\")\n"
        "    file(WRITE \"\${_IL_${wcf_name}_PROBE}\" \"#include <string>\\n\")\n"
        "    separate_arguments(_IL_${wcf_name}_FLAGS NATIVE_COMMAND \"\${CMAKE_CXX_FLAGS}\")\n"
        "    execute_process(\n"
        "        COMMAND \"\${CMAKE_CXX_COMPILER}\" \${_IL_${wcf_name}_FLAGS} -x c++ -E -dM \"\${_IL_${wcf_name}_PROBE}\"\n"
        "        OUTPUT_VARIABLE _IL_${wcf_name}_DEFS ERROR_QUIET RESULT_VARIABLE _IL_${wcf_name}_RC)\n"
        "    file(REMOVE \"\${_IL_${wcf_name}_PROBE}\")\n"
        "    set(_IL_${wcf_name}_KIND \"unknown\")\n"
        "    set(_IL_${wcf_name}_VER \"unknown\")\n"
        "    if(_IL_${wcf_name}_RC EQUAL 0)\n"
        "        if(_IL_${wcf_name}_DEFS MATCHES \"_LIBCPP_VERSION[ \\t]+([0-9]+)\")\n"
        "            set(_IL_${wcf_name}_KIND \"libc++\")\n"
        "            set(_IL_${wcf_name}_VER \"\${CMAKE_MATCH_1}\")\n"
        "        elseif(_IL_${wcf_name}_DEFS MATCHES \"_GLIBCXX_USE_CXX11_ABI[ \\t]+([0-9]+)\")\n"
        "            set(_IL_${wcf_name}_KIND \"libstdc++\")\n"
        "            set(_IL_${wcf_name}_VER \"cxx11abi=\${CMAKE_MATCH_1}\")\n"
        "        endif()\n"
        "    endif()\n"
        "    if(NOT _IL_${wcf_name}_KIND STREQUAL \"unknown\"\n"
        "       AND NOT _IL_${wcf_name}_KIND STREQUAL \"${_wcf_stdlib_kind}\")\n"
        "        message(FATAL_ERROR\n"
        "            \"${wcf_name} was built against ${_wcf_stdlib_kind}, but this build uses \"\n"
        "            \"\${_IL_${wcf_name}_KIND} (\${CMAKE_CXX_COMPILER_ID}). The two spell std::string \"\n"
        "            \"differently in the mangled ABI, so linking them cannot work.\\n\"\n"
        "            \"Build with a compiler using ${_wcf_stdlib_kind}, or build the ecosystem \"\n"
        "            \"from source with -DNWX_ECOSYSTEM_FROM_SOURCE=ON.\")\n"
        "    elseif(_IL_${wcf_name}_KIND STREQUAL \"libstdc++\"\n"
        "           AND NOT _IL_${wcf_name}_VER STREQUAL \"${_wcf_stdlib_ver}\")\n"
        "        message(FATAL_ERROR\n"
        "            \"${wcf_name} was built with ${_wcf_stdlib_ver}, but this build uses \"\n"
        "            \"\${_IL_${wcf_name}_VER}. libstdc++'s two std::string ABIs are not \"\n"
        "            \"link-compatible (Ss vs NSt7__cxx11...).\\n\"\n"
        "            \"Rebuild this package, or set -D_GLIBCXX_USE_CXX11_ABI to match.\")\n"
        "    elseif(_IL_${wcf_name}_KIND STREQUAL \"libc++\"\n"
        "           AND NOT _IL_${wcf_name}_VER STREQUAL \"${_wcf_stdlib_ver}\")\n"
        "        # Mangling agrees across libc++ versions, so this links; what\n"
        "        # differs is layout and inlined code. Apple's libc++ and\n"
        "        # Homebrew LLVM's are separate implementations and mixing them\n"
        "        # aborts in dyld, but a consumer merely on a different Xcode is\n"
        "        # usually fine -- so warn, and let CI opt into strictness.\n"
        "        if(${wcf_name}_STRICT_ABI_CHECK OR NWX_STRICT_ABI_CHECK)\n"
        "            set(_IL_${wcf_name}_LEVEL FATAL_ERROR)\n"
        "        else()\n"
        "            set(_IL_${wcf_name}_LEVEL WARNING)\n"
        "        endif()\n"
        "        message(\${_IL_${wcf_name}_LEVEL}\n"
        "            \"${wcf_name} was built against libc++ ${_wcf_stdlib_ver}, but this build \"\n"
        "            \"uses libc++ \${_IL_${wcf_name}_VER}. These mangle identically, so this \"\n"
        "            \"will link and may then abort at run time with 'symbol not found in \"\n"
        "            \"flat namespace'. Two different libc++ implementations (e.g. the macOS \"\n"
        "            \"SDK's vs Homebrew LLVM's) must not be mixed; a different Xcode is \"\n"
        "            \"usually benign. Set ${wcf_name}_SKIP_ABI_CHECK=ON to silence.\")\n"
        "        unset(_IL_${wcf_name}_LEVEL)\n"
        "    endif()\n"
        "    unset(_IL_${wcf_name}_PROBE)\n"
        "    unset(_IL_${wcf_name}_FLAGS)\n"
        "    unset(_IL_${wcf_name}_DEFS)\n"
        "    unset(_IL_${wcf_name}_RC)\n"
        "    unset(_IL_${wcf_name}_KIND)\n"
        "    unset(_IL_${wcf_name}_VER)\n"
        "endif()\n"
    )

    if(_wcf_deps)
        # <prefix>/lib/cmake/<name>/<name>Config.cmake -> <prefix>, the same
        # three-PATH walk install(EXPORT)'s own _IMPORT_PREFIX does. Every
        # package installs under a shared prefix (the venv's platlib for a
        # wheel), so a sibling's config sits at <prefix>/lib/cmake/<dep> --
        # exactly where find_package looks once <prefix> is on
        # CMAKE_PREFIX_PATH.
        #
        # CMAKE_PREFIX_PATH is restored afterwards so a consumer's own
        # find_package() calls aren't silently widened by having used this
        # package.
        file(APPEND
            "${wcf_file}"
            "\n"
            "include(CMakeFindDependencyMacro)\n"
            "\n"
            "# Resolution of the dependencies below needs to know where a\n"
            "# pip-installed ecosystem keeps its CMake packages (pybind11's\n"
            "# wheel puts its config somewhere find_package does not search;\n"
            "# Python::Module only exists if Development.Module was asked\n"
            "# for). That knowledge lives in NWXCMake, so locate it the same\n"
            "# way get_nwx_cmake.cmake does -- via the pip-installed locator.\n"
            "# Falling back to a plain find_dependency() when it is not\n"
            "# importable keeps a consumer who already has everything on\n"
            "# CMAKE_PREFIX_PATH working, and yields CMake's ordinary\n"
            "# \"could not find\" diagnostic when they do not.\n"
            "if(NOT COMMAND nwx_config_find_dependency)\n"
            "    find_package(Python QUIET COMPONENTS Interpreter)\n"
            "    if(Python_Interpreter_FOUND)\n"
            "        execute_process(\n"
            "            COMMAND \"\${Python_EXECUTABLE}\" -c\n"
            "                \"import nwxcmake,sys;sys.stdout.write(nwxcmake.cmake_dir())\"\n"
            "            OUTPUT_VARIABLE _IL_${wcf_name}_NWXCMAKE_DIR\n"
            "            OUTPUT_STRIP_TRAILING_WHITESPACE\n"
            "            RESULT_VARIABLE _IL_${wcf_name}_NWXCMAKE_RC\n"
            "            ERROR_QUIET\n"
            "        )\n"
            "        if(_IL_${wcf_name}_NWXCMAKE_RC EQUAL 0\n"
            "           AND IS_DIRECTORY \"\${_IL_${wcf_name}_NWXCMAKE_DIR}\")\n"
            "            list(APPEND CMAKE_MODULE_PATH \"\${_IL_${wcf_name}_NWXCMAKE_DIR}\")\n"
            "            include(nwx_find_dependencies OPTIONAL)\n"
            "        endif()\n"
            "        unset(_IL_${wcf_name}_NWXCMAKE_DIR)\n"
            "        unset(_IL_${wcf_name}_NWXCMAKE_RC)\n"
            "    endif()\n"
            "endif()\n"
            "\n"
            "get_filename_component(_IL_${wcf_name}_PREFIX "
            "\"\${${_wcf_dir_var}}/../../..\" ABSOLUTE)\n"
            "set(_IL_${wcf_name}_SAVED_PREFIX_PATH \"\${CMAKE_PREFIX_PATH}\")\n"
            "list(APPEND CMAKE_PREFIX_PATH \"\${_IL_${wcf_name}_PREFIX}\")\n"
        )
        foreach(_wcf_dep IN LISTS _wcf_deps)
            file(APPEND
                "${wcf_file}"
                "if(COMMAND nwx_config_find_dependency)\n"
                "    nwx_config_find_dependency(${_wcf_dep})\n"
                "else()\n"
                "    find_dependency(${_wcf_dep})\n"
                "endif()\n"
            )
        endforeach()
        file(APPEND
            "${wcf_file}"
            "set(CMAKE_PREFIX_PATH \"\${_IL_${wcf_name}_SAVED_PREFIX_PATH}\")\n"
            "unset(_IL_${wcf_name}_SAVED_PREFIX_PATH)\n"
            "unset(_IL_${wcf_name}_PREFIX)\n"
            "\n"
        )
    endif()

    file(APPEND
        "${wcf_file}"
        "include(\"\${${_wcf_dir_var}}/${wcf_name}Targets.cmake\")\n"
        "unset(${_wcf_dir_var})\n"
    )
endfunction()

#[[[
# Writes every config file queued by install_library().
#
# Runs deferred, at the end of the directory that queued the work, so the
# target's public dependencies are complete. Drains the queue, so the repeated
# cmake_language(DEFER) registrations one directory can accumulate cost
# nothing: the first invocation does the work and the rest find it empty.
#]]
function(nwx_write_pending_config_files)
    get_property(_nwpcf_pending GLOBAL PROPERTY NWX_PENDING_CONFIG_FILES)
    if(NOT _nwpcf_pending)
        return()
    endif()
    set_property(GLOBAL PROPERTY NWX_PENDING_CONFIG_FILES "")
    foreach(_nwpcf_entry IN LISTS _nwpcf_pending)
        string(REPLACE "\t" ";" _nwpcf_parts "${_nwpcf_entry}")
        list(GET _nwpcf_parts 0 _nwpcf_name)
        list(GET _nwpcf_parts 1 _nwpcf_file)
        write_config_file("${_nwpcf_file}" "${_nwpcf_name}")
    endforeach()
endfunction()

function(install_library il_name il_header_dir)
    #TODO: Get these values programmatically
    set(_il_archive_dir lib)
    set(_il_library_dir lib)
    set(_il_runtime_dir bin)
    set(_il_includes_dir include)

    # -- Install target that is a library --
    get_target_property(_il_type ${il_name} TYPE)
    if(_il_type STREQUAL "INTERFACE_LIBRARY")
        install(TARGETS ${il_name} EXPORT ${il_name}Targets)
    else()
        install(TARGETS ${il_name}
            EXPORT ${il_name}Targets
            ARCHIVE DESTINATION "${_il_archive_dir}"
            LIBRARY DESTINATION "${_il_library_dir}"
            RUNTIME DESTINATION "${_il_runtime_dir}"
            INCLUDES DESTINATION "${_il_includes_dir}"
        )
    endif()

    # -- Install CMake Config Files --
    install(EXPORT ${il_name}Targets
        FILE ${il_name}Targets.cmake
        NAMESPACE nwx::
        DESTINATION "${_il_library_dir}/cmake/${il_name}"
    )

    set(_il_config_file "${CMAKE_CURRENT_BINARY_DIR}/${il_name}Config.cmake")
    # Deferred to the end of this directory's processing rather than written
    # now, because "now" is too early to know the target's public dependencies.
    # A project routinely adds usage requirements *after* the nwx_library()
    # call that installs it -- PluginPlay links pybind11::pybind11 and
    # Python::Module twenty lines below its own nwx_library() -- and those
    # additions still reach the exported link interface that install(EXPORT)
    # writes. Reading the property at install_library() time missed them, so
    # nwchemex-pluginplay 1.0.64 shipped a config that declared neither, and a
    # consumer linking nwx::pluginplay died at generate time on the dangling
    # pybind11::pybind11.
    #
    # install(FILES) below only records the path; the file itself is not read
    # until install time, long after the deferred call has produced it.
    # State travels through a global property rather than the deferred call's
    # arguments: il_name and _il_config_file are function-scope, and they do
    # not survive to deferred execution -- passing them directly produced
    # "get_target_property called with incorrect number of arguments" from an
    # empty target name.
    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.19)
        set_property(GLOBAL APPEND PROPERTY
            NWX_PENDING_CONFIG_FILES "${il_name}\t${_il_config_file}"
        )
        cmake_language(DEFER CALL nwx_write_pending_config_files)
    else()
        write_config_file("${_il_config_file}" "${il_name}")
    endif()

    install(FILES "${_il_config_file}"
        DESTINATION "${_il_library_dir}/cmake/${il_name}"
    )

    # -- Install Headers --
    # Trailing slash installs the *contents* of il_header_dir into include/,
    # giving <prefix>/include/<pkg>/... (matches the INSTALL_INTERFACE:include
    # usage requirement). Without it CMake appends the last path component,
    # yielding <prefix>/include/include/<pkg>/...
    # An empty il_header_dir means the target has no headers (e.g. a
    # pure-aggregator INTERFACE target); skip header installation entirely.
    if(il_header_dir)
        install(DIRECTORY "${il_header_dir}/"
            DESTINATION "${_il_includes_dir}"
            FILES_MATCHING
                PATTERN "*.hpp"
                PATTERN "*.h"
                PATTERN "*.ipp"
        )
    endif()
endfunction()
