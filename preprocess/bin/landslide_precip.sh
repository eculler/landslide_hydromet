#!/opt/local/bin/bash
# Configure paths
LOCALWORKDIR=~/Documents/research/landslide.hydromet.git/preprocess
LOCALDATADIR=/Volumes/WD-Data/data/by.project/landslide.hydromet.data
LOCALOUTDIR=~/GoogleDrive/research/landslide.hydromet.sync/data/precipitation
LOCALSRCDIR=${LOCALWORKDIR}/src
DOCKERWORKDIR=/hydromet
DOCKERDATADIR=${DOCKERWORKDIR}/data
DOCKERSRCDIR=${DOCKERWORKDIR}/src
DOCKEROUTDIR=${DOCKERWORKDIR}/out

PRECIPNAME="$1"
LOGLEVEL=debug

# Build container
cd ${LOCALWORKDIR} && docker build --tag=hydromet ${LOCALWORKDIR}

for YEAR in {2014..2020}; do
  case ${PRECIPNAME} in
    nldas)
      PRECIP="precipitation/NLDAS2/NLDAS_FORA0125_H.A${YEAR}\*.\*.002.grb.SUB.nc4"
      ;;
    imergf)
      PRECIP="precipitation/IMERG.final/3B-HHR.MS.MRG.3IMERG.${YEAR}\*-S\*00-E005959.0030.V06B.HDF5.nc4"
      ;;
    imerge)
      PRECIP="precipitation/IMERG.early/3B-HHR-E.MS.MRG.3IMERG.${YEAR}\*-S\*00-E085959.0510.V06B.HDF5.nc4"
      ;;
    mrms)
      PRECIP="precipitation/MRMS/"
      ;;
  esac

  # Start container, run python script
  set -f && docker run --rm -it \
    --security-opt seccomp=unconfined \
    -v ${LOCALDATADIR}:${DOCKERDATADIR} `# Input data` \
    -v ${LOCALSRCDIR}:${DOCKERSRCDIR} `# Processing code` \
    -v $LOCALOUTDIR:${DOCKEROUTDIR} `# Output directory` \
    -t hydromet:latest \
    conda run -n hydrometenv \
    python ${DOCKERSRCDIR}/landslide_precip.py \
    ${DOCKERDATADIR}/${PRECIP} \
    ${DOCKERDATADIR}/landslide/landslides.csv \
    ${DOCKEROUTDIR}/${PRECIPNAME}.${YEAR}.csv \
    ${LOGLEVEL}
done
