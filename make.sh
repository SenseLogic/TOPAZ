#!/bin/sh
set -x
dmd -m64 topaz.d
rm *.o
