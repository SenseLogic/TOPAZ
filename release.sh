#!/bin/sh
set -x
dmd -O -m64 obsidion.d
rm *.o
