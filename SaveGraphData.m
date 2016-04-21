%function SaveGraphData(SCALE,EdgesPerVertex,MatrixName,MachineNum)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Generate a Kronecker graph and save to data files.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%                  % Turn off echoing.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%1

myDB;

machines_t = DB('NumOfMachines');
NumOfMachines = str2num(Val(machines_t(:,:)));
nodes_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(nodes_t(:,:)));
proc_t=DB('NumOfProcessors');
NumOfProcessors = str2num(Val(proc_t(:,:)));


matrix_t = DB(['M' num2str(NumOfNodes)]);
initM_edges_t  = DB('edges');
EdgesPerVertex = str2num(Val(initM_edges_t(:,:)));

Nfile = NumOfMachines;

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

for i = myFiles
  
    rand('seed',i);                              % Set random seed to be unique for this file.
    [v1,v2] = SymKronGraph500NoPerm(NumOfNodes,EdgesPerVertex./Np);       % Generate data.
 
    rowStr = sprintf('%d,',v1);                                      % Convert to strings.
    colStr = sprintf('%d,',v2);
    %valStr = repmat('1,',1,numel(v1));
     
     %######################################################
    % Open files, write data, and close files.
    %fidRow=fopen([fname 'r.txt'],'w'); fidCol=fopen([fname 'c.txt'],'w'); fidVal =fopen([fname 'v.txt'],'w');
   % fwrite(fidRow,rowStr);             fwrite(fidCol,colStr);             fwrite(fidVal,valStr);
   % fclose(fidRow);                    fclose(fidCol);                    fclose(fidVal);
  %fileTime = toc;  disp(['Time: ' num2str(fileTime) ', Edges/sec: ' num2str(numel(v1)./fileTime)]);
     %########################################################

    A = Assoc(rowStr,colStr,1,@min);
    put(matrix_t,num2str(A));
end
agg(w);
