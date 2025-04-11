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
    # Build Hatari
    mkdir "build" do
      system "cmake", "..",
        "-DCMAKE_OSX_ARCHITECTURES=#{Hardware::CPU.arch}",
        *std_cmake_args
        system "cmake", "--build", ".", "--parallel"
    end

    # Prepare Applications subdir
    (apps_dir = prefix/"Applications/hatari-hrdb").mkpath

    # Rename Hatari.app and install
    mv "build/src/Hatari.app", "build/src/Hatari-HRDB.app"
    apps_dir.install "build/src/Hatari-HRDB.app"

    # Build HRDB debugger
    cd "tools/hrdb" do
      system "qmake", "."
      system "make"
      apps_dir.install "hrdb.app"
    end

    # Install CLI symlinks
    bin.install_symlink apps_dir/"Hatari-HRDB.app/Contents/MacOS/hatari" => "hatari-hrdb"
    bin.install_symlink apps_dir/"hrdb.app/Contents/MacOS/hrdb"

    (link_script = bin/"link-hatari-hrdb.sh").write <<~EOS
  #!/bin/bash
  set -e

  SOURCE_DIR="$(brew --prefix hatari-hrdb)/Applications/hatari-hrdb"
  DEST_DIR="/Applications/hatari-hrdb"

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

  echo "Done! You should now see a folder in Applications called hatari-hrdb."
EOS

    link_script.chmod 0755
  end

  def caveats
    <<~EOS
    Hatari-HRDB and HRDB have been installed to:
      #{opt_prefix}/Applications/hatari-hrdb/

    To link them into /Applications for easy access, run:

      link-hatari-hrdb.sh

    This will symlink both Hatari-HRDB.app and hrdb.app into:
      /Applications/hatari-hrdb/
    EOS
  end

  test do
    assert_match "Hatari", shell_output("#{bin}/hatari-hrdb --help", 1)
    assert_match "Usage", shell_output("#{bin}/hrdb --help", 1)
  end
end

