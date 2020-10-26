import datetime
import logging
import netCDF4 as nc4
import numpy as np
import ogr, osr
import os
import pandas as pd
import shutil
import sys
import xarray as xr
import yaml






def pull_data(landslide_path, precip_path, out_path):
    # Log file paths
    logging.info('Landslide data at {}'.format(landslide_path))
    logging.info('Precipitation data at {}'.format(precip_path))
    logging.info('Output file at {}'.format(out_path))

    # Make sure that the output directory exists
    if not os.path.exists(os.path.dirname(out_path)):
        raise FileNotFoundError(
            'Directory does not exist: {}'.format(out_path))
    # Make a copy if results already exist
    if os.path.exists(out_path):
        os.rename(out_path, os.path.splitext(out_path)[0] + 'backup.csv')

    # Import landslide data
    slide = pd.read_csv(landslide_path, index_col='ID')
    
    # Open precipitation dataset
    logging.info('Loading precipitation data...')
    files = glob.glob(precip_fn)
    files.sort()
    logging.info('Opening {} precipitation files'.format(len(files)))
    logging.debug('Precipitation file names: \n' +
                  '\n    '.join(files))
    precip_ds = xr.open_mfdataset(
        files,
        combine='nested', concat_dim='time', coords='minimal',
        chunks={'latitude': 10, 'longitude': 10})

    # Build KD-Tree
    logging.info('Building KD-Tree...')
    xv, yv = np.meshgrid(precip.lon.values, precip.lat.values)
    xv = xv.flatten()
    yv = yv.flatten()
    xi, yi = np.indices((precip.sizes['lon'], precip.sizes['lat']))
    xi = xi.flatten('F')
    yi = yi.flatten('F')

    kdt = cKDTree(np.dstack((xv, yv))[0])

    # Pull data for landslide locations
    count=1
    for i, row in slide.iterrows():
        logging.info('Processing landslide {}, {}'.format(count, row['ID']))

        slide_precip = precip_ds.sel(
            x=slide_x, y=slide_y, method='nearest')
        total = 1.

        # Find index of closest location
        loc_i = kdt.query((row.lon, row.lat))[1]
        logging.debug('Location index: {}'.format(loc_i))
        logging.debug('Location: {}, {}'.format(row.lon, row.lat))
        logging.debug('Closest cell: {}, {}'.format(xv[loc_i], yv[loc_i]))
        logging.debug('Closest index: {}, {}'.format(xi[loc_i], yi[loc_i]))

        # Pull precipitation data
        slide_precip = precip.sel(lon = xv[loc_i], lat = yv[loc_i])

        # To DataFrame
        slide_precip = event_precip.chunk({'time': 'auto'})
        slide_precip = pd.DataFrame(
            {'precip': slide_precip.precip.values},
            index = slide_precip.time.values)

        # Add location identifier to the index
        event_precip['id'] = i
        event_precip = event_precip.set_index(['id'], append=True)

        # Write to file
        event_dfs.to_csv(out_path, mode='a', header=count==1)
        logging.debug(event_precip.sort_index().head())
        count += 1

if __name__ == '__main__':
    # Initialize logging to a file (so it will be available outside container)
    log_level = getattr(logging, sys.argv[4].upper())
    now = datetime.datetime.now().strftime('%Y%m%d%H%M')
    log_path = os.path.join(
        os.path.dirname(out_path), 'preprocess{}.log'.format(now))
    logging.basicConfig(
        filename=log_path, filemode='w',
        level=log_level,
        format='%(asctime)s %(message)s')

    # Run data processing
    pull_data(precip_path=sys.argv[1],
              landslide_path=sys.argv[2],
              out_path=sys.argv[3])
