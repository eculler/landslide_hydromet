#!/bin/bash
# Set the source data path
PRECIPNAME="$1"
LOGLEVEL=${log:-info}
PCPDIR="/hydromet/data/precip/"
case $PRECIPNAME in
  nldas)
    PRECIP="$PCPDIR/NLDAS2/NLDAS_FORA0125_H.A*.*.002.grb.SUB.nc4"
    ;;
  imergf)
    PRECIP="$PCPDIR/IMERG.final/3B-HHR.MS.MRG.3IMERG.*-S*00-E005959.0030.V06B.HDF5.nc4"
    ;;
  imerge)
    PRECIP="$PCPDIR/IMERG.early/3B-HHR-E.MS.MRG.3IMERG.*-S*00-E085959.0510.V06B.HDF5.nc4"
    ;;
  mrms)
    PRECIP="$PCPDIR/MRMS/"
    ;;

# Build container
cd ~/Documents/research/hydromet && \
  docker build --tag=hydromet ~/Documents/research/hydromet

# Start container
INDATADIR="~/GoogleDrive/research/landslide.precipitation/data"
OUTPATH="/hydromet/data/precip/landslide_precipitation_$PRECIPNAME.csv"
SLIDEPATH="/hydromet/data/landslide/Landslide_List.csv"
docker run --rm -it \
  --security-opt seccomp=unconfined \
  # Landslide data
  -v $INDATADIR/landslide:/hydromet/data/landslide \
  # Precipitation data
  -v /mnt/wddata/data/by.project/landslide.precipitation:/hydromet/data/precip \
  # Processing code
  -v ~/Documents/research/landslide_hydromet/preprocessing/src:/hydromet/src \
  # Output directory
  -v $INDATADIR/precipitation:/hydromet/out
  -t hydromet:latest \
  conda run -n hydromet \
  python -m /hydromet/src/landslide_precip.py \
  $PRECIPPATH $SLIDEPATH $OUTPATH $LOGLEVEL
