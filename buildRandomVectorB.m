%function buildRandomVectorB
%%% Usage: This function will run in parallel to build random vector B and
%%%        calculate lz_q1 = B / || B ||

%%  Leader process: 1. wait for worker to finish with rand(vectorsize,1,'double');
%%                      also calculate the partial sum(^2) and saved to lz_norm_B_temp table
%%                  2. Calculate || B || and save the result back to normB table.
%%                  3. Send continue update signal to all worker processes.
%%                  4. Wait for all worker processes to finish 

%% Worker process: 1. Rand(vectorsize, 1, 'double'), calcualte the partial sum to lz_norm_B_temp
%%                 2. Send finish to the leader
%%                 3. wait for update_v1 signal
%%                 4. read ||B|| from normB table and multiply it to B / || B ||
%%                 5. send signal back to the leader 

%% Author: Yin Huang
%% Date: May-6-2016

myDB; %% connect to DB and return a binding named DB.

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
proc_t = DB('NumOfProcessors');
tempB_t = DB('lz_norm_B_temp');
normB_t = DB('normB');

NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(proc_t('1,','1,')));

%% for test purpose
test_flag_t = DB('testVector');
test_nodes_t = DB('testNodes');
test_proc_t = DB('testProc');

test_flag = str2num(Val(test_flag_t(:,:)));

if(test_flag == 1)
    NumOfNodes = str2num(Val(test_nodes_t(:,:)));
    NumOfProcessors = str2num(Val(test_proc_t(:,:)));
end

gap = floor(NumOfNodes/(NumOfProcessors-1));

output_t = DB([num2str(NumOfNodes) 'lz_q1']);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Below is for MPI related %%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

syn1_tag = 10000;
update_v1 = 30000;
syn2_tag = 20000;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% MPI realted done %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fdebug = fopen('benchmark/buildRandomVectorB.txt','a+');
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if (my_rank == leader) %% leader

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  Leader process: 1. wait for worker to finish with rand(vectorsize,1,'double');
%%                      also calculate the partial sum(^2) and saved to lz_norm_B_temp table
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

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
              leader_tag = syn1_tag + recvCounter;
             %[message_ranks, message_tags] = MPI_Probe( dest, leader_tag, comm );
             %if ~isempty(message_ranks)
                 output(:,recvCounter) = MPI_Recv(dest, leader_tag, comm);
                 str = (['Received data packet number ' num2str(recvCounter)]);
                 disp(str);fwrite(fdebug,str);
                 recvCounter = recvCounter - 1;
             %end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
    output
 leader_total_time = toc(leader_begin_time);
   
    str = (['--------------------------Initializing B begin--------------------- ' sprintf('\n') ...
        'Initialize B costs' sprintf('\t') num2str(leader_total_time) sprintf('\n') sprintf('\n') ...
        '--------------------------Initializing B  Done--------------------- ' sprintf('\n') ... 
        '***********************Calculate ||B|| begin**************' sprintf('\n')]);
    disp(str); fwrite(fdebug, str);
    
    %% 2. Calculate || B || and save the result back to normB table.
    [br,bc,bv] =  tempB_t(:,:);
    partial_B_arr = str2num(bv);
    normB_value = sqrt(sum(partial_B_arr));
    put(normB_t,Assoc('1,','1,',sprintf('%.15f,',normB_value)));
   
    %% 3. Send continue update signal to all worker processes.
       str = ['------------------------Update lz_v1 begin-------------------' sprintf('\n')];
        disp(str);  fwrite(fdebug,str);
        this = tic;
     numCounter = comm_size - 1;
     done = 0;
        while ~done
          % leader receives all the results.
          if numCounter > leader
              %% dest is who sent this message
              send_tag = update_v1 + numCounter;
                 MPI_Send(numCounter, send_tag, comm, done);
                 numCounter = numCounter - 1;
             
          else % recvCounter  == leader
              done =1;
          end
    end  
     bcast_time = toc(this);
     str= ['Broadcasting' sprintf('\t') num2str(bcast_time) sprintf('\n')];
     disp(str);fwrite(fdebug, str);
    
     
    %% 4. Wait for all worker processes to finish 
     leader_begin_time = tic;
    done = 0;
    %leader will receive comm_size-1 signals
    output = zeros(1,comm_size-1); 
    
    recvCounter = comm_size-1;
    str = ['Waiting for all processes: update_v1 to finish ...' sprintf('\n')];
    disp(str); fwrite(fdebug,str);
    while ~done
          % leader receives all the results.
          if recvCounter > leader
              %% dest is who sent this message
              dest = recvCounter;
              leader_tag = syn2_tag + recvCounter;
             %[message_ranks, message_tags] = MPI_Probe( dest, leader_tag, comm );
             %if ~isempty(message_ranks)
                 output(:,recvCounter) = MPI_Recv(dest, leader_tag, comm);
                 str = (['Received data packet number ' num2str(recvCounter)]);
                 disp(str);fwrite(fdebug,str);
                 recvCounter = recvCounter - 1;
             %end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
    output
    leader_total_time = toc(leader_begin_time);
    str = (['update_v1' sprintf('\t') num2str(leader_total_time) sprintf('\n') ...
        '--------------------------update_v1 done-----------------------' sprintf('\n')]);
    disp(str);fwrite(fdebug, str);
    
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%leader done %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
else % worker node
%% TO calculate how much time spending on syn and doing the computation 
fstat = fopen(['timer/buildRandomB_' num2str(my_rank+1) '_id_timer.txt'],'a+');

