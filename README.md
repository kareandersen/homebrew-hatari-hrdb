# homebrew-hatari-hrdb

🍺 A Homebrew tap for building and installing the **Hatari emulator** with the **HRDB debugger**, packaged with macOS `.app` bundles and CLI wrappers.

- This tap builds from a fork of [Hatari](https://www.hatari-emu.org), a versatile Atari ST/STE/TT/Falcon emulator, which includes the HRDB debugger maintained and extended by [@tattlemuss](https://github.com/tattlemuss).
- The Homebrew tap itself — including macOS integration, wrapper scripts, and application icons — is maintained by [@kareandersen](https://github.com/kareandersen).

The `hatari` binary has been renamed to `hatari-hrdb`, and the application bundle to `Hatari-HRDB.app`, to allow coexistence with a standard Hatari installation.

On the command line, `hatari-hrdb` runs a wrapper script located inside the bundle. This allows arguments to be passed correctly and avoids a known crash related to how SDL handles the invisible mouse cursor on macOS.

## Installation

```bash
brew tap kareandersen/homebrew-hatari-hrdb
brew install --HEAD hatari-hrdb
```

> ⚠️ **Note**: This builds from source. You’ll need Xcode command-line tools and a Homebrew environment set up.

## Launching the Applications

After install, app bundles are available in:

```
$(brew --prefix)/opt/hatari-hrdb/Applications/hatari-hrdb/
```

To make them accessible in Finder:

```bash
# Link to your user Applications folder (~/Applications)
link-hatari-hrdb.sh

# Or to the system-wide Applications folder (requires sudo)
sudo link-hatari-hrdb.sh --system
```

## CLI Wrappers

These commands are added to your path:

- `hatari-hrdb` – launches Hatari via its `.app` bundle wrapper (not a raw binary).
- `hrdb` – launches the standalone HRDB debugger.

## Unlinking

To remove the symlinks created above:

```bash
unlink-hatari-hrdb.sh                # Unlink from ~/Applications
sudo unlink-hatari-hrdb.sh --system  # Unlink from /Applications
```

## Notes

- App icons are generated and embedded during the build.
- Launching from CLI preserves GUI functionality.
- Tested on macOS 15 with Apple Silicon and Intel.
--

This tap is maintained by [@kareandersen](https://github.com/kareandersen).
Upstream HRDB fork by [@tattlemuss](https://github.com/tattlemuss).

