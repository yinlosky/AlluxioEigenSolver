function parallelReading()
%%%%%%%%%%% 
%%%% function name: parallelReading
%%%% Usage: This function serves to test the parallel reading of in-memory files in parallel and assess the performance
%%%% The result will be saved in the accumulo table R{numofnodes_numberofprocesses}
%%%% Author: Yin Huang
%%% Date: March 1 2016
%%%%%%%%%%

%% Prerequisite
%% This function requires the pre-populate the following accumulo tables: max_iteration and time_statistics_numofnodes_numOfMachines__np_{max_iteration}

%% myDB;
%% numberOfIteration_t = DB('max_iteration');
%% numberOfIteration = str2num(Val(numberOfIteration_t('1,','1,')));

%% Connect to the DB first;
myDB;
%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% Total number of iteratons for evaluating the reading performance
numberOfIteration_t = DB('max_iteration');
numberOfIteration = str2num(Val(numberOfIteration_t('1,','1,')));


%% Get the total number of machines and nodes
%% get the number of nodes which is the dimension of the input  matrix
nodes_t = DB('Scale');
NumOfNodes = 2^str2num(Val(nodes_t('1,','1,')));

machines_t = DB('NumOfMachines');

numOfMachines = str2num(Val(machines_t('1,','1,')));

%% set the result table
%result_t = DB(['time_statistics_' num2str(NumOfNodes) '_' num2str(numOfMachines) '_' num2str(Np)]);

%% set up the table for writing the final results
% result_t = DB(['R' num2str(NumOfNodes) '_' num2str(Np) '_iter' num2str(i)   ]);
% numArr = zeros(1,numberOfIteration);
% for i = 1:numberOfIteration
%	numArr_{num2str(i)} = DB(['R' num2str(NumOfNodes) '_' num2str(Np) '_iter' num2str(i)   ]);
% end

%% Parallel part
%% myProc is the working client
w = zeros(Np,1,map([Np 1],{},0:Np-1));
myProc = global_ind(w); %Parallel


%% Set up the debug file location as pwd
DebugPathPre = ([pwd '/assessParallelPerformance' ]);

%% Filepath to store in TFS
filePathPre = '/mytest';

for i = myProc
        if (i>1) % process id 1 is idel	
        %% setting the iterations
	for myIteration = 1 : numberOfIteration;
	
	%% set up the destiation
	result_t = DB(['time_statistics_' num2str(NumOfNodes) '_' num2str(numOfMachines) '_' num2str(Np) '_' num2str(myIteration)]);
		
	% set up the real debug file for each process
	flog = fopen([DebugPathPre '/' num2str(i) '_process_debug' '_iteration_' num2str(myIteration) '.txt'],'w+');
	
	%% start reading from TFS for each process has its own file in the TFS
	%% According to the way we write the files the file name is: filePathPre/mydata{NumOfNodes}_{ProcessId}_{r,c,v}
	filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
	
	% set up the final destination for saving the timer
        %result_t = DB(['R' num2str(NumOfNodes) '_' num2str(Np) '_iter' num2str(i)   ]);	
	
	
	
        %% creating the Java object to access the in-memory files
  	%% Create the following three objects for writing strings
        myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_r' '|CACHE|CACHE_THROUGH']);
        myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
        myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_v' '|CACHE|CACHE_THROUGH']);
	%% start calling the readFile method in my java code
	this = tic; 
	myRow = javaMethod('readFile',myobject_r);

	myCol = javaMethod('readFile',myobject_c);

	myVal = javaMethod('readFile',myobject_v);
	read_time = toc(this);
	
	disp(['Reading for process: ' num2str(i) ' at iteration: ' num2str(myIteration) ' costs ' num2str(read_time) ]);

	fwrite(flog, ['Reading for process: ' num2str(i) ' costs ' num2str(read_time) ] );

	put(result_t, Assoc(sprintf('%d,',i), sprintf('%d,', myIteration), sprintf('%0.5f,',read_time) ) );
	%% Post processing to transfer the data returned into Assoc format. For now we don't need it

	%myRow = str2mat(myRow);

	%myCol = str2mat(myCol);

	%myVal = str2mat(myVal);

	%readAssoc = Assoc(myRow, myCol, myVal);	
	fclose(flog);
	end %% end for iteration loop
	end %% end for if
end  %% end the parallel process part

%%aggregate the w (waiting for all processes to finish)
agg(w);
