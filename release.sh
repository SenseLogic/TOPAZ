#!/bin/sh
set -x
dmd -O -m64 topaz.d
rm *.o