i = my_rank+1;  %% my_rank starts from 0 to comm_size-1; so I starts from 1 to comm_size
%% Worker process: 1. Rand(vectorsize, 1, 'double'), calcualte the partial sum to lz_norm_B_temp
        start_node = (i-2)*gap+1;
        if(i<comm_size)
        end_node = (i-1)*gap;
        else
        end_node = NumOfNodes;
        end
        length = end_node - start_node+1;
    
        str = (['my i: ' num2str(i) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
         str = (['start node: ' num2str(start_node) ' end_node: ' num2str(end_node) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
        
        rowStr = sprintf('%d,',start_node:end_node);
        %disp(rowStr);
        rand('seed',i); %set the seed particular for i so we don't generate the same data
        val_arr = rand(1,length,'double');
        %disp([sprintf('%.15f,',val_arr)]);
        partial_sum = sum(val_arr.^2);
        put(tempB_t,Assoc(sprintf('%d,',my_rank),'1,',sprintf('%.15f,',partial_sum)));
%%                 2. Send finish to the leader
        mytic = tic;
        leader_tag = syn1_tag + my_rank;
        MPI_Send(leader, leader_tag, comm,my_rank);
        timer = toc(mytic);
        
        str = (['sending syn1_tag costs: ' num2str(timer) sprintf('\n')]);
        disp(str); fwrite(fstat,str);

%%                 3. wait for update_v1 signal

         str = (['Waiting for leader to continue to update_v1... ' sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         send_tag = update_v1 + my_rank;
         con = MPI_Recv(leader, send_tag, comm );  %%% receive bcast_tag
         
         str = (['Received the con signal from leader process now update_v1' sprintf('\n') ]);
         disp(str); fwrite(fstat, str);
         
%%                 4. read ||B|| from normB table and multiply it to B / || B ||
          normB = str2num(Val(normB_t(:,:)));
          lz_q1_val = val_arr ./ normB;
          
     %%% insert by chunk because the arr is too large  
     rowStr = sprintf('%d,',start_node:end_node);
     chunksize = 62500;
     
    insert_step = floor(length / chunksize);
    
    for index=1:insert_step
        if index == insert_step
            chunk_val_arr = lz_q1_val((index-1)*chunksize+1:end_node);
            put(output_t,Assoc(sprintf('%d,',start_node+(index-1)*chunksize:end_node),'1,', sprintf('%.15f,',chunk_val_arr),@min));
      
        else
            chunk_val_arr = lz_q1_val((index-1)*chunksize+1:index*chunksize);
            put(output_t,Assoc(sprintf('%d,',start_node+(index-1)*chunksize:start_node+index*chunksize),'1,', sprintf('%.15f,',chunk_val_arr),@min));
 
        end
        
    end
          
         % put(output_t, Assoc(rowStr,'1,',sprintf('%.15f,',lz_q1_val)));

%%                 5. send signal back to the leader 
        mytic = tic;
        leader_tag = syn2_tag + my_rank;
        MPI_Send(leader, leader_tag, comm,my_rank);
        timer = toc(mytic);
        str = (['sending syn2_tag costs: ' num2str(timer) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% worker done %%%%%%%%%%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
end
