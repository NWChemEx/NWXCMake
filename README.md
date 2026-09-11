<!--
  ~ Copyright 2026 NWChemEx-Project
  ~
  ~ Licensed under the Apache License, Version 2.0 (the "License");
  ~ you may not use this file except in compliance with the License.
  ~ You may obtain a copy of the License at
  ~
  ~ http://www.apache.org/licenses/LICENSE-2.0
  ~
  ~ Unless required by applicable law or agreed to in writing, software
  ~ distributed under the License is distributed on an "AS IS" BASIS,
  ~ WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  ~ See the License for the specific language governing permissions and
  ~ limitations under the License.
-->

# NWXCMake
CMake modules and toolchains for NWChemEx

## Versioning note

PyPI has an orphaned `nwchemex-nwxcmake==0.1.0` release from 2026-08-05 with no corresponding git
tag -- a frozen build-overhaul-era snapshot (it hardcodes a since-deleted `simde` git branch).
Every ecosystem repo's `pyproject.toml` pins `nwchemex-nwxcmake>=0.1.0`, and since that's the only
release ever published as `0.1.0`, pip always resolved to it in preference to any newer `0.0.x`
patch release. This PR bumps straight to `0.2.0` (skipping the `0.1.x` line entirely, via a
`v0.1.99` sentinel git tag with no matching PyPI release) so the existing `>=0.1.0` pins resolve to
a real, current build again without every downstream repo needing a pin change.
