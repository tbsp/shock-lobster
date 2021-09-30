#!/usr/bin/env python3

#
# Pearl sequence packer for Shock Lobster
#
# Copyright 2021 Dave VanEe
#
# This software is provided 'as-is', without any express or implied
# warranty.  In no event will the authors be held liable for any damages
# arising from the use of this software.
# 
# Permission is granted to anyone to use this software for any purpose,
# including commercial applications, and to alter it and redistribute it
# freely, subject to the following restrictions:
# 
# 1. The origin of this software must not be misrepresented; you must not
#    claim that you wrote the original software. If you use this software
#    in a product, an acknowledgment in the product documentation would be
#    appreciated but is not required.
# 2. Altered source versions must be plainly marked as such, and must not be
#    misrepresented as being the original software.
# 3. This notice may not be removed or altered from any source distribution.
#

from PIL import Image
from sys import argv,stderr


assert len(argv) > 2, "Usage:\n\t{} input_file output_file".format(argv[0])

SEQUENCE_HEIGHT = 6

with Image.open(argv[1]) as img:
    bg_color   = img.getpixel((0, 0))
    fg_color   = img.getpixel((1, 0))

    width, height = img.size
    assert SEQUENCE_HEIGHT + 1 == height, f"The source image's height must be {SEQUENCE_HEIGHT}, plus 1!"

    data = []

    for x in range(0, width):
        byte = 0
        for y in range(1, height):
            pixel = img.getpixel((x, y))
            if pixel == fg_color:
                byte |= 0x80
            byte = byte >> 1
        byte = byte >> 1
        data.append(byte)

    data.append(0x80)

with open(argv[2], "wb") as output:
    output.write(bytes(data))
