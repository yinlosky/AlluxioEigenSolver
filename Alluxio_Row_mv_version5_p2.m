%%%%%%%%%%%%%%%Filename: Alluxio_Row_mv_version5_p2.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% This version cut version4 into two parts. Because we are injecting SO part in between two parts.
% Part 2 takes care of the second part of version4 after SO.

%% Difference with version3 is that in this version the leader process is not using MPI_Probe for receiving the messages since the message is very short.
%% I remove all MPI_Probe, just use MPI_recv, and see how it performs. In one_timesaxv, I keep MPI_Probe because we are aggregating results from workers to the leader, 
%% if the vector is getting bigger, the message might be large. 



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

myDB; %% connect to DB and return a binding named DB.

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

beta_t = DB('beta');
machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it= DB('cur_it');
proc_t = DB('NumOfProcessors');
dot_temp = DB('dot_temp');


NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(proc_t('1,','1,')));

norm_v_temp = DB(['lz_norm_v' num2str(NumOfNodes) '_temp']);

it = str2num(Val(cur_it('1,','1,')));  %% current iteration
m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors


%%  initialize alpha() and beta()


global bet;

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

output_tag_second = 20000;

output_tag_three = 30000;

output_tag_four = 40000;

%% continue tag;
onetime_saxv_tag = 50000;

updateq_tag = 60000;

save_v_i_plus_one_tag = 70000;

con = 1;

