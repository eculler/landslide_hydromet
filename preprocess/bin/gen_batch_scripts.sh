#!/opt/local/bin/bash
# Configure paths
WORKDIR=../.. #projects/elcu4811/landslide.hydromet
DATADIR=scratch/summit/elcu4811/landslide.hydromet.data
OUTDIR=projects/elcu4811/landslide.hydromet/out
SRCDIR=${WORKDIR}/preprocess/src
BATCHDIR=${OUTDIR}/batch

mkdir -p $WORKDIR $DATADIR $OUTDIR $SRCDIR $BATCHDIR

PRECIPNAME="$1"
LOGLEVEL=info

for YEAR in {2014..2020}; do

BATCHPATH=${BATCHDIR}/${PRECIPNAME}.${YEAR}.batch
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
    PRECIP="precipitation/MRMS.2min/mtarchive.geol.iastate.edu/${YEAR}/\*/\*/mrms/ncep/PrecipRate/"
    ;;
esac

# Initialize file
cp ${WORKDIR}/preprocess/bin/batch_template_test.txt ${BATCHPATH}

# Write command to start container, run python script
cat >> ${BATCHPATH} << EOL
singularity exec ${WORKDIR}/hydromet.img \\
  conda run -n hydrometenv \\
  python ${SRCDIR}/landslide_precip.py \\
  ${DATADIR}/${PRECIP} \\
  ${DATADIR}/landslide/landslides.csv \\
  ${OUTDIR}/${PRECIPNAME}.${YEAR}.csv \\
  ${LOGLEVEL}
EOL

done
