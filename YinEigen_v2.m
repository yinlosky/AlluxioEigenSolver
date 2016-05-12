function YinEigen_v2(NumOfMach,  NumOfProcs, NumOfNod, initMat, EdgesPerVer, max_it, eig_k, KeepB, Run_schedule, StoreTFS, StoreLHD, TFS)
%%
%% Usage: This function is used for calculating the eigen values and eigen vectors for input symmetric matrix 
%% with the size of NumOfNodes using Alluxio in-memory file system to store the input matrix 
%%     Input: 1.NumOfMachines is the number of machines to be running in the cluster (16)
%%            2.NumOfProcessors is the number of processes to be running in the cluster (32)
%%            3.NumOfNodes is the matrix dimension (2^18)
%%	      4.initMat is set to initialize the matrix or not typically (0)
%%	      5.EdgesPerVertex is the number of edges per each vertex (105 for 2^18)
%%            4.max_iteration is the number of iterations for the Lanczos-SO algorithm (20)
%%            5.eig_k is the number of eigenvalues to be calculated (10)
%%            6.KeepB is to keep the same random B vector or not (1)
%%            7.Run_schedule is to scan the input table and divide the task evenly among processes (0) 
%%            8.StoreTFS is whether to store the input matrix into TFS (1)
%%            9.StoreLHD is whether to store the input matrix into local hard disk
%%            10.TFS is to run the for loop within TFS or LHD (1 for TFS, otherwise LHD)
%% Note 1: the main process can read the variables in m files.
%% Note 2: the parallel version should not delete the temporary table, it will mess up other processes' opertaions. So I move the delete temporary table in the main process.
%% Note 3: The inputmatrix will be set as automatically as 'M{NumOfNodes}' say M4096
% Note 4: The random vector B will be set as automatically 'B{NumOfNodes}' say B4096
%% Note 5: The first lz_q1 will be named as {NumOfNodes}lz_q1

