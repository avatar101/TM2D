#!/bin/bash
#set -x
# Compute the blocks based on the 500-150 hPa vertically averaged potential vorticity (VAPV). The algorithm is very similar to Schwierz et al. (2004). 
# The script contains several parts:
# Definition part: Describes which datasets, define the threshold for the blocking algorithm
# Preprocessing: 
# Compute anomalies
# Compute blocks
# Postprocessing

ulimit -n 2048

declare syear=2018 # First year of dataset (2006 or 2009 for experiments, 1979 for climatologies
declare eyear=2019 # Last year of dataset (2016 for experiments, 2005 for climatologies)

declare preprocess=false
declare runmean=true
declare anom=true                 # true then calculate anomaly
declare precomputedclima=true    # If false, the clima "hour of year" mean is calculated for the dataset
declare anomtype="oFaIsF"       # If precomputedanom is taken, indicate here which one
declare anomsyea=1982 # Start year of ANOMALY (do not mix of syear!)
declare anomeyea=2005 # End year of ANOMALY 
declare tmtrack=true
declare pproc=true

# You may change the thresholds that define a block, normally just leave as is

persistence=20             # Tuning parameter for TM2D: Minimum persistence of blocking
overlap=0.7                # Tuning parameter for TM2D: Minimum overlap between timesteps
vapvmin=-1.3               # Tuning parameter for TM2D: PV minimum threshold

# Programs 
tm2d=/home/mali/workdir/TM2D-master/tm2d

workdir=/home/mali/workdir
cd /home/mali/
data_dir=/scratch3/mali/data/ERA_5/VAPV
#dset=/scratch3/mali/data/ERA_5/VAPV/VAPV_2018.nc

### Get data - extract PV field form model output and make yearly files
if ( ${preprocess} ) then
    echo "Preprocessing of ${dset}: `date +%d:%T.%3N`"
    for year in `seq ${syear} 1 ${eyear}` ; do
        cdo -O mergetime ${data_dir}/${year}/VAPV_${year}* ${data_dir}/APV_${year}.nc
        # cdo -setname,APV -a -O mergetime ${data_dir}/${year}/VAPV_${year}* 
    done
    # cdo merge all yearly files into ${dset}.PV.nc (line80)? Yes
    cdo -a -O mergetime ${data_dir}/APV*.nc ${data_dir}/${syear}_${eyear}_temp.nc
    cdo -sellonlatbox,0,360,-90,90 -setname,APV ${data_dir}/${syear}_${eyear}_temp.nc ${workdir}/PV/${syear}_${eyear}_PV.nc
fi
### Compute anomalies (either take preexisting climatology or derive climatology from data.
### clim.nc is in 0 to 360
if ( ${runmean} ) then
    echo "Running mean ${dset} `date +%d:%T.%3N`"
    if ( ${anom} ) then
        if ( ${precomputedclima} ) then
            # when precomputed anom present pass to it
            ln -s /mnt/climstor/giub/blockings/VAPV/orig/era5/clim.nc ${workdir}/PV/clim.nc
            # touch ${workdir}/PV/PVclim.${anomtype}
        else
        # calc anom when precomputed anom not present
            cdo -O -s runmean,121 -selyear,${syear}/${eyear} ${workdir}/PV/${syear}_${eyear}_PV.nc ${workdir}/PV/PV_rm121.nc
            # year hourly mean
            cdo -s yhourmean -delete,day=29,month=2 ${workdir}/PV/PV_rm121.nc ${workdir}/PV/clim.nc
        fi # if takeeraintanom
        for year in $(seq ${syear} ${eyear}); do
            echo "Calculate anomaly $year : `date +%d:%T.%3N`"
            echo ${year}
            echo ${syear}
            echo ${eyear}
            cdo sub -selyear,$year workdir/PV/${syear}_${eyear}_PV.nc workdir/PV/clim.nc workdir/PV/PV_anom_${year}.nc
            
            #cdo -s sub -selyear,${year} PV/${syear}_${eyear}_PV.nc PV/clim.nc PV/PV_anom_${year}.nc
        done
        cdo -O -s mergetime ${workdir}/PV/PV_anom_*.nc ${workdir}/PV/PV_anom.nc
        cdo -s runmean,9 ${workdir}/PV/PV_anom.nc ${workdir}/PV/PV_rm9.nc
    else
            # Two day running mean  
    cdo -s runmean,9 ${workdir}/PV/${syear}_${eyear}_PV.nc ${workdir}/PV/PV_rm9.nc
    fi # if anom
fi # if runmean


### Track blockings
dataname=${workdir}/blocks/blocks_${dset}.nc
if ( ${tmtrack} ) then
    echo "Track blockings start ${dset}: `date +%d:%T.%3N`"
    ${tm2d} --infile=${workdir}/PV/PV_rm9.nc --invar=APV --outfile=${dataname} --mode=VAPV --persistence=${persistence} --overlap=${overlap} --vapvmin=${vapvmin}
    mv blockstat.txt ${workdir}/blocks/blockstat.txt
    mv blocktracks.txt ${workdir}/blocks/blocktracks.txt
    mv blockstat_all.txt ${workdir}/blocks/blockstat_all.txt
    mv blocktracks_all.txt ${workdir}/blocks/blocktracks_all.txt
fi # if ttruek

          
