from scipy.spatial import cKDTree
import concurrent.futures
import dask
import datetime
import geopandas as gpd
import glob
import logging
import math
import numpy as np
import os
import pandas as pd
import sys
import xarray as xr

def get_precip(precip, group_count, i, count,
               x_name, y_name, precip_name, time_name,
               loc_i, xi, yi):
    slide_precip = precip[{x_name: xi[loc_i], y_name: yi[loc_i]}]

    # To DataFrame
    slide_precip_df = pd.DataFrame(
        {'precipitation': slide_precip[precip_name].values},
        index = slide_precip[time_name].values)

    # Add location identifier to the index
    slide_precip_df['slide.id'] = i
    slide_precip_df = slide_precip_df.set_index(['slide.id'],
                                                append=True)

    # Write to file
    slide_precip_df.to_csv(
        out_path, mode='a', header=(count==1 and group_count==1),
        index_label=('datetime', 'slide.id'))
    logging.debug(slide_precip_df.sort_index().head())
    return

def pull_data(precip_path, landslide_path, out_path,
              lon_name='lon', lat_name='lat',
              precip_name='precipitation', time_name='time',
              engine='netcdf4', slide_crs="EPSG:4326", precip_crs="",
              x_name='xgrid_0', y_name='ygrid_0', to_360=False,
              reproject=False, x_is_lon=True):
    # Log file paths
    logging.info('Landslide data at {}'.format(landslide_path))
    logging.info('Precipitation data at {}'.format(precip_path))
    logging.info('Output file at {}'.format(out_path))
    # Generate landslide locations filename
    out_slide_path = os.path.join(
        os.path.dirname(out_path),
        'landslide.locations.' + os.path.basename(out_path))
    logging.info('Landslide locations at {}'.format(out_slide_path))

    # Make sure that the output directory exists
    if not os.path.exists(os.path.dirname(out_path)):
        raise FileNotFoundError(
            'Directory does not exist: {}'.format(out_path))
    # Make a copy if results already exist
    if os.path.exists(out_path):
        os.rename(out_path, os.path.splitext(out_path)[0] + '.backup.csv')
    if os.path.exists(out_slide_path):
        os.rename(
            out_slide_path, os.path.splitext(out_slide_path)[0] + '.backup.csv')

    # Import landslide data
    logging.info('Importing landslide data from {}'.format(landslide_path))
    slide = pd.read_csv(landslide_path, index_col='slide.id')
    slide = gpd.GeoDataFrame(
        slide, geometry=gpd.points_from_xy(slide.lon, slide.lat),
        crs=slide_crs)

    # Open precipitation dataset
    logging.info('Loading precipitation data...')
    files = glob.glob(precip_path)
    files.sort()
    logging.info('Opening {} precipitation files'.format(len(files)))
    logging.debug('Precipitation file names: \n    ' +
                  '\n    '.join(files[:10]))
    if not files:
        raise ValueError('No files at {}'.format(precip_path))

    precip_groups = []
    ngroups = 2
    group_size = math.ceil(len(files) / ngroups)
    group_start = 0
    for group in range(ngroups):
        # Split precipitation files into n groups
        group_end = min(group_start + group_size, len(files))
        file_group = files[group_start:group_end]
        group_start = group_end

        # Open group files
        precip_group = xr.open_mfdataset(
            file_group, engine=engine,
            combine='nested', concat_dim=time_name,
            data_vars='minimal', coords='minimal', compat='override',
            parallel=False)

        # Modify coordinates to wrap
        if to_360:
            precip_group[lon_name] = precip_group[lon_name] - 360
            #precip_group = precip_group.isel(step=0)

        logging.debug(precip_group)
        logging.debug(precip_group.time)

        precip_groups.append(precip_group)

    # Reproject landslide data to match precipitation data
    if reproject:
        slide = slide.to_crs(precip_crs)

    # Build KD-Tree
    precip_example = precip_groups[0]
    logging.info('Building KD-Tree...')
    if x_is_lon:
        xv, yv = np.meshgrid(precip_example[lon_name].values,
                             precip_example[lat_name].values)
        xi, yi = np.indices((precip_example.sizes[lon_name],
                             precip_example.sizes[lat_name]))
    else:
        xv = precip_example[lon_name].values
        yv = precip_example[lat_name].values
        xi, yi = np.indices((precip_example.sizes[x_name],
                             precip_example.sizes[y_name]))

    xv = xv.flatten()
    yv = yv.flatten()
    xi = xi.flatten('F')
    yi = yi.flatten('F')
    kdt = cKDTree(np.dstack((xv, yv))[0])

    # Pull data for landslide locations
    count=1
    with concurrent.futures.ProcessPoolExecutor() as pool:
        for i, row in slide.iterrows():
            logging.info('Processing landslide {}, id {}'.format(count, i))

            # Skip out-of-bounds landslides
            if (row.lon > np.amax(precip_example[lon_name].values) or
                row.lon < np.amin(precip_example[lon_name].values) or
                row.lat > np.amax(precip_example[lat_name].values) or
                row.lat < np.amin(precip_example[lat_name].values)):
                count +=1
                logging.info('Landslide out of bounds')
                logging.info('Location: {}, {}'.format(row.lon, row.lat))
                continue

            # Find index of closest location
            loc_i = kdt.query((row.lon, row.lat))[1]
            logging.debug('Location index: {}'.format(loc_i))
            logging.info('Location: {}, {}'.format(row.lon, row.lat))
            logging.info('Closest cell: {}, {}'.format(xv[loc_i], yv[loc_i]))
            logging.debug('Closest index: {}, {}'.format(xi[loc_i], yi[loc_i]))
            pd.DataFrame(
                {'lat': [row.lat], 'lon': [row.lon], 'kdt': [loc_i],
                 'closest_lat': [yv[loc_i]], 'closest_lon': [xv[loc_i]],
                 'closest_lat_i': [yi[loc_i]], 'closest_lon_i': [xi[loc_i]]},
                index = [i]
            ).to_csv(out_slide_path, mode='a', header=count==1,
                     index_label='id')

            # Pull precipitation data
            group_count = range(1, ngroups + 1)
            get_slide_precip = lambda precip, group_count: get_precip(
                precip, group_count, i, count,
                x_name, y_name, precip_name, time_name,
                loc_i, xi, yi)
            pool.map(get_slide_precip, precip_groups, group_count)

            count += 1

