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

"""Locator for the shared NWChemEx CMake modules.

Downstream CMake projects query this package (via a Python interpreter, which
CMake can run *before* ``project()``) to discover the directory holding the
NWXCMake ``.cmake`` modules and prepend it to ``CMAKE_MODULE_PATH``.
"""

import os

__all__ = ["cmake_dir"]


def cmake_dir() -> str:
    """Return the absolute path to the directory holding the NWXCMake modules.

    Resolution order:

    1. ``NWXCMAKE_DIR`` environment variable, if it names a real directory.
       An escape hatch for unusual installs or CI overrides.
    2. Bundled/wheel layout: ``<this_dir>/cmake``. A regular ``pip install``
       places the modules here via the ``force-include`` in ``pyproject.toml``.
    3. Editable/repo layout: ``<this_dir>/../../cmake``. An editable install
       resolves ``__file__`` back into the working copy (``python/nwxcmake``),
       so its sibling repo-root ``cmake/`` is the live, editable module dir.

    :raises FileNotFoundError: if none of the candidate directories exist.
    """
    override = os.environ.get("NWXCMAKE_DIR")
    if override and os.path.isdir(override):
        return os.path.abspath(override)

    here = os.path.dirname(os.path.abspath(__file__))

    bundled = os.path.join(here, "cmake")
    if os.path.isdir(bundled):
        return bundled

    repo_cmake = os.path.normpath(os.path.join(here, "..", "..", "cmake"))
    if os.path.isdir(repo_cmake):
        return repo_cmake

    raise FileNotFoundError(
        "nwxcmake: could not locate the cmake/ module directory "
        "(checked NWXCMAKE_DIR, {!r}, and {!r})".format(bundled, repo_cmake)
    )


if __name__ == "__main__":
    import sys

    sys.stdout.write(cmake_dir())
