#!/bin/sh
set -x
dmd -m64 obsidion.d
rm *.o
