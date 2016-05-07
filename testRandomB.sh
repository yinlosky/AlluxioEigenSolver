#!/bin/bash
# parameter: 
# 1. 1 for test otherwise 0
# 2. NumOfprocessors
# 3. NumOfMachines
#testOrNot = $1;
#NumOfNodes = $2;
#NumOfProc = $3;
#NumOfMachines = $4;
matlab -nodesktop -nosplash -r "myDB; test_flag_t = DB('testVector'); test_nodes_t = DB('testNodes'); test_proc_t = DB('testProc'); put(test_flag_t,Assoc('1,','1,',sprintf('%d,', $1)));  put(test_nodes_t,Assoc('1,','1,',sprintf('%d,',$2))); put(test_proc_t,Assoc('1,','1,',sprintf('%d,',$3))); eval(pRUN('buildRandomVectorB', $3, getMachines($4)));"