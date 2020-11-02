#!/bin/bash
PRECIPNAME="$1"
LOGLEVEL=info
TEMPLATE="$2"
LON_NAME=lon
LAT_NAME=lat
TIME_NAME=time

# Configure paths
WORKDIR=/projects/elcu4811/landslide.hydromet/landslide.hydromet.git
DATADIR=/scratch/summit/elcu4811/landslide.hydromet.data
OUTDIR=/projects/elcu4811/landslide.hydromet/landslide.hydromet.out/$PRECIPNAME
SRCDIR=${WORKDIR}/preprocess/src
BATCHDIR=${OUTDIR}/batch
if [TEMPLATE==test]
  TEMPLATE="batch_template_test.txt"
else
  TEMPLATE="batch_template.txt"
fi
mkdir -p $WORKDIR $DATADIR $OUTDIR $SRCDIR $BATCHDIR

# Make batch script for each year
for YEAR in {2014..2020}; do

BATCHPATH=${BATCHDIR}/${PRECIPNAME}.${YEAR}.batch
case ${PRECIPNAME} in
  nldas)
    PRECIP="precipitation/NLDAS2/NLDAS_FORA0125_H.A${YEAR}\*.\*.002.grb.SUB.nc4"
    PRECIP_NAME=APCP
    ;;
  imergf)
    PRECIP="precipitation/IMERG.final/3B-HHR.MS.MRG.3IMERG.${YEAR}\*-S\*.nc4"
    PRECIP_NAME=precipitationCal
    ;;
  imerge)
    PRECIP="precipitation/IMERG.early/3B-HHR-E.MS.MRG.3IMERG.${YEAR}\*-S\*.nc4"
    PRECIP_NAME=precipitationCal
    ;;
  mrms)
    PRECIP="precipitation/MRMS/"
    PRECIP_NAME=precip
    ;;
esac

# Initialize file
cp ${WORKDIR}/preprocess/bin/${TEMPLATE} ${BATCHPATH}

# Write command to start container, run python script
cat >> ${BATCHPATH} << EOL
singularity exec ${WORKDIR}/hydrological.processes.202011.img \\
  conda run -n hydrometenv \\
  python ${SRCDIR}/landslide_precip.py \\
  ${DATADIR}/${PRECIP} \\
  ${DATADIR}/landslide/landslides.csv \\
  ${OUTDIR}/${PRECIPNAME}.${YEAR}.csv \\
  ${LON_NAME} ${LAT_NAME} ${PRECIP_NAME} ${TIME_NAME} \\
  ${LOGLEVEL}
EOL

done
