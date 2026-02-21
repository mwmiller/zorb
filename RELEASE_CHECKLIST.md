# Release Checklist for Zorb 0.9.0

## Pre-Release (Current Status)

- [x] Bump version to 0.9.0 in mix.exs
- [x] Create CHANGELOG.md with release notes
- [x] Update README.md with performance highlights
- [x] Clean up temporary files
- [x] Update package description
- [x] Add new docs to package files and extras
- [x] All tests passing (except 1 pre-existing V7 failure)
- [x] Code formatted and Credo clean

## Pending

- [ ] **Watusi 0.4.0 published to Hex** (BLOCKING)
  - Once published, update mix.exs dependency from path to hex version
  - Change: `{:watusi, path: "../watusi"}` → `{:watusi, "~> 0.4.0"}`

## Release Steps (After Watusi Published)

1. Update watusi dependency in mix.exs:
   ```elixir
   {:watusi, "~> 0.4.0"}
   ```

2. Run final checks:
   ```bash
   mix deps.get
   mix compile
   mix test
   mix docs
   ```

3. Create git tag:
   ```bash
   git tag -a v0.9.0 -m "Release 0.9.0: WASM Patcher with 6000x speedup"
   git push origin main --tags
   ```

4. Publish to Hex:
   ```bash
   mix hex.publish
   ```

5. Verify on Hex.pm:
   - Check package page
   - Verify documentation
   - Test installation in fresh project

## Post-Release

- [ ] Announce on Elixir Forum
- [ ] Update GitHub release notes
- [ ] Consider blog post about 6000x speedup achievement

## Key Features in 0.9.0

- WASM Patcher: ~1ms compilation (6000x speedup)
- Pre-compiled templates embedded at compile-time
- 335 KB memory overhead for all templates
- Backward-compatible API
- Cache support maintained
- Optional traditional compilation for debugging
