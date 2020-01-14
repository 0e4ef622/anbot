#!/bin/bash

if ! [ -e in ]; then
    mkfifo in;
fi

perl -CSD derp.pl < in & cat > in
