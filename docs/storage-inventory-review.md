# Storage inventory review — 26 September 2026

## Changes made during review

- Model discovery prunes known cache, SDK, runtime, simulator, application, and Trash trees.
  Unknown siblings remain discoverable. It no longer requests allocated sizes for unrelated
  files in locations traversed solely to find model formats.
- Large Files only defers model candidates inside the Home model scanner's coverage.
  Models on external volumes remain eligible for Large Files.
- Each live scan owns its traversal caches, preventing a terminating scan from cancelling a
  newer scan's cache. Cancelling a model scan or navigating away from a folder preview also
  cancels the associated background walk.
- Folder overlap is resolved before applying candidate limits. Deep ancestor chains cannot
  crowd independent folders out of the inventory. Folders with unreadable subtrees are not
  offered with misleading partial totals.
- Inventory rows are sorted largest first. Each row opens only its own path, including hidden
  children in the folder and model-store browsers. Sizes are aligned on the right using the
  same typography as Simulators. Single-path findings without detailed byte maps retain
  their known total instead of displaying zero.
- Known model-store discovery and Quick Clean share the same path resolver. LM Studio uses
  model directories; Hugging Face discovery includes only `models--*` repositories with blob
  directories, excluding datasets, Spaces, credentials, and symbolic-link aliases.
- AI Models explains that detected files are not known to be unused. Model candidates and
  stores remain review-only; nothing is selected automatically, and removal uses the existing
  preview, confirmation, and Trash flow.

## Local measurement

A read-only Home scan after the metadata-read optimization inspected 1,301,670 entries in
37.2 seconds, finding seven large folders and 16 model candidates. It recorded 469 unreadable
locations. An earlier run before that optimization took 109.9 seconds while Xcode checks were
also running. These are observations from one Mac, not a controlled benchmark or a timing
promise for other systems. No personal files were removed.

The large hidden storage from the original audit remained discoverable without app-specific
folder-name rules. Known cache locations remain assigned to their dedicated categories.

To repeat the optional live measurement:

```sh
STORAGE_CLEANER_LIVE_AUDIT=1 swift test --filter HomeStorageDiscoveryLiveAuditTests
```

The ordinary regression suite skips this Home-walking audit and uses synthetic fixtures.

## Limits that remain visible to the user

- File formats and path context identify model candidates, not whether they are unused,
  replaceable, or independent of other files. App/extension weights and multi-file models
  can stop working if an individual component is removed. Prefer the owning application's
  model manager when removing a complete installed model.
- Other Storage is a fallback inventory, not a complete disk-usage map. It excludes broad
  project/media locations and managed Library locations to avoid conflicting cleanup scopes.
- Filesystem permissions, sandbox grants, candidate limits, shared APFS extents, and ongoing
  writes limit coverage and space estimates. Trash preserves the normal macOS restore path;
  it does not immediately release disk space until emptied.
- The automated layout checks use demo data. They do not establish that every configuration,
  third-party model layout, or assistive-technology workflow is flawless.

## Storage-layout references

- [LM Studio model directory structure](https://lmstudio.ai/docs/app/advanced/import-model)
- [Hugging Face cache layout](https://huggingface.co/docs/huggingface_hub/guides/manage-cache)

## Verification and stopping point

- Final unit regression: 706 tests, one optional live audit skipped, zero failures.
- SwiftLint strict: zero violations. Xcode analyzer/build and Periphery: passed.
- The updated AI inventory was visually inspected from an automated demo screenshot; its
  navigation test passed. One full UI run passed all 13 tests. The later run after the model-store
  change passed 11 and failed two Settings/sidebar tests during desktop interaction.
- Further UI execution was stopped at the user's request because it disrupts their computer.
  No UI runner remained active when checked. The latest complete UI gate is therefore not green;
  no claim of a flawless or fully verified release is made.
