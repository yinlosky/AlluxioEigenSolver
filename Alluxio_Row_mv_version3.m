%%%%%%%%%%%%%%%Filename: Alluxio_Row_mv_version3.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% This function is used to be made with MPI_RUN to be used in multiple processes in the cluster
%% eval(MPI_Run('Alluxio_Row_mv_version3', Np, machines{}))
%%
%% Each process will be identified by the rank which starts from 0
%% The leading process will wait for working processes' done signal, once everything is completed, 
%% the leading process will proceed to the following section of the algorithm

%% Same as Row_mv_version2, each process will process corresponding matrix part and vector part
%% and this is identified by my_rank

%% once each working process is done, it will send a finish signal to the leading process
%% I am using an output array which will save the process rank to indicate the completion of 
%% each working process

%%
%% Function: This file will read rows of matrix from Alluxio and multiply the vector {NumOfNodes}lz_q{cur_it}
%% Result will be saved at [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id' {_r _v} ];

%%
%% {NumOfNodes}lz_vpath = matrix * {NumOfNodes}lz_q{cur_it}
%% %% Version 2 will read vector from Alluxio as well to see how much faster we can get 
%% Date: Apr-1-2016

totaltic = tic;
%disp(['****************** Now Running Alluxio_Row_mv_version3.m ***********************']);


%%% Below is for MPI related %%%%%%%%%%%%%%%%%%%%%%
% Initialize MPI.
MPI_Init;

% Create communicator.
comm = MPI_COMM_WORLD;

% Get size and rank.
comm_size = MPI_Comm_size(comm);
my_rank = MPI_Comm_rank(comm);

% Since the leader only manages, there must be at least 2 processes
if comm_size <= 1
    error('Cannot be run with only one process');
end

disp(['my_rank: ',num2str(my_rank)]);
% Set who is leader.
leader = 0;
% Create a unique tag id for this message (very important in Matlab MPI!).
output_tag = 10000; %% this tag is used as a synchronization message.

fbug = fopen(['benchmark/v3_' num2str(my_rank+1) '_proc_MatrixVector.txt'],'w+');

% Leader: just waiting to receive all signals from working processes
if(my_rank == leader)
    %flag for beding done with all processing  
    
    leader_begin_time = tic;
    done = 0;
    %leader will receive comm_size-1 signals
    output = zeros(1,comm_size-1); 
%% Instead of using for loops, use counters to indicate how many processes have
%% completed their tasks.

%% we are doing backwards because in MPI_RUN the highest rank process
%% will be spawned first and it is more likely to complete earlier
    recvCounter = comm_size-1;
    while ~done
          % leader receives all the results.
          if recvCounter > leader
              %% dest is who sent this message
              dest = recvCounter;
              leader_tag = output_tag + recvCounter;
             [message_ranks, message_tags] = MPI_Probe( dest, leader_tag, comm );
             if ~isempty(message_ranks)
                 output(:,recvCounter) = MPI_Recv(dest, leader_tag, comm);
                 str = (['Received data packet number ' num2str(recvCounter)]);
                 disp(str);fwrite(fbug,str);
                 recvCounter = recvCounter - 1;
             end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
    output
    leader_total_time = toc(leader_begin_time);
    str = (['Leader process runs: ' num2str(leader_total_time) sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    fclose(fbug);
else %% working processes
%%%%%%%%%%
%%%%%%%%%%
%%%%%%%%%%
 %%%%%%%%%%%%%%%%%%%%%%

myDB; %% connect to DB and return a binding named DB.

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it= DB('cur_it');
proc_t = DB('NumOfProcessors');

NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(proc_t('1,','1,')));

it = str2num(Val(cur_it('1,','1,')));
m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors

num = DB(['Entries' num2str(NumOfNodes)]);  %% This table stores the elements for each column

%% path to where the Alluxio files are stored
filePathPre = '/mytest';


 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 i = my_rank+1;  %% my_rank starts from 0 to comm_size-1; 
	    fstat = fopen(['benchmark/v3_' num2str(i) '_proc_MatrixVector.txt'],'w+');
               %% rank 0 is leader process; i ranges from 1 to comm_size-1;
        if(i==2)
        start_col = 1;
        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
        else
                if(i<NumOfProcessors)
                        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
                        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
                end
        end
        if(i==NumOfProcessors)
        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
        end_col = NumOfNodes;
        end
        str = (['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
        

	%% version 2: reading vector from Alluxio, each process should know which machine it belongs to.
	%%
	%% TO determine which machine each process belongs to,
	%%   if rem(procID-1, TotalMachine-1) == 0, then procID belongs to the last machine machines(NumOfMachines);
	%% else procID belongs to the machines(rem+1);
               [idum, my_machine] = system('hostname'); 
               my_machine = strtrim(my_machine);
		 str = ['My rank id is: ' num2str(i-1) 'and My machine is: ' my_machine sprintf('\n')];
                disp(str); fwrite(fstat, str);		
		
%%%%%%%%%%%%%%%% After setting the machine number, we know where to read the vector from.
		str = (['Now reading vector from Alluxio' sprintf('\n')]);
		disp(str); fwrite(fstat, str);
		
		inputFilePathPre = '/mytest';
		inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
		
		inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
       	inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
		this = tic;
		my_row = javaMethod('readFile',inputobject_r);
		my_val = javaMethod('readFile',inputobject_v);
		readv=toc(this);
		str = ['Read vector takes: ' num2str(readv) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);
		
		str = ['Now constructing the vector'];
		this = tic;
		disp(str); fwrite(fstat, str);
		my_row = char(my_row); my_val = char(my_val);
		my_row = sscanf(my_row, '%d'); my_val = sscanf(my_val,'%f'); 	
		myVector = sparse(my_row, 1, my_val, NumOfNodes, 1);
		transV = toc(this);	
		str = ['Construction of vector done! It takes ' num2str(transV) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);	
			% for columns = start_col:end_col
                       % if(exist([root '/mydata' num2str(NumOfNodes) '/' num2str(i) '.txt']))  %% We have one row to multiply
            
                       %% According to the way we write the files the file name is: filePathPre/mydata{NumOfNodes}_{ProcessId}_{r,c,v}
        filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
                
                 	%% Create the following three objects for writing strings
        myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_r' '|CACHE|CACHE_THROUGH']);
        myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
        myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_v' '|CACHE|CACHE_THROUGH']);
                  this = tic; 
        myRow = javaMethod('readFile',myobject_r);

        myCol = javaMethod('readFile',myobject_c);

        myVal = javaMethod('readFile',myobject_v);
        readlocal = toc(this);
	    disp(['Read processor id: ' num2str(i) ' from file costs: ' num2str(readlocal) 's' sprintf('\t')]);
        fwrite(fstat, ['Read processor id: ' num2str(i) ' from file costs: ' num2str(readlocal) 's' sprintf('\t') ]);
        %% COnvert the Assoc into Matrix format....             
        %% convert java string to matlab char
        myRow = char(myRow); myCol = char(myCol); myVal = char(myVal); 
        %% convert char into numeric type
        myRow = sscanf(myRow,'%d'); myCol = sscanf(myCol,'%d'); myVal=sscanf(myVal,'%f');
        this = tic;
        %onerowofmatrix = sparse(inputData(:,1),inputData(:,2),inputData(:,3),1,NumOfNodes);
                        onepartofmatrix = sparse(myRow-start_col+1,myCol,myVal,end_col-start_col+1,NumOfNodes);
                        const = toc(this);
                         fwrite(fstat, ['Construct sparse: ' num2str(const) 's' sprintf('\n') ]);

                        this = tic;
                        myresult = onepartofmatrix * myVector;
                        multt = toc(this);
                         fwrite(fstat, ['Multiplication: ' num2str(multt) 's' sprintf('\t') ]);
		
		%% below commented: writing result back to the Accumulo 
		%{
                        %%full(myresult) is the value
                        this = tic;
                         put(output, Assoc(sprintf('%d,',start_col:end_col),'1,',sprintf('%.15f,',full(myresult)))); %% columns is actually the row id
                        putt = toc(this);
                           fwrite(fstat, ['Write back: ' num2str(putt) 's' sprintf('\n') ]);
		%}

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%% below writing result back to Alluxio 
		%% [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id' {_r _v} ];
		outputFilePathPre = '/mytest';
		outputPath = [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
		%%%%
		%% create the object to write to Alluxio
		myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_r' '|CACHE|CACHE_THROUGH']);
        	myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_v' '|CACHE|CACHE_THROUGH']);
		str = (['Start writing result back to local lz_vpath alluxio ...  ']);	
		this = tic;
		str_r = sprintf('%d,',start_col:end_col);
		str_v = sprintf('%.15f,',full(myresult));
	        javaMethod('writeFile',myobject_r,str_r);
        	javaMethod('writeFile',myobject_v,str_v);
		writeTime = toc(this);
		str = ([num2str(writeTime) 's' sprintf('\n')]);
		disp(str); fwrite(fstat,str);
		
                    fwrite(fstat, ['Done' ]);
                    fclose(fstat);
         leader_tag = output_tag + my_rank;
         MPI_Send(leader, leader_tag, comm,my_rank);
                   
%%%%%%%%%%%
%%%%%%%%%%
end

disp('Success');

MPI_Finalize;




%% function MPI_Send( dest, tag, comm, varargin )
%% function varargout = MPI_Recv( source, tag, comm )






%disp('Sending to agg');
%fwrite(fstat,['Sending to agg']);
%agg(w);
%disp('Agg is done! I am closed now');
%fwrite(fstat, ['Agg is done! I am closed now.']);
%fclose(fstat);