%% Author: Yin Huang
%% Date: Mar, 15, 2016
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%
%%   Log location: benchmark/version5_stat.txt  fstat
%%
%%   global variables: 
%%          machines, NumOfMachines, NumOfNodes, NumOfProcessors, max_iteration
%%     
%%   %% matrix will be written to M{NumOfNodes} table in accumulo 
%%   %% Meanwhile input for Heigen is also saved at: 
%%        fidEdge =fopen(['Heigen' num2str(NumOfNodes) '_' num2str(randi([0,10000]))  '.edge'],'w');
%%   
%%   %% random vector B will be written to B{NumOfNodes} table in accumulo 
%%
%%   %% vi is saved in accumulo table: {NumOfNodes}lz_q{1:iteration}
%%   %%
%% 
%%   %% MATRIX will be saved in Alluxio:
%%       if(pace == 1)
%%	   %filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
%%       % else
%%    %filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(Np) 'proc_' num2str(i) ]);
%%     
%%  %% Since vi is required for matrix * vector operation, the leader process first read a global version from Accumulo 
%%     And save to a global version at:
%%      Global location:  [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v' ];
%%      local location:   [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine];
%% 
%%

%%% Connect to the DB to access the global variables among multiple
%%% processes in the whole cluster
myDB;

%%%% Create a folder benchmark to store the debugging information
if ~exist('benchmark','dir')
        mkdir('benchmark');
end
fname = ('benchmark/version5_stat.txt');
fstat = fopen(fname,'a+');

disp(['Start time: ' sprintf('\n')]);
StartTime = datestr(now);
%disp(['TFS is ' num2str(TFS)]);
lz_allTime = tic;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% GLOBAL variables need be accessed by all processors. 
% I store them in the table every processor will read from the table.
global NumOfMachines; % num of machines for computation
NumOfMachines = NumOfMach;
global machines;
machines=getMachines(NumOfMachines);
global NumOfNodes; %nodes in the graph
NumOfNodes = NumOfNod;

global max_iteration; % iteration times 
max_iteration = max_it;
global NumOfProcessors;
NumOfProcessors = NumOfProcs;
global EdgesPerVertex;
EdgesPerVertex = EdgesPerVer;
global alpha; 
alpha = zeros(1,max_iteration);
global bet; 
bet = zeros(1,max_iteration);

global machines_t; machines_t = DB('NumOfMachines');
global nodes_t; nodes_t = DB('NumOfNodes');
global proc_t; proc_t=DB('NumOfProcessors');
global matrix_t; matrix_t = DB(['M' num2str(NumOfNodes)]);

global alpha_t; alpha_t = DB('alpha'); %% store the alpha array in accumulo table 'alpha'
global beta_t; beta_t = DB('beta'); %% store the beta array in accumulo table 'beta'

%%  initM_edges_t = DB('edges'); this is for initialize the matrix
global initM_edges_t; initM_edges_t  = DB('edges');

global cur_it_t; cur_it_t = DB('cur_it');



norm_b_temp = DB(['lz_norm_B_temp2']); %% temp db table for calculating the norm of vector B.





cur_loop_j = DB('cur_loop_j'); %% so inside loop identifier j every process need to know this value to computeR

% so_rrtv = DB('so_rrtv'); %% so to store the vector 'rrtv' which is used to update lz_vpath, lz_vpath = lz_vpath - so_rrtv;

temp_lz_vpath = DB([num2str(NumOfNodes) 'lz_vpath']);
temp_mv_temp=DB('mv_temp');
temp_dot_temp=DB('dot_temp');


delete(alpha_t);
delete(beta_t);


delete(norm_b_temp);

delete(cur_loop_j);


delete(temp_lz_vpath);
delete(temp_mv_temp);
delete(temp_dot_temp);

alpha_t = DB('alpha');
beta_t = DB('beta');


norm_b_temp = DB(['lz_norm_B' num2str(NumOfNodes) '_temp']);


cur_loop_j = DB('cur_loop_j');


temp_dot_temp=DB('dot_temp');
temp_lz_vpath = DB([num2str(NumOfNodes) 'lz_vpath']);

%%% initialize the following table variables that will not change as
%%% program runs
m_assoc = Assoc('1,','1,',sprintf('%d,',NumOfMachines));
put(machines_t,m_assoc);
n_assoc = Assoc('1,','1,',sprintf('%d,',NumOfNodes));
put(nodes_t,n_assoc);
p_assoc = Assoc('1,','1,',sprintf('%d,',NumOfProcessors));
put(proc_t,p_assoc);
initM_edges_assoc = Assoc('1,','1,',sprintf('%d,',EdgesPerVertex));
put(initM_edges_t, initM_edges_assoc);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Hard coded variables
v_prefix = [num2str(NumOfNodes) 'lz_q'];   %% v_prefix is lz_q to retrieve the tables named from lz_q{1:row}
q_path = cell(max_iteration+1,1);
scalar_b_path = 'scalar_b';
B_path = ['B' num2str(NumOfNodes)];

        %%% initialize q_path array with the name lz_q{i}%%%%%%%%%%
        for i = 1:max_iteration+1
            q_path{i} = [v_prefix num2str(i)];
        end
        for i = 2:max_iteration+1
            tempary = DB(q_path{i});
            delete(tempary);
        end
        for i = 1:max_iteration+1
                tempary =DB(q_path{i});
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

fwrite(fstat,['***********************************************' sprintf('\n') ...
    'Begin time: ' StartTime sprintf('\n*******************************************\n')]);
diary (['YinEigen: ' num2str(NumOfNodes) '_Machines' num2str(NumOfMachines) '_Proc' ...
    num2str(NumOfProcessors) '_Iter' num2str(max_iteration) '_logs.txt']);
fwrite(fstat,['**Commands: YinEigen( ' num2str(NumOfMachines) ',' num2str(NumOfProcessors) ',' num2str(NumOfNodes) ',' num2str(initMat) ',' num2str(EdgesPerVertex) ',' num2str(max_iteration) ',' num2str(eig_k) ',' num2str(KeepB) ',' num2str(Run_schedule) ',' num2str(StoreTFS) ',' num2str(StoreLHD)  ',' num2str(TFS) ')' sprintf('\n') ]);

disp([sprintf('\tRunning YinEigen with the following configuration:\n')]);
disp([num2str(NumOfMachines) 'machines:' machines sprintf('\n')]);
disp([num2str(NumOfProcessors) sprintf(' processors\t')]);
disp([num2str(NumOfNodes) sprintf(' nodes\t')])
disp([num2str(max_iteration) sprintf(' max iterations\t')]);
disp([num2str(eig_k) sprintf(' top eigen values')]);
disp(['KeepB yes?no: ' num2str(KeepB)]);
disp(['Run_schedule yes?no: ' num2str(Run_schedule)]);
disp(['StoreTFS yes?no: ' num2str(StoreTFS)]);
disp(['StoreLHD yes?no: ' num2str(StoreLHD)]);
disp(['TFS yes?no: ' num2str(TFS)]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% Initializing the input matrix%

%%
%%    SaveGraphData.m:
%%      1. Create the input matrix based on KronGraph500 algorithm in M{NumOfNodes} table in accumulo 
%%      2. Meanwhile the matrix input for Heigen is saved at Heigen_{NumOfNodes}_.txt file 
%%
        if (initMat == 1)
        disp(['Now initializing the input matrix in ' 'M' num2str(NumOfNodes)]);
        this = tic; eval(pRUN('SaveGraphData',NumOfProcessors, machines)); total_time = toc(this);
        disp(['Total time to initialize M' num2str(NumOfNodes) ' is ' num2str(total_time)]);
        fwrite(fstat,['Total time to initialize M' num2str(NumOfNodes) ' is ' num2str(total_time) ]);
        end
%% Done initializing the input matrix

        
%%% initialize random vector b stored in table 'B{NumOfNodes}'

% initB.m :
%	1.create the random vector B in table B{NumOfNodes}
%   2.calculate the norm of vector B in scalar_b table
%	3.save the normalized vector B in {NumOfNodes}lz_q1 

%% 
%%  Initialize vector B and store it into the RAM of each process
%%  Random vector B will be stored at B{NumOfNodes}
%%
if (KeepB ~= 1)
    
    %% initB.m:
    %%    1. Create B{NumOfNodes} table in accumulo to save the random vector B. 
    %%
    %% parallel_lz_norm_B_p1:
    %%    input: B{NumOfNodes} 
    %%    output: temp = DB('lz_norm_B_temp2');
    %%
    %%    1. parallel calculate a equal length of B{NumOfNodes} and write to lz_norm_B_temp2
    %%
    %% parallel_lz_norm_B_p2:
    %%   input: DB('lz_norm_B_temp2')
    %%   output: DB('scalar_b');
    %%   1. parallel calculate the norm of vector B and write the result in DB('scalar_b');
    %%
    %% parallel_scalarmult_B:
    %%      
    %%      input:input_v =DB(['B' num2str(NumOfNodes)]); scalar_b_path = DB('scalar_b'); % local variable for scalar_b 
    %%      
    %%      output:DB({NumOfNodes}'lz_q1');
  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%  
    
    output=DB([num2str(NumOfNodes) 'lz_q1']);
    disp(['Initializing the random vector b in table B' num2str(NumOfNodes)]);
	this = tic;eval(pRUN('initB',NumOfProcessors,machines));that = toc(this);
	disp(['InitB takes: ' num2str(that)]);
	fwrite(fstat,['InitB takes: ' num2str(that) sprintf('\n')]);
    
    %% initialize the lz_q1 for the for loop
    eval(pRUN('parallel_lz_norm_B_p1',NumOfProcessors,machines));
    parallel_lz_norm_B_p2(NumOfProcessors);
    eval(pRUN('parallel_scalarmult_B',NumOfProcessors,machines));
    
    %% {NumOfNodes}lz_q1 will be saved in the for loop before first iteration actually takes place
end
%% TEST of initB passed.
%% Normalize B and save the scalar*B into Lz_q1 only need to do once.


 
%%%% Below is to schedule the tasks evenly among all processors %%%%%%%
%%%% The cut of input matrix will be stored in the table Cut{NumOfNodes}
%%%% For parallel part, each processor will read through cut('previous cut',:)+1 until cut('current cut',:)

scheduler = DB(['Cut' num2str(NumOfNodes)]);
totalentries = DB(['Entries' num2str(NumOfNodes)]);
if (Run_schedule == 1)
        delete(scheduler);
        delete(totalentries);
        scheduler = DB(['Cut' num2str(NumOfNodes)]);
        totalentries = DB(['Entries' num2str(NumOfNodes)]);
        this = tic;
        eval(pRUN('myscheduler',NumOfProcessors,machines));
        that =toc(this);
        disp(['Scan table running time: ' num2str(that) 's' sprintf('\n')]);
        fwrite(fstat,['Scan table running time: ' num2str(that) 's' sprintf('\n')]);
		this = tic;
		myscheduler_p2(NumOfProcessors, EdgesPerVertex);
		that = toc(this);
		disp(['Scheduler 2 running time: ' num2str(that) 's']);
		fwrite(fstat, ['Scheduler 2 running time: ' num2str(that) 's' sprintf('\n')]);
end


%%%%% Now we store the input matrices to corresponding work node %%%%
%%
%%  storeDataToTFS.m:
%%      1. according to Cut{NumOfNodes} save the partial matrix into the worker processor's RAM
%%  
%%      input: Cut{NumOfNodes} M{NumOfNodes} NumOfNodes NumOfMachines
%%  
%%      output:      if(pace == 1)
%%                   %filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
%%                   % else
%%                   %filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(Np) 'proc_' num2str(i) ]);
%%
%%      DebugPath: DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
%%                 DebugPath = ([DebugPathPre '/' num2str(NumOfNodes) '_' num2str(NumOfMachines) '_' num2str(Np)]);
%%
%%

