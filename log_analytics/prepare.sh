#!/bin/bash

. env.sh

cat Makefile.in | sed -e "s%@pmix_base_path@%$PMIX_BASE%g" > Makefile
