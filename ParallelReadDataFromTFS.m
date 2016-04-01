function ParallelReadDataFromTFS(NumOfMachines, NumOfProcessors, MyIteration)
%% This function is used as a helper function to actually read the data from TFS
%% Author: Yin Huang

%% This helper function run parallel reading MyIteration times and save the result in 
%% the table: time_statistics_numofnodes_np_{max_iteration}

%% Initialize the following table for parallelReading.m: 
%%  1. max_iteration which stores the value of MyIteration
%%  2. time_statistics_numofnodes_numOfMachines_np_{max_iteration}
%%
myDB;

machines_t = DB('NumOfMachines');
put(machines_t, Assoc('1,','1,',sprintf('%d,', NumOfMachines)));

%% Get the total number of machines and nodes
%% get the number of nodes which is the dimension of the input  matrix
nodes_t = DB('Scale');
NumOfNodes = 2^str2num(Val(nodes_t('1,','1,')));

%% store the number of iteration
numberOfIteration_t = DB('max_iteration');
put(numberOfIteration_t, Assoc('1,','1,',sprintf('%d,',MyIteration)));


% Creating max_iteration number of statistic tables to store the running time for each iteration for all processes
%result_t = DB(['time_statistics_' num2str(NumOfNodes) '_' num2str(numOfMachines) '_' num2str(Np) '_' num2str(1:MyIteration)]);
numArr = cell(1, MyIteration);
for i = 1: MyIteration
	numArr{i} = DB(['time_statistics_' num2str(NumOfNodes) '_' num2str(NumOfMachines) '_' num2str(Np) '_' num2str(i)]);
end
%% pre set all the result tables

switch NumOfMachines
        case 1
                machines = {};
        case 2
                machines={'n117' 'n118'};
        case 3
                machines = {'n117' 'n118' 'n119' }
        case 4
                machines = {'n117' 'n118' 'n119' 'n120'  }
        case 5
                machines = {'n117' 'n118' 'n119' 'n120'  'n121' }
        case 6
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122' }
        case 7
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'}
        case 8
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'}
        case 9
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125' }
        case 10
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126' }
        case 11
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127' }
        case 12
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128' }
        case 13
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  }
        case 14
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'}
        case 15
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'  'n131'}
        case 16
                machines = {'n117' 'n118' 'n119' 'n120'  'n121'  'n122'  'n123'  'n124'  'n125'  'n126'  'n127'  'n128'  'n129'  'n130'  'n131'  'n132' }
end
 
%% actually parallel read the files from TFS
disp(['Start parallel computaion part']);
eval(pRUN('parallelReading', NumOfProcessors, machines));
disp(['Done!']);

