#!/bin/sh
set -x
dmd -debug -g -gf -gs -m64 obsidion.d
rm *.o
