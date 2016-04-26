function [ output_args ] = initMatrix( NumOfMachines, NumOfNodes, NumOfProcessors,EdgesPerVertex )
%UNTITLED2 Summary of this function goes here
%   Detailed explanation goes here

myDB;

machines_t = DB('init_NumOfMachines');
put(machines_t, Assoc('1,','1,',sprintf('%d,',NumOfMachines)));

nodes_t = DB('init_NumOfNodes');
put(nodes_t, Assoc('1,','1,',sprintf('%d,',NumOfNodes)));

proc_t=DB('init_NumOfProcessors');
put(proc_t, Assoc('1,','1,',sprintf('%d,',NumOfProcessors)));

initM_edges_t  = DB('init_edges');
put(initM_edges_t, Assoc('1,','1,',sprintf('%d,',EdgesPerVertex)));

machines = getMachines(NumOfMachines);

iteration_number = EdgesPerVertex/25;

iteration_num_t = DB('iteration_num_t');


for i = 1:1:iteration_number
    put(iteration_num_t, Assoc('1,','1,',sprintf('%d,',i)));
disp(['Round ' num2str(i) ' initializing the input matrix in ' 'M' num2str(NumOfNodes)]);

this = tic; eval(pRUN('MySaveGraphData',NumOfProcessors, machines)); total_time = toc(this);

disp(['Total time to initialize M' num2str(NumOfNodes) ' is ' num2str(total_time)]);
end

delete(iteration_num_t);

end

