class HatariHrdb < Formula
  desc "Hatari emulator with HRDB debugger"
  homepage "http://clarets.org/steve/projects/hrdb.html"
  url "https://github.com/tattlemuss/hatari/archive/refs/tags/hrdb-v0.010.tar.gz"
  sha256 "ccbebf1367f7ffd1eb3b110b065d550362b66a840bfffba49555d7d84afd02bb"
  license "GPL-2.0-or-later"
  head "https://github.com/tattlemuss/hatari", branch: "hrdb-main", using: :git

  bottle do
    root_url "https://github.com/kareandersen/homebrew-hatari-hrdb/releases/download/bottles-0.010-20250922-000040"
    sha256 cellar: :any, arm64_sequoia: "7bebb916a27b9f37057246d37efcacd31e706481c722d6da79d12b08332000dc"
    sha256 cellar: :any, sequoia:       "92e81e1fbecf34c976503c5e29fa00015ab01da377697408cfb92541328bc280"
  end

  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on "pkg-config" => :build
  depends_on "libpng"
  depends_on "portaudio"
  depends_on "portmidi"
  depends_on "qt6"
  depends_on "readline"
  depends_on "sdl2"

  def install
    unless DevelopmentTools.clang_build_version
      odie <<~EOS
        Xcode command-line tools are not fully initialized.

        Please run the following before installing again:

          sudo xcode-select --switch /Applications/Xcode.app
          sudo xcodebuild -runFirstLaunch
      EOS
    end

    (apps_dir = prefix/"Applications/hatari-hrdb").mkpath

    mkdir "build" do
      system "cmake", "..",
        "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.arch}",
        "-DCMAKE_BUILD_TYPE=Release",
        *std_cmake_args
      system "cmake", "--build", ".", "--parallel"
    end

    # Rename and install the app bundle
    mv "build/src/Hatari.app", "build/src/Hatari-HRDB.app"

    # Clean up bundled development files
    rm_rf "build/src/Hatari-HRDB.app/Contents/Frameworks/lib/pkgconfig"
    rm_rf "build/src/Hatari-HRDB.app/Contents/Frameworks/lib/cmake"
    rm_f Dir["build/src/Hatari-HRDB.app/Contents/Frameworks/lib/*.a"]

    # Relink to use Homebrew SDL2 instead of bundled version
    system "install_name_tool", "-change",
           "@executable_path/../Frameworks/lib/libSDL2-2.0.0.dylib",
           "#{Formula["sdl2"].opt_lib}/libSDL2-2.0.0.dylib",
           "build/src/Hatari-HRDB.app/Contents/MacOS/Hatari"

    # Remove bundled SDL2 to avoid signing issues
    rm_f Dir["build/src/Hatari-HRDB.app/Contents/Frameworks/lib/libSDL2*"]

    # Sign the hatari executable
    system "codesign", "--force", "--sign", "-",
           "build/src/Hatari-HRDB.app/Contents/MacOS/Hatari"

    apps_dir.install "build/src/Hatari-HRDB.app"

    # Create scripts directory and wrapper script outside the app bundle
    scripts_dir = apps_dir/"scripts"
    scripts_dir.mkpath
    wrapper_script = scripts_dir/"hatari-hrdb-wrapper.sh"
    wrapper_script.write <<~EOS
      #!/bin/bash
      EXEC="$(dirname "$0")/../Hatari-HRDB.app/Contents/MacOS/Hatari"
      ARGS=()
      for arg in "$@"; do
          case "$arg" in
              "~" )   ARGS+=("$HOME") ;;
              "~/"*)  ARGS+=("$HOME/${arg#~/}") ;;
              * )     ARGS+=("$arg") ;;
          esac
      done
      exec "$EXEC" "${ARGS[@]}"
    EOS
    wrapper_script.chmod 0755

    # CLI wrapper in PATH
    bin_wrapper = bin/"hatari-hrdb"
    bin_wrapper.write <<~EOS
      #!/bin/bash
      WRAPPED="#{opt_prefix}/Applications/hatari-hrdb/scripts/hatari-hrdb-wrapper.sh"
      if [ ! -x "$WRAPPED" ]; then
        echo "Hatari-HRDB error: $WRAPPED not found or not executable."
        exit 1
      fi
      exec "$WRAPPED" "$@"
    EOS
    bin_wrapper.chmod 0755

    cp Pathname(__dir__).join("Resources/hrdb.icns"), buildpath/"hrdb.icns"

    cd "tools/hrdb" do
      # Replace the embedded application icon with our own, regenerate resources
      system "sips", "-s", "format", "png", buildpath/"hrdb.icns", "--out", "images/hrdb_icon.png"
      touch "hrdb.qrc"

      # Build
      system "qmake", "."
      system "make"

      # Install
      apps_dir.install "hrdb.app"

      # Ad-hoc sign the HRDB binary for bottling compatibility
      system "codesign", "--force", "--sign", "-",
             apps_dir/"hrdb.app/Contents/MacOS/hrdb"

      # Set the application bundle icon
      icon_dest = apps_dir/"hrdb.app/Contents/Resources/hrdb.icns"
      icon_dest.dirname.mkpath
      cp buildpath/"hrdb.icns", icon_dest

      # Patch Info.plist
      plist_file = apps_dir/"hrdb.app/Contents/Info.plist"
      system "/usr/libexec/PlistBuddy", "-c",
             "Set :CFBundleIconFile hrdb.icns",
             plist_file.to_s
    end

    # Add a CLI symlink for HRDB
    bin.install_symlink apps_dir/"hrdb.app/Contents/MacOS/hrdb"

    # Linking script
    (link_script = bin/"link-hatari-hrdb.sh").write <<~EOS
      #!/bin/bash
      set -e

      DEST_DIR="$HOME/Applications/hatari-hrdb"
      if [ "$1" == "--system" ]; then
        DEST_DIR="/Applications/hatari-hrdb"
      elif [ "$1" != "" ]; then
        echo "Usage: $(basename "$0") [--system]"
        echo "  (default: links to ~/Applications/hatari-hrdb)"
        exit 1
      fi

      BREW_PREFIX="$(brew --prefix hatari-hrdb)"
      SOURCE_DIR="$BREW_PREFIX/Applications/hatari-hrdb"

      mkdir -p "$DEST_DIR"

      for app in "$SOURCE_DIR"/*.app; do
        name=$(basename "$app")
        target="$DEST_DIR/$name"

        if [ -L "$target" ]; then
          current_target=$(readlink "$target")
          if [ "$current_target" != "$app" ]; then
            echo "Updating stale symlink: $target"
            rm "$target"
            ln -s "$app" "$target"
          else
            echo "Symlink already correct: $name"
          fi
        elif [ -e "$target" ]; then
          echo "Skipping existing non-symlink: $name"
        else
          echo "Linking $name to $DEST_DIR"
          ln -s "$app" "$target"
        fi
      done

      echo "Done! Linked to: $DEST_DIR"
    EOS
    link_script.chmod 0755

    # Unlinking script
    (unlink_script = bin/"unlink-hatari-hrdb.sh").write <<~EOS
      #!/bin/bash
      set -e
      DEST_DIR="$HOME/Applications/hatari-hrdb"
      [ "$1" == "--system" ] && DEST_DIR="/Applications/hatari-hrdb"
      if [ ! -d "$DEST_DIR" ]; then
        echo "No symlink directory found at: $DEST_DIR"
        exit 0
      fi
      echo "Removing symlinks from: $DEST_DIR"
      for link in "$DEST_DIR"/*.app; do
        [ -L "$link" ] && echo "Removing $(basename "$link")" && rm "$link"
      done
      rmdir "$DEST_DIR" 2>/dev/null || true
      echo "Done."
    EOS
    unlink_script.chmod 0755
  end

  def caveats
    <<~EOS
      Hatari-HRDB and HRDB have been installed to:
        #{opt_prefix}/Applications/hatari-hrdb/

      You can launch Hatari-HRDB via:
        hatari-hrdb

      Or launch the debugger via:
        hrdb

      To link them into your Applications folder:
        link-hatari-hrdb.sh          # links to ~/Applications
        sudo link-hatari-hrdb.sh --system  # links to /Applications

      To remove the links:
        unlink-hatari-hrdb.sh [--system]

    EOS
  end

  test do
    # Test that the hatari binary can be executed
    assert_match "Hatari", shell_output("#{bin}/hatari-hrdb --version 2>&1", 1)
    # Test that HRDB can be executed
    assert_match "hrdb", shell_output("#{bin}/hrdb --version")
  end
end
