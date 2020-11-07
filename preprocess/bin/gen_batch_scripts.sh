#!/bin/bash
PRECIPNAME="$1"
LOGLEVEL=info
TEMPLATE="$2"
LON_NAME=lon
LAT_NAME=lat
TIME_NAME=time
PRECIPCRS='EPSG:4326'
ENGINE=netcdf4

# Configure paths
WORKDIR=/projects/elcu4811/landslide.hydromet/landslide.hydromet.git/preprocess
DATADIR=/scratch/summit/elcu4811/landslide.hydromet.data
OUTDIR=/projects/elcu4811/landslide.hydromet/landslide.hydromet.out/$PRECIPNAME
SRCDIR=${WORKDIR}/src
BATCHDIR=${SRCDIR}/batch
if [ $TEMPLATE == "test" ]
then
  TEMPLATE_PATH="batch_template_test.txt"
  MONTH=10
  STARTYEAR=2018
  ENDYEAR=2018
else
  TEMPLATE_PATH="batch_template.txt"
  MONTH=""
  STARTYEAR=2014
  ENDYEAR=2020
fi
mkdir -p $WORKDIR $OUTDIR $BATCHDIR

# Make batch script for each year
for ((YEAR=STARTYEAR; YEAR<=ENDYEAR; YEAR++)); do

BATCHPATH=${BATCHDIR}/${PRECIPNAME}.${TEMPLATE}.${YEAR}.batch
case ${PRECIPNAME} in
  nldas)
    PRECIP="precipitation/NLDAS2/NLDAS_FORA0125_H.A${YEAR}${MONTH}\*.\*.002.grb.SUB.nc4"
    PRECIP_NAME=APCP
    ;;
  imergf)
    PRECIP="precipitation/IMERGF/${YEAR}/3B-HHR.MS.MRG.3IMERG.${YEAR}${MONTH}\*-S\*.nc4"
    PRECIP_NAME=precipitationCal
    ;;
  imerge)
    PRECIP="precipitation/IMERGE/${YEAR}/3B-HHR-E.MS.MRG.3IMERG.${YEAR}${MONTH}\*-S\*.nc4"
    PRECIP_NAME=precipitationCal
    ;;
  mrms)
    PRECIP="precipitation/MRMS/GaugeCorr_QPE_01H_00.00_${YEAR}${MONTH}\*-\*.nc"
    PRECIP_NAME=precip
    ;;
  hrrr)
    PRECIP="precipitation/HRRR/${YEAR}/${YEAR}${MONTH}\*/hrrrx_qpf_${YEAR}\*.grib2"
    PRECIP_NAME="Total_precipitation_surface_Mixed_intervals_Accumulation"
    ENGINE="pynio"
    PRECIPCRS="+proj=lcc +lat_1=38.5 +lat_2=38.5 +lat_0=38.5 +lon_0=262.5 +x_0=0 +y_0=0 +a=6371229 +b=6371229 +units=m +no_defs"
    LON_NAME="x"
    LAT_NAME="y"
esac

# Initialize file
echo $BATCHPATH
cp ${SRCDIR}/${TEMPLATE_PATH} ${BATCHPATH}

# Write command to start container, run python script
cat >> ${BATCHPATH} << EOL
singularity run --bind /scratch/summit ${WORKDIR}/hydrological.processes.202011.sif bash -c \\
  'conda activate hydrometenv && python ${SRCDIR}/landslide_precip.py ${DATADIR}/${PRECIP} ${DATADIR}/landslide/landslides.csv ${OUTDIR}/${PRECIPNAME}.${YEAR}.csv ${LON_NAME} ${LAT_NAME} ${PRECIP_NAME} ${TIME_NAME} ${ENGINE} "${PRECIPCRS}" ${LOGLEVEL}'
EOL

done
