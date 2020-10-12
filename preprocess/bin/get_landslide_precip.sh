#!/bin/bash
WORKDIR="~/Documents/research/landslide_hydromet/preprocess"
EXTDIR="/Volumes/WD-Data/data/by.project/landslide.precipitation"
cd $WORKDIR && docker build --tag=hydromet $WORKDIR
docker run --rm -it \
  --security-opt seccomp=unconfined \
  -v $WORKDIR/data/landslide:/hydromet/data/landslide \ # Link landslide data
  -v $EXTDIR:/hydromet/data/precipitation \ # Link precipitation raw data
  -v $WORKDIR/data/precipitation:/hydromet/data/out \   # Link output directory
  -t hydromet:latest \ # Tag docker build
  conda run -n hydromet python get_landslide_precip.py # Run script in conda env
