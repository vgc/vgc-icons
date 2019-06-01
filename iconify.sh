#!/bin/bash
#
# Usage:
#   iconify.sh myicon.svg
#

# Specifies which image sizes we should generate. These must be ordered from
# largest to smallest.
#
png_sizes=(256)
bmp_sizes=(48 32 24 16)

# Useful variables
#
in_svg=$1
in_basename=${in_svg%.*}
out_pngs=()
out_bmps=()
out_ico=$in_basename.ico

# Create a PNG from a SVG using Inkscape.
#
make_png () {
    in_svg=$1
    out_png=$2
    size=$3
    inkscape -z -e "$out_png" -w $size -h $size "$in_svg" >/dev/null 2>/dev/null
}

# Applies sharpening using Gimp
#
sharpen_png () {
    png=$1
    gimp -i -b "
      (define
        (vgc-sharpen filename radius amount threshold)
        (let*
          ((image (car (gimp-file-load RUN-NONINTERACTIVE filename filename)))
           (drawable (car (gimp-image-get-active-layer image))))
          (plug-in-unsharp-mask RUN-NONINTERACTIVE image drawable radius amount threshold)
          (gimp-file-save RUN-NONINTERACTIVE image drawable filename filename)
          (gimp-image-delete image)))
      (vgc-sharpen \"$png\" 5.0 0.30 0)
      (gimp-quit 0)"
}

# Create a BMP from a PNG using ImageMagick.
#
make_bmp () {
    in_png=$1
    out_bmp=$2
    convert "$in_png" -depth 8 -colors 256 "$out_bmp"
}

# Create all temporary PNGs.
#
for size in "${png_sizes[@]}"
do
    out_png=$in_basename.$size.png
    out_pngs=( "${out_pngs[@]}" "$out_png" )
    make_png "$in_svg" "$out_png" $size
done

# Create all temporary BMPs.
#
for size in "${bmp_sizes[@]}"
do
    out_png=$in_basename.$size.png
    out_bmp=$in_basename.$size.bmp
    out_bmps=( "${out_bmps[@]}" "$out_bmp" )
    make_png "$in_svg" "$out_png" $size
    sharpen_png "$out_png"
    make_bmp "$out_png" "$out_bmp"
done

# Compile all the generated PNGs and BMPs into one .ico file. Note how we only
# apply -colors 256 to the smaller sizes, to prevent degrading the high-res PNG
# icon.
#
# Also note that we order them from higher-res to lower-res in the *.ico, which
# leads to better previews in some systems, and seems preferable.
#
convert "${out_pngs[@]}" "${out_bmps[@]}" "$out_ico"

# Remove all temporary PNGs.
#
for size in "${png_sizes[@]}"
do
    out_png=$in_basename.$size.png
    rm "$out_png"
done

# Remove all temporary BMPs.
#
for size in "${bmp_sizes[@]}"
do
    out_png=$in_basename.$size.png
    out_bmp=$in_basename.$size.bmp
    rm "$out_png" "$out_bmp"
done
