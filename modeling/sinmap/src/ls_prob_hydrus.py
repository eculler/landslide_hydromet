import logging
import yaml
import shutil, os, sys
import numpy as np
import csv
from landlab import RasterModelGrid
from landlab.components.landslides import LandslideProbability


if __name__ == '__main__':
    print(os.listdir('/code/data'))
    for flux_path in os.listdir('/code/data'):
        
        grid = RasterModelGrid((3, 3), 1.0)

        # Add slope to landlab grid
        grid.at_node['topographic__slope'] = np.repeat(0.25, 9)
 
        # Add Contributing Area to Landlab Grid
        grid.at_node[
            'topographic__specific_contributing_area'] = np.repeat(1, 9)


        # Compute Cohesion mode
        # Add Cohesion to Landlab Grid
        grid.at_node['soil__mode_total_cohesion'] = np.repeat(0.001, 9)
        grid.at_node['soil__minimum_total_cohesion'] = np.repeat(0.00099,9)
        grid.at_node['soil__maximum_total_cohesion'] = np.repeat(0.0011, 9)

        # Compute internal friction angle
        # Add internal friction angle to grid
        grid.at_node['soil__internal_friction_angle'] = np.repeat(23, 9)

        # Add soil thickness to grid
        grid.at_node['soil__thickness'] = np.repeat(1, 9)
        grid.at_node['soil__density'] = np.repeat(1 / 9.80665, 9)  

        # Run model
        print('Running Landslide Probability')
        slide_prob = []
        with open('/code/data/' + flux_path, 'r') as flux_file:
            flux = csv.reader(flux_file)
            recharge = [float(row[0]) for row in flux]
            max_recharge = max(recharge)
            print(max_recharge)
            # Add Ksat to Landlab Grid
            grid.at_node['soil__saturated_hydraulic_conductivity'
                             ] = np.repeat(max_recharge / 1000, 9)
            for value in recharge:
                prob_grid = LandslideProbability(
                        grid,
                        number_of_iterations = 1000,
                        groundwater__recharge_min_value = value - 10e-9,
                        groundwater__recharge_max_value = value + 10e-9)
        
                prob_grid.calculate_landslide_probability()

                prob_ar = grid.at_node['landslide__probability_of_failure']
                print(prob_ar)
                slide_prob.append(prob_ar[])
                
        with open('/code/data/' + flux_path + '_LSprob', 'w') as prob_file:
            prob_writer = csv.writer(prob_file)
            for i in range(len(slide_prob)):
                prob_writer.writerow([recharge[i], slide_prob[i]])
                
            