fbug = fopen(['benchmark/' num2str(NumOfMachines) 'machines_' num2str(my_rank+1) '_proc_MatrixVector.txt'],'w+');
fdebug = fopen('benchmark/version4_stat.txt','a+');
% Leader: just waiting to receive all signals from working processes
if(my_rank == leader)
     
    str = ['--------------------------updatev_i+1 begin-------------------' sprintf('\n')];
    disp(str); fwrite(fbug,str);fwrite(fdebug, str);
    leader_begin_time = tic;
    done = 0;
    %leader will receive comm_size-1 signals
    updated_vector = cell(1,comm_size-1); 
    
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
              leader_tag = output_tag_three + recvCounter;
             [message_ranks, message_tags] = MPI_Probe(dest, leader_tag, comm );
             if ~isempty(message_ranks)
                 str = (['Received data packet number ' num2str(recvCounter)]); disp(str);fwrite(fbug,str);
                 %disp(['class of MPI_recv package is: ' class(MPI_Recv(dest, leader_tag, comm))]);
                % disp('received from above number: ');
                 tempstr = MPI_Recv(dest, leader_tag, comm);
                % disp('stored in tempstr');
                 tempstr_cell = cellstr(tempstr);
                % disp('transfered into cellstring');
                 updated_vector(recvCounter) = tempstr_cell;
                % disp('stored into updated_vector');
                 recvCounter = recvCounter - 1;
             end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
   
    leader_total_time = toc(leader_begin_time);
    str = (['updateV_i+1' sprintf('\t') num2str(leader_total_time) sprintf('\n') 'Time received: ' datestr(clock,0) sprintf('\n') ...
        '------------------updatev_i+1 done----------------' sprintf('\n')]);
    disp(str); fwrite(fbug, str);fwrite(fdebug, str);
    
    str = ('Now saving the updatedQ to global file ...');
    this = tic;
    disp(str); fwrite(fbug, str);
    result_string = [updated_vector{1} sprintf('%s', updated_vector{2:end})]; %% convert to char from cell string so we can write to Alluxio
    
    inputFilePathPre = '/mytest';
	inputFilePath=[inputFilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global'];
    %inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
    inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|THROUGH']);
    ALLUXIO_HOME = getenv('ALLUXIO_HOME');
    
    javaMethod('writeFile',inputobject_v, result_string);
    pause(2.0);
    system(['alluxio fs load ' inputFilePath '_v']);
    
	writeTime = toc(this);
	str = (['*****************saving updatedv_i+1 begin*************************' sprintf('\n')...
        'saving updatedv in leader' sprintf('\t') num2str(writeTime) sprintf('\n')]);
	disp(str); fwrite(fbug,str);fwrite(fdebug, str);
    
    pause(2.0);
    %%********************* now asking all working processes to copy the
    %%new v_i_plus_one vector to local machine
     str = ['Now broadcasting copy vector: save_v_i_plus_one_tag to everyone ...' sprintf('\n')];disp(str); %fwrite(fbug,str);
     this = tic;
     numCounter = comm_size - 1;
     done = 0;
        while ~done
          % leader receives all the results.
          if numCounter > leader
              %% dest is who sent this message
              send_tag = save_v_i_plus_one_tag + numCounter;
                 MPI_Send(numCounter, send_tag, comm, con);
                 numCounter = numCounter - 1;
          else % recvCounter  == leader
              done =1;
          end
    end 
     %%%%%%%%%%%%%%%%%%%%%  
     bcast_time = toc(this);
     str= ['Broadcasting' sprintf('\t') num2str(bcast_time) sprintf('\n') ...
         'Broadcasting time: ' datestr(clock, 0) sprintf('\n')];
     disp(str); fwrite(fbug,str);fwrite(fdebug, str);
 
    leader_begin_time = tic;
    done = 0;
    %leader will receive comm_size-1 signals
    output = zeros(1,comm_size-1); 
    
%% Instead of using for loops, use counters to indicate how many processes have
%% completed their tasks.
%% we are doing backwards because in MPI_RUN the highest rank process
%% will be spawned first and it is more likely to complete earlier
    recvCounter = comm_size-1;
    str = ['Waiting for all processes: copy global v_i+1 to finish ...' sprintf('\n')];
    disp(str); fwrite(fbug,str);
    while ~done
          % leader receives all the results.
          if recvCounter > leader
              %% dest is who sent this message
              dest = recvCounter;
              leader_tag = output_tag_four + recvCounter;
             %[message_ranks, message_tags] = MPI_Probe( dest, leader_tag, comm );
             %if ~isempty(message_ranks)
                 output(:,recvCounter) = MPI_Recv(dest, leader_tag, comm);
                 str = (['Received data packet number ' num2str(recvCounter)]);
                 disp(str);fwrite(fbug,str);
                 recvCounter = recvCounter - 1;
             %end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
    leader_total_time = toc(leader_begin_time);
    str = (['copyV_i+1' sprintf('\t') num2str(leader_total_time) sprintf('\n') 'Time received: ' datestr(clock,0) sprintf('\n') ...
        '***********************save updatedv done***************' sprintf('\n')]);
    disp(str); fwrite(fbug, str);fwrite(fdebug, str);
    str= (['=============================Iteration ' num2str(it) ' Done============================' sprintf('\n')]);
    fwrite(fdebug, str);
    %%%%**************************  All working processes done copying
    %%%%v_i_plus_one to local machine.
    
   
else %% working processes

%% TO calculate how much time spending on syn and doing the computation 
fstat = fopen(['timer/' num2str(NumOfMachines) 'machines_' num2str(my_rank+1) '_timer.txt'],'a+');
   
%% path to where the Alluxio files are stored
filePathPre = '/mytest';
i = my_rank+1;  %% my_rank starts from 0 to comm_size-1; so I starts from 1 to comm_size

%% pace is used to save the schedule time from cut table since we have sliced 1048576 into 135 slices. 
%% now we are testing 3 machines, 5machines, 9machines, 16 machines. 
%%   1+7*2= 15, 1+7*4 = 29, 1+ 7*8 = 57, 1+ 7*15 = 136
%{
switch NumOfMachines
    case 3
        pace = 8;
    case 5
        pace = 4;
    case 9
        pace = 2;
    case 16
        pace = 1;
end
%}
%fstat = fopen(['benchmark/v3_' num2str(i) '_proc_MatrixVector.txt'],'w+');
               %% rank 0 is leader process; i ranges from 1 to comm_size-1;
        if(i==2)
        start_col = 1;
        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:))); 
        %pace
        %end_col = str2num(Val(cut_t(sprintf('%d,',(i-1)*pace),:)));
       
        else
                if(i<NumOfProcessors)
                        start_col = str2num(Val(cut_t(sprintf('%d,',(i-2)),:)))+1;
                        end_col = str2num(Val(cut_t(sprintf('%d,',(i-1)),:)));
                        
                end
        end
        if(i==NumOfProcessors)
        start_col = str2num(Val(cut_t(sprintf('%d,',(i-2)),:)))+1;
        end_col = NumOfNodes;
        
        end
        str = (['**************Iteration ' num2str(it) '*****************' sprintf('\n') 'Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
        
        vectorLength = end_col - start_col + 1;
        [idum, my_machine] = system('hostname'); 
        my_machine = strtrim(my_machine);
		str = ['My rank id is: ' num2str(i-1) 'and My machine is: ' my_machine sprintf('\n')];
        disp(str); fwrite(fstat, str);
     
     %% v_i+1 = v/beta
     %% we already have resultVector as part of v
     
     %% get beta:
     str = (['Getting beta value from Accumulo ...' sprintf('\n')]);
     disp(str); fwrite(fstat, str);
     %%%%
     
     if(~isempty(Val(beta_t(sprintf('%d,',it),'1,'))))
        beta_v = str2num(Val(beta_t(sprintf('%d,',it),'1,')));
        beta_it_v = 1./beta_v;
     else
        beta_it_v = 0;
     end
     
     str = ([' Beta value is ' num2str(beta_v) sprintf('\n')]);
     disp(str); fwrite(fstat, str);
     
     
     %% output should be partial vi table and also make a global copy 
     %% each machine has a local copy as well.
     %% we can ignore the row because as long as we know the cut, the row is start_col:end_col
     
     %% We need read resultVector from Alluxio
     file_location = ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
         num2str(i)  'id_tempv'];
     javaResult = readVectorFromAlluxio(file_location);
     resultVector = convertJavaToMat(javaResult);
     vector_i_plus_one = resultVector .* beta_it_v;
     
     vector_i_plus_one_row = sprintf('%d,',start_col:end_col);
     vector_i_plus_one_val = sprintf('%.15f,',vector_i_plus_one);

     %vector = [num2str(NumOfNodes) 'lz_q' num2str(it)];
     %v = DB(vector);
     
    
    %% Done with update Q
    %% Rather than writing to Filesystem, Try to send it back to leader process and see how it performs.
    
    str = (['Done with updateQ, sending signal back to leader process ...' sprintf('\n') 'Time sent: ' datestr(clock, 0) sprintf('\n')]);
	disp(str); fwrite(fstat, str);
    
    leader_tag = output_tag_three + my_rank;
    MPI_Send(leader, leader_tag, comm,vector_i_plus_one_val);
    
    %% saving lz_v_i+1 back to Accumulo the reason is because SO will need access all lz_v{i:iteration} elements.
    vector_name = [num2str(NumOfNodes) 'lz_q' num2str(it+1)];
    v_db = DB(vector_name);
    put(v_db,Assoc(vector_i_plus_one_row, '1,', vector_i_plus_one_val));
    %% saving back to Accumulo done
    
    str = (['Now waiting for leader to send out copying v_i+1 signal ...' sprintf('\n') 'Time started: ' datestr(clock, 0) sprintf('\n')]);disp(str); fwrite(fstat, str);
    send_tag = save_v_i_plus_one_tag + my_rank;
    con = MPI_Recv(leader, send_tag, comm );
    str = (['Received the con signal from leader process now saving V_i+1' sprintf('\n') 'Time received: ' datestr(clock, 0) sprintf('\n')]);disp(str); fwrite(fstat, str);
 
    str = (['Now saving the updatedQ to local machine ...' sprintf('\n')]); disp(str); fwrite(fstat, str);
    pause(2.0); %% add this 2 seconds to make sure the leader process has completed/ alluxio has completed the updated v_i+1
   
    
    this_total = tic;
    
  
    
    %%% *********** only the process with:
    %% my_rank mod (NumOfProcessors - 1)/(NumOfMachines -1) == 0
    %%% 
    %{
    if rem(my_rank, (NumOfProcessors-1)/(NumOfMachines-1)) == 0
      str='copying....';disp(str); fwrite(fstat, str);
       
    FilePathPre = '/mytest';
	inputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global'];
    outputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
    %outputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
    
    inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
    outputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputFilePath '_v' '|CACHE|CACHE_THROUGH']);
    
    %% reading file
    this = tic;
    v_i_plus_one_val = javaMethod('readFile',inputobject_v);
    that = toc(this);
    str=(['Reading from global file costs ' num2str(that) 's' sprintf('\n')]); disp(str); fwrite(fstat, str);
    
    %% writing file
    this = tic;
    javaMethod('writeFile',outputobject_v, v_i_plus_one_val);
    that = toc(this);
    str=(['Writing to local file costs ' num2str(that) 's' sprintf('\n')]); disp(str); fwrite(fstat, str);
    end %% end for writing to local machine
	writeTime = toc(this_total);
	str = (['It takes: ' num2str(writeTime) 's to save to local machine' sprintf('\n')]);disp(str); fwrite(fstat,str);
    %****************
    %}
       %%% *********** only the process with:
    %% my_rank mod (NumOfProcessors - 1)/(NumOfMachines -1) == 0
    %%% 
   
    if rem(my_rank, (NumOfProcessors-1)/(NumOfMachines-1)) == 0
      str='copying....';disp(str); fwrite(fstat, str);
       
    ALLUXIO_HOME = getenv('ALLUXIO_HOME');
    [~,mymachine] = system('hostname');
    mymachine = strtrim(mymachine);
    
    input_filename = [num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v'];
    output_filename = [num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine '_v'] ;
    %disp(output_filename);
    %disp(['scp n117:' ALLUXIO_HOME '/underFSStorage/mytest/' input_filename ' ' ALLUXIO_HOME '/underFSStorage/mytest/' output_filename])
    system(['scp n117:' ALLUXIO_HOME '/underFSStorage/mytest/' input_filename ' ' ALLUXIO_HOME '/underFSStorage/mytest/' output_filename]);
    system(['alluxio fs copyFromLocal ' ALLUXIO_HOME '/underFSStorage/mytest/' output_filename ' /mytest']);
    end %% end for writing to local machine
	writeTime = toc(this_total);
	str = (['It takes: ' num2str(writeTime) 's to save to local machine' sprintf('\n')]);disp(str); fwrite(fstat,str);
    %****************
    
    
    
     %% Done with saving v_i+1    
    mytic = tic;
    leader_tag = output_tag_four + my_rank;
    MPI_Send(leader, leader_tag, comm,my_rank);
    timer = toc(mytic);
    str = (['Done with saving v_i+1, sending signal back to leader process costs ' num2str(timer) sprintf('\n') 'Time sent: ' datestr(clock, 0) sprintf('\n') '**************Iteration ' num2str(it) '*****************' sprintf('\n')]);
	disp(str); fwrite(fstat, str);
    
end %% end for all working processes
fclose(fbug);fclose(fdebug);
disp('Success');
this = tic;
MPI_Finalize;
that = toc(this);
disp(['Finalization costs: ' num2str(that) 's']);


