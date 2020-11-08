#!/opt/local/bin/bash
# Configure paths
LOCALWORKDIR=~/Documents/research/landslide.hydromet.git/preprocess
LOCALDATADIR=/Volumes/WD-Data/data/by.project/landslide.hydromet.data
LOCALOUTDIR=~/GoogleDrive/research/landslide.hydromet.sync/data/
LOCALSRCDIR=${LOCALWORKDIR}/src
DOCKERWORKDIR=/hydromet
DOCKERDATADIR=${DOCKERWORKDIR}/data
DOCKERSRCDIR=${DOCKERWORKDIR}/src
DOCKEROUTDIR=${DOCKERWORKDIR}/out

PRECIPNAME="$1"
LOGLEVEL=debug
LON_NAME=lon
LAT_NAME=lat
TIME_NAME=time
PRECIPCRS='EPSG:4326'
ENGINE=netcdf4

# Build container
#cd ${LOCALWORKDIR} && docker build --tag=hydromet ${LOCALWORKDIR}

for YEAR in {2014..2020}; do
  case ${PRECIPNAME} in
    nldas)
      PRECIP="precipitation/NLDAS2/NLDAS_FORA0125_H.A${YEAR}\*.\*.002.grb.SUB.nc4"
      PRECIP_NAME=APCP
      ;;
    imergf)
      PRECIP="precipitation/IMERGF/${YEAR}/3B-HHR.MS.MRG.3IMERG.${YEAR}\*-S\*.nc4"
      PRECIP_NAME=precipitationCal
      ;;
    imerge)
      PRECIP="precipitation/IMERGE/${YEAR}/3B-HHR-E.MS.MRG.3IMERG.${YEAR}\*-S\*.nc4"
      PRECIP_NAME=precipitationCal
      ;;
    mrms)
      PRECIP="precipitation/MRMS/"
      PRECIP_NAME=precip
      ;;
    hrrr)
      PRECIP="precipitation/HRRR/2019/20190101/hrrrx_qpf_20190101\*.grib2"
      PRECIP_NAME="Total_precipitation_surface_Mixed_intervals_Accumulation"
      ENGINE="pynio"
      PRECIPCRS="+proj=lcc +lat_1=38.5 +lat_2=38.5 +lat_0=38.5 +lon_0=262.5 +x_0=0 +y_0=0 +a=6371229 +b=6371229 +units=m +no_defs"
      LON_NAME="x"
      LAT_NAME="y"
      ;;
  esac

  # Start container, run python script
  set -f && docker run --rm -it \
    --security-opt seccomp=unconfined \
    -v ${LOCALDATADIR}:${DOCKERDATADIR} `# Input data` \
    -v ${LOCALSRCDIR}:${DOCKERSRCDIR} `# Processing code` \
    -v ${LOCALOUTDIR}:${DOCKEROUTDIR} `# Output directory` \
    -t hydromet:latest \
    conda run -n hydrometenv \
    python ${DOCKERSRCDIR}/landslide_precip.py \
    ${DOCKERDATADIR}/${PRECIP} \
    ${DOCKERDATADIR}/landslide/landslides.csv \
    ${DOCKEROUTDIR}/${PRECIPNAME}.${YEAR}.csv \
    ${LON_NAME} \
    ${LAT_NAME} \
    ${PRECIP_NAME} \
    ${TIME_NAME} \
    ${ENGINE} \
    "${PRECIPCRS}" \
    ${LOGLEVEL}
done
