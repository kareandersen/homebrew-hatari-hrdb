class HatariHrdb < Formula
  desc "Hatari emulator with HRDB debugger"
  homepage "http://clarets.org/steve/projects/hrdb.html"
  license "GPL-2.0"
  head "https://github.com/tattlemuss/hatari", branch: "hrdb-main", using: :git

  depends_on "gcc" => :build
  depends_on "pkg-config" => :build
  depends_on "cmake" => :build
  depends_on "qt6"
  depends_on "libpng"
  depends_on "portaudio"
  depends_on "sdl2"
  depends_on "portmidi"
  depends_on "readline"

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
    apps_dir.install "build/src/Hatari-HRDB.app"

    # Wrapper inside the .app bundle
    in_bundle_wrapper = apps_dir/"Hatari-HRDB.app/Contents/MacOS/hatari-hrdb-wrapper.sh"
    in_bundle_wrapper.write <<~EOS
      #!/bin/bash
      EXEC="$(dirname "$0")/Hatari"
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
    in_bundle_wrapper.chmod 0755

    # CLI wrapper in PATH
    bin_wrapper = bin/"hatari-hrdb"
    bin_wrapper.write <<~EOS
      #!/bin/bash
      WRAPPED="#{opt_prefix}/Applications/hatari-hrdb/Hatari-HRDB.app/Contents/MacOS/hatari-hrdb-wrapper.sh"
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
      system "touch", "hrdb.qrc"

      # Build
      system "qmake", "."
      system "make"

      # Install
      apps_dir.install "hrdb.app"

      # Set the application bundle icon
      icon_dest = apps_dir/"hrdb.app/Contents/Resources/hrdb.icns"
      (icon_dest.dirname).mkpath
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
      [ "$1" == "--system" ] && DEST_DIR="/Applications/hatari-hrdb"
      SOURCE_DIR="#{opt_prefix}/Applications/hatari-hrdb"
      mkdir -p "$DEST_DIR"
      for app in "$SOURCE_DIR"/*.app; do
        name=$(basename "$app")
        target="$DEST_DIR/$name"
        if [ ! -e "$target" ]; then
          echo "Linking $name to $DEST_DIR"
          ln -s "$app" "$target"
        else
          echo "$name already exists in $DEST_DIR"
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
end