if(StoreTFS == 1)  
    this = tic;
    eval(pRUN('storeDataToTFS',NumOfProcessors,machines));
    that=toc(this);
    disp(['Store to TFS running time: ' num2str(that) 's']);
    fwrite(fstat, ['Store to TFS running time: ' num2str(that) 's' sprintf('\n')]);
end

if(StoreLHD == 1)
	this = tic;
	eval(pRUN('LHD_store',NumOfProcessors,machines));
	that = toc(this);
    disp(['Store to LHD running time: ' num2str(that) 's']);
    fwrite(fstat, ['Store to LHD running time: ' num2str(that) 's' sprintf('\n')]);
end


%%Now start the for loop%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%fname = ('benchmark/stat.txt');
%fstat = fopen(fname,'a+');

for it = 1:max_iteration
    str= ['----------------------Iteration: ' num2str(it)  ...
        ' begins-----------------------' sprintf('\n')];
    disp(str); fwrite(fstat, str);
	thistic=tic;
    
	%%%%%%%%%%%%%%%%%%%%%%  matrix * vector begin **********************
    %%*******************************************************************
    
    %% update the cur_it first because iteration number will be used in this section
    it_assoc = Assoc('1,','1,',sprintf('%d,',it)); put(cur_it_t,it_assoc); 
    
	%%%%%%%%%%%%%%%%%%%%%% saving vi to global file because matrix * vi needs the whole vi %%%%%%%%%%%%%%%%%%
	%% Only do it once when it == 1 because in the end we update the result of vi based on local results
    %%  
    %%  saveVectorToGTFS.m:
    %%     1. saving v1 to global file in Alluxio
    %%     2. input: vector = DB[num2str(NumOfNodes) 'lz_q1'];
    %%     3. output: Alluxio file
	%%    outputFilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v' ];   This is where the global file saved 
    %%     only value needs be stored because it is a full vector, row: 1:NumOfNodes, col: 1  
    %%
	if (it == 1) 
        disp('Now saving vector to the global alluxio file');
        this = tic;
	    %saveVectorToGTFS();
        saveT = toc(this);
        str=([ 'Saving vector to global file costs ' num2str(saveT) 's' sprintf('\n')]);
        disp(str); fwrite(fstat, str);
        disp(['Now each machine makes its own copy of vector']);
        this = tic;
        
	%%%%%%%%%%%%%%%%%%%%%% saving global vi to all local machines to reduce the bottleneck in leader process%%%%%%%%%%%%%%%%%%
    %%
    %%          SaveVectorToTFS.m:
    %%              Usage:  Save global {NumOfNodes}lz_q1 in Alluxio to all local machines
    %%          1. Input: 
    %%   inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v' ];
    %%
    %%          2. Output:
    %%   outputFilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine];
    %%
    
        eval(pRUN('saveVectorToTFS', NumOfMachines,machines));
        savelocal = toc(this);
        str = (['Machine copy vector costs ' num2str(savelocal) 's' sprintf('\n')]);
        disp(str); fwrite(fstat, str);	
        
    end
	
    %%%%%% Saving global vector {NumOfNodes}lz_q1 to Alluxio done %%%%%%%
    
    %%%%%%**********Start doing matrix * vector ***************************
    
        disp(['computing v=matrix * vector ' num2str(it) ' ...']);
        temp = DB('mv_temp'); delete(temp);temp = DB('mv_temp');  %% remove the temp table from previous operation for paralell_mv_p1.m
  if(TFS == 1)
        disp('Running TFS version of matrix multipilcation');
        thisT = tic;
        
        %%%%% Alluxio_Row_mv_version5_p1.m
        %%%%%   Usage: Do the following computation according to the
        %%%%%   algorithm before SO section occurs
        %%%%%   Calculating alpha and beta using intermediate table in
        %%%%%   accumulo: 
        %%%%%    for beta: norm_v_temp = DB(['lz_norm_v' num2str(NumOfNodes) '_temp']);
        %%%%%    for alpha: dot_temp = DB('dot_temp');
        %%%%%   Intermediate result tables have been deleted in leader.
        %%%%%   1. Input: 
        %%%%%    it, M{NumOfNodes}, Cut{NumOfNodes}, alpha, beta
        %%%%%  		vector: inputFilePath=[inputFilePathPre '/' num2str(it) 'v_'
        %%%%% num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
        %%%%%       
        %%%%%       matrix: ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
       
        %%%%%   2. Output:
        %%%%%       alpha(it), beta(it)
        %%%%%       file_location = ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
        %%%%%       num2str(i)  'id_tempv'];
        
        eval(pRUN('Alluxio_Row_mv_version5_p1',NumOfProcessors,machines));
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% Preparing for SO %%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        disp(['Constructing the Tridigonal matrix...']);
        disp(['alpha is ']); alpha
        disp(['beta is ']); bet
        tempTmatrix = constructT(it, alpha, bet); 
        [Q,D] = eig(tempTmatrix);
        D = diag(D);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%%%% Preparing Done %%%%%%%%%%%%%%%%%%%%%%%
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        %% Start parallel-Selective Orthogonization part %%%%%%%%%%%%
        %% *********************************************************** 
        disp(['NumOfMachines in SO: ' num2str(NumOfMachines) 'Starting so, iterations # is ' ...
            num2str(it) ' beta_it value is: ' num2str(bet(it))]);
        this = tic;  
        cur_loop_j = DB('cur_loop_j');
        eps = 2.204e-16;
        num_ortho = 0;
        error_bound = abs(sqrt(eps)*D(it));
        
        for j = 1:it
        cur_error = abs(bet(it) * Q(it,j));
        disp(['Error of' num2str(j) '/' num2str(it) ' th vector:' num2str(cur_error) 'compare to ' num2str(error_bound)]);
		
            if(cur_error <= error_bound)
                disp(['V need to be reorthogalized by ' num2str(j) 'th Ritz Vector']);
                    num_ortho =  num_ortho + 1;
                disp(['Reorthogonalizing against' num2str(j) 'th Ritz vector']);
                disp(['Store j: ' num2str(j) ' into cur_loop_j(1,1) table']);
                loop_j_Assoc = Assoc('1,','1,',sprintf('%d,',j));
                put(cur_loop_j,loop_j_Assoc);
            %%%%%%
            %% Parallel_SO.m
            %%    Usage: 
            %%      calculate r <- ViQ[:,j]   
            %%      
            %%      Vi is the lz_q{1:iteration} thus Vi should be saved in Accumulo table as well
            %%      In addition, beta is also updated at the same time
            %%   
            %%    Input:
            %%      1. Cur_loop_j 2. it 3. Cut{NumOfNodes} 4. lz_q{1:it}
            %%      5. alpha_t 6. beta_t 7. beta array 
            %%      8. inputFilePath=[inputFilePathPre '/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
            %%      num2str(i) 'id_tempv'];
            %%
            %%    Intermediate result table: 
            %%      1. DB(['lz_norm_v' num2str(NumOfNodes) '_temp']); for beta
            %%      2. rtv result: DB('rtv_result');
            %%      3. rtv temp: DB('so_rtv_temp');
            %%
            %%    Output:
            %%      1. ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
            %%      num2str(i)  'id_tempv'];
                eval(pRUN('parallel_SO',NumOfProcessors,machines));
            
            %% parallel_SO done%%%%%%%%%%%%%
            %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
            end
        end % end for
        
        that = toc(this);
        disp(['Iteration ' num2str(it) ' SO takes: '  num2str(that)]);
        fwrite(fstat,['Iteration ' num2str(it) ' SO takes: '  num2str(that) sprintf('\n')]);
        disp(['Number of orthongalization: ' num2str(num_ortho)]);


        if(num_ortho > it - 1)
        disp('The new vector converged. Finishing ...');
        compute_eigval(it, alpha, bet, eig_k);
        save_tridiagonal_matrix(alpha, bet, it);
        break
        end 
        
        if(bet(it) == 0.0)
        disp(['beta[' num2str(it) ']=0. finishing']);
        disp('Saving the tridiagonal matrix');
        compute_eigval(it, alpha, bet, eig_k);
        save_tridiagonal_matrix(alpha, bet, it);
        break
        end
        
        %% Selective Orthogonization part done **********************
        %%*************************************************************
        
        %% Continue to do the rest after SO: Alluxio_Row_mv_version5_p2.m
        %% Usage: 
        %%
        %%     Continue to update:
        %%
        %%              v_i+1 <- V / beta_i
        %%
        %%     Should save V_i+1 into Accumulo table as well
        %%     Should broadcast V_i+1 to all workers
        %% input: 
        %%      1. it
        %%      2. DB:Cut{NumOfNodes}
        %%      3. beta
        %%      4. inputFilePath=[inputFilePathPre '/' num2str(it+1) 'v_' ... 
        %%      num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global'];
        %%      5. ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
        %%      num2str(i)  'id_tempv'];
        %%
        %% output:
        %%      1. outputFilePath=[FilePathPre '/' num2str(it+1) 'v_' ... 
        %%      num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
        
        eval(pRUN('Alluxio_Row_mv_version5_p2',NumOfProcessors,machines));
        
        %% Alluxio_Row_mv_version5_p2 done
        %%************************************
        
        that = toc(thisT);
        %fstat = fopen(fname,'a+');
        %disp(['Iteration ' num2str(it) ' Alluxio_Row_mv_version4 takes: '  num2str(that)]);
       % fwrite(fstat,['Iteration ' num2str(it) ' Alluxio_Row_mv_version4 takes: '  num2str(that) sprintf('\n')]);
  else
        disp(['Running the local disk version of matrix*vector']);
         this = tic;
        eval(pRUN('LHD_Row_mv',NumOfProcessors,machines));
        that = toc(this);
        disp(['Iteration ' num2str(it) ' LHD_Row_mv takes: '  num2str(that)]);
        fwrite(fstat,['Iteration ' num2str(it) ' LHD_Row_mv takes: '  num2str(that) sprintf('\n')]);
  end

        
  
    oneIterationTime=toc(thistic);
    disp(['Iteration: ' num2str(it) ': ' num2str(oneIterationTime) 's']);
    fwrite(fstat,['Iteration: ' num2str(it) ': ' num2str(oneIterationTime) 's' sprintf('\n')]);

	compute_eigval(it, alpha, bet, eig_k);
	disp('Saving the tridiagonal matrix');
	save_tridiagonal_matrix(alpha, bet, it);
	
    
	end  %% end for loop
	
	if ( TFS ~= 1) %% LHD mode we remove the local disk files to save space.
    eval(pRUN('deletefiles',NumOfMachines,machines));
    end
	disp('!!!!!!Reached the max iterations. Finishing...');
	
	disp('Summarizing alpha[] and bet[]...');
	disp(sprintf('\n\talpha\tbeta'));
	for n = 1:max_iteration
	disp([num2str(n) sprintf('\t') num2str(alpha(n)) sprintf('\t\t') num2str(bet(n))]);
	end
	
	alltime = toc(lz_allTime);
	disp(['Total running time is: ' num2str(alltime)]);
	  endtime = datestr(now);

	disp(['Ending time: ' endtime  sprintf('\n')]);
	
	fwrite(fstat,['Ending time: ' endtime  sprintf('\n')]);
	disp(['Begin time: ' StartTime]);
	diary off;
	fclose(fstat);
end %end function

