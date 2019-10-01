#!/bin/bash
#
# ------------------------------------------------------------------------------
# Copyright (c) 2017-2019 VGC Software
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
# ------------------------------------------------------------------------------
#
# This script should be run from macOS, which seems to be the only OS with the
# capability of creating Apple's iconset format *.icns.
#
# In order to run this script, you need Inkscape, ImageMagick, and GIMP:
#
# brew cask install xquartz
# brew cask install inkscape
# brew install imagemagick
# brew cask install gimp
#
# Then simply call:
#
# ./iconify.sh path/to/icon.svg
#
# Guidelines on icon design:
#
# https://developer.apple.com/design/human-interface-guidelines/macos/icons-and-images/app-icon/
#

# Which PNG image sizes should be generated, and which of
# these should be automatically sharpened using GIMP.
#
png_sizes=(16 24 32 48 64 128 256 512 1024)
png_sizes_sharpen=(16 24 32 48)

# Which sizes to use for the generation of the ICO. They should be ordered
# from largest to smallest.
#
ico_png_sizes=(256)
ico_bmp_sizes=(48 32 24 16)

# Which sizes to use for the generation of the *.icns.
#
# Note: for the retina @2x versions, we simply use the PNG generated at twice
# the resolution. For example, for 16x16@2x.png, we use the same image as for
# 32x32.png. In theory, we would want these to be different, but in our case we
# don't even simplify the design of smaller icons anyway, so it doesn't matter.
# In the future, we may want to design simplified SVGs which would be used to
# generate the smaller icons, or even directly design some of the PNGs or BMPs
# without generating them from a SVG.
#
icns_sizes=(16 32 128 256 512)

# Creates a PNG from a SVG using Inkscape.
#
make_png () {
    in_svg=$1
    out_png=$2
    size=$3
    inkscape -z -e "$out_png" -w $size -h $size "$in_svg" >/dev/null 2>/dev/null
}

# Applies sharpening to a PNG using GIMP.
#
# Note that we have to call gimp directly without using a symlink. This is due
# to a current bug/limitation of GIMP. See:
# https://github.com/Homebrew/homebrew-cask/issues/69939
# https://gitlab.gnome.org/Infrastructure/gimp-macos-build/issues/5
#
GIMP=$(readlink "$(which gimp)")
sharpen_png () {
    png=$1
    $GIMP -i -b "
      (define
        (vgc-sharpen filename radius amount threshold)
        (let*
          ((image (car (gimp-file-load RUN-NONINTERACTIVE filename filename)))
           (drawable (car (gimp-image-get-active-layer image))))
          (plug-in-unsharp-mask RUN-NONINTERACTIVE image drawable radius amount threshold)
          (gimp-file-save RUN-NONINTERACTIVE image drawable filename filename)
          (gimp-image-delete image)))
      (vgc-sharpen \"$png\" 5.0 0.30 0)
      (gimp-quit 0)" >/dev/null 2>/dev/null
}

# Creates a BMP from a PNG using ImageMagick.
#
make_bmp () {
    in_png=$1
    out_bmp=$2
    convert "$in_png" -depth 8 -colors 256 "$out_bmp"
}

# Convert the input SVG file to an absolute path, which GIMP requires on macOS
# as of GIMP 2.10.12.
#
in_svg="$(cd "$(dirname "$1")"; pwd -P)/$(basename "$1")"
in_basename=${in_svg%.*}
echo "Input SVG file to iconify: $in_svg"

# Create all PNG files.
#
for size in "${png_sizes[@]}"
do
    out_png=${in_basename}_${size}x${size}.png
    make_png "$in_svg" "$out_png" $size
    echo "Generated $out_png"
done

# Sharpen the smaller PNG icon sizes.
#
for size in "${png_sizes_sharpen[@]}"
do
    out_png=${in_basename}_${size}x${size}.png
    sharpen_png "$out_png"
    echo "Sharpened $out_png"
done

# Create the ICO by converting PNGs to BMPs, calling ImageMagick,
# then deleting the BMPs.
#
# Note how we only apply -colors 256 to the smaller sizes, to prevent
# degrading the high-res PNG icon.
#
# Also note that we order them from higher-res to lower-res in the *.ico, which
# leads to better previews in some systems, and seems preferable.
#
ico_pngs=()
for size in "${ico_png_sizes[@]}"
do
    ico_png=${in_basename}_${size}x${size}.png
    ico_pngs=( "${ico_pngs[@]}" "$ico_png" )
done
ico_bmps=()
for size in "${ico_bmp_sizes[@]}"
do
    ico_png=${in_basename}_${size}x${size}.png
    ico_bmp=${in_basename}_${size}x${size}.bmp
    ico_bmps=( "${ico_bmps[@]}" "$ico_bmp" )
    make_bmp "$ico_png" "$ico_bmp"
done
out_ico=${in_basename}.ico
convert "${ico_pngs[@]}" "${ico_bmps[@]}" "$out_ico"
rm "${ico_bmps[@]}"
echo "Generated $out_ico"

# Create the ICNS by copying PNGs to a temporary folder, calling iconutil,
# then deleting the folder.
#
icns_dir=${in_basename}.iconset
mkdir "$icns_dir"
for size in "${icns_sizes[@]}"
do
    in_png=${in_basename}_${size}x${size}.png
    out_png=${icns_dir}/icon_${size}x${size}.png
    size_2x=$(( 2 * size ))
    in_png_2x=${in_basename}_${size_2x}x${size_2x}.png
    out_png_2x=${icns_dir}/icon_${size}x${size}@2x.png
    cp "$in_png" "$out_png"
    cp "$in_png_2x" "$out_png_2x"
done
iconutil -c icns "$icns_dir"
rm -r "$icns_dir"
echo "Generated ${in_basename}.icns"
