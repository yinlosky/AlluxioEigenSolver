#!/bin/bash
# This script will store the data from Accumulo table to TFS.
# the input matrix using $1 machines; $2 processors in the cluster;
cd /home/yhuang9/my_workspace/AlluxioEigenSolver;
matlab -nodesktop -nosplash -r "ParallelstoreDataToTFS($1,$2); exit;";
