#!/bin/sh
set -x
dmd -debug -g -gf -gs -m64 topaz.d
rm *.o
