%function SaveGraphData(SCALE,EdgesPerVertex,MatrixName,MachineNum)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generate a Kronecker graph and save to data files.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                  % Turn off echoing.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%1

myDB;

machines_t = DB('init_NumOfMachines');
NumOfMachines = str2num(Val(machines_t(:,:)));
nodes_t = DB('init_NumOfNodes');
NumOfNodes = str2num(Val(nodes_t(:,:)));
proc_t=DB('init_NumOfProcessors');
NumOfProcessors = str2num(Val(proc_t(:,:)));
initM_edges_t  = DB('init_edges');
EdgesPerVertex = str2num(Val(initM_edges_t(:,:)));
iteration_num_t = DB('iteration_num_t');
iteration_number = str2num(Val(iteration_num_t(:,:)));

matrix_t = DB(['M' num2str(NumOfNodes)]);

%Nfile = NumOfMachines;

%%%%%%%%%%%%%%%%%%%%%%%%% Remove old table %%%%%%%%%%%%%%%%%%%%%%%%
%myMatrix = DB([MatrixName]);
%delete(myMatrix);       
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%SCALE = 22;   EdgesPerVertex = 16;               % Set algorithm inputs.
%SCALE = 18;   EdgesPerVertex = 16;               % Set algorithm inputs.

Nmax = NumOfNodes;                                 % Max vertex ID.
M = EdgesPerVertex .* Nmax;                      % Total number of edges.

                                      % Set the number of files to save to.

%myFiles = 1:Nfile;                               % Set list of files.
w = zeros(Np,1,map([Np 1],{},0:Np-1));
myFiles = global_ind(w);   % PARALLEL.

chunksize = 62500
for i = myFiles
    
    if(i>1)
    %rand('seed',i);                              % Set random seed to be unique for this file.
    [v1,v2] = SymKronGraph500NoPerm(NumOfNodes,EdgesPerVertex./((Np-1)*4),i,iteration_number);       % Generate data.
    disp('Now start inserting the data!');
    
    totalNum = size(v1,1);
    insert_step = floor(totalNum / chunksize);
    
    for index=1:insert_step
        if index == insert_step
            readv1 = v1((index-1)*chunksize+1:totalNum);
            readv2 = v2((index-1)*chunksize+1:totalNum);
        else
        readv1 = v1((index-1)*chunksize+1:index*chunksize);
        readv2 = v2((index-1)*chunksize+1:index*chunksize);
        end
        put(matrix_t,Assoc(sprintf('%d,',readv1),sprintf('%d,',readv2),'1,',@min));
    end
    
    
    disp('Insertion done!');
    else 
        disp(['This is leader process, I am just waiting!']);
    end
end
agg(w);