if __name__ == '__main__':
    # Get command line arguments
    precip_path, landslide_path, out_path = sys.argv[1:4]
    lon_name, lat_name, precip_name, time_name, x_name, y_name = sys.argv[4:10]
    to_360, engine, precip_crs = sys.argv[10:13]
    to_360 = True if to_360=='true' else False
    log_level = sys.argv[13]
    log_level = getattr(logging, log_level.upper())

    # Initialize logging
    now = datetime.datetime.now().strftime('%Y%m%d%H%M')
    log_path = os.path.join(
        os.path.dirname(out_path), 'log', 'preprocess{}.log'.format(now))
    if not os.path.exists(os.path.dirname(log_path)):
        os.mkdir(os.path.dirname(log_path))
    file_handler = logging.FileHandler(filename=log_path)
    stdout_handler = logging.StreamHandler(sys.stdout)
    logging.basicConfig(
        handlers=[stdout_handler, file_handler],
        level=log_level,
        format='%(asctime)s %(message)s')

    logging.debug('Precipitation path: {}'.format(precip_path))
    logging.debug('Landslide path: {}'.format(landslide_path))
    logging.debug('Output path: {}'.format(out_path))
    logging.debug('Variable names: x - {}, y - {}, t = {}, P = {}'.format(
                      lon_name, lat_name, time_name, precip_name))
    logging.debug('Precipitation file engine: {}'.format(engine))
    logging.debug('Precipitation CRS: {}'.format(precip_crs))

    # Run data processing
    with dask.config.set(scheduler='threads'):
        pull_data(precip_path=precip_path,
                  landslide_path=landslide_path,
                  out_path=out_path,
                  lon_name=lon_name,
                  lat_name=lat_name,
                  precip_name=precip_name,
                  time_name=time_name,
                  x_name=x_name,
                  y_name=y_name,
                  to_360=to_360,
                  engine=engine,
                  precip_crs=precip_crs)
