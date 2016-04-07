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

myDB; %% connect to DB and return a binding named DB.

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
alpha_t = DB('alpha');
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

num = DB(['Entries' num2str(NumOfNodes)]);  %% This table stores the elements for each column

%%  initialize alpha() and beta()

alpha = zeros(1,10);
bet = zeros(1,10);



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
    str = (['Leader process for matrix*vector runs: ' num2str(leader_total_time) sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    %fclose(fbug); %% debug for matrix * vector done
    
    %%%
    
    
    str = (['Leader process now calculates the value of alpha[it]' sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    [tRow,tCol,tVal] = dot_temp(sprintf('%d,',1:NumOfProcessors),:); %% This range query works for rows not for cols so this is fine.

    if(~isempty(tVal))
%tVal = str2num(tVal);
    tVal=sscanf(tVal,'%f');
    it_alpha = sum(tVal);
    else 
    it_alpha = 0;
    end
    	this = tic;
        alpha(it) = it_alpha;
        that = toc(this);
        str = (['Calculation alpha costs ' num2str(that) 's' sprintf('\n')]);
        disp(str); fwrite(fbug,str);
        delete(dot_temp);
     alpha_temp_Assoc = Assoc(sprintf('%d,',it),'1,',sprintf('%.15f,',alpha(it)));
        put(alpha_t, alpha_temp_Assoc);
        str = ['Result of alpha[' num2str(it) '] =' num2str(alpha(it)) ' is saved.' sprintf('\n')];
        disp(str); fwrite(fbug,str);
    
   
        
    %%%%%%%%%% Done with Matrix * vector and calculating the alpha %%%%%%%%%%%%
 
   
    %%%%%% Now begin to calculate onetime_saxv
    %1. leader broadcast a signal to proceed with vi*v for all working
    %processes
    
     % Broadcast coefficients to everyone else.   Now continuing to onetimesaxv ...
     str = ['Now broadcasting onetimesaxv con_tag to everyone ...' sprintf('\n')];
        disp(str); fwrite(fbug,str);
        this = tic;
       
     %  MPI_Bcast(leader, con_tag, comm, con ); %% MPI_Recv(leader, con_tag, comm );
       
     %%%%%%%%%%%%%%%%%%%%%
     numCounter = comm_size - 1;
     done = 0;
        while ~done
          % leader receives all the results.
          if numCounter > leader
              %% dest is who sent this message
              send_tag = onetime_saxv_tag + numCounter;
                 MPI_Send(numCounter, send_tag, comm, con);
                 numCounter = numCounter - 1;
             
          else % recvCounter  == leader
              done =1;
          end
    end 
     %%%%%%%%%%%%%%%%%%%%%  
     bcast_time = toc(this);
     str= ['Broadcasting costs: ' num2str(bcast_time) 's' sprintf('\n')];
     disp(str); fwrite(fbug,str);
   % con = MPI_Recv(leader, con_tag, comm );
    %%%%%%% start next step in the algorithm
    leader_begin_time = tic;
    done = 0;
    %leader will receive comm_size-1 signals
    output = zeros(1,comm_size-1); 
    
%% Instead of using for loops, use counters to indicate how many processes have
%% completed their tasks.

%% we are doing backwards because in MPI_RUN the highest rank process
%% will be spawned first and it is more likely to complete earlier
    recvCounter = comm_size-1;
    str = ['Waiting for all processes: onetime_saxv to finish ...' sprintf('\n')];
    disp(str); fwrite(fbug,str);
    while ~done
          % leader receives all the results.
          if recvCounter > leader
              %% dest is who sent this message
              dest = recvCounter;
              
              
              leader_tag = output_tag_second + recvCounter;
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
    str = (['Leader process for onetimesaxv runs: ' num2str(leader_total_time) sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    %fclose(fbug);
    
    %% leader process calculate beta p2
    
    str = ['Leader process Computing beta[' num2str(it) ']...'];
    disp(str); fwrite(fbug,str)
    this = tic;
	%parallel_lz_norm_v_p2; %% scalar_v is written to beta_i in the table beta_t('i,','1,')
	 [temp_t_Row,temp_t_Col,temp_t_Val] = norm_v_temp(sprintf('%d,',1:NumOfProcessors),:);
 if(isempty(temp_t_Val))
	scalar_v = 0;
 else scalar_v = sum(str2num(temp_t_Val));
 end   %%% Calcualate the total sum of the values	
%disp(['Before sqrt: ' sprintf('%.15f,', scalar_v)]);
scalar_v = sqrt(scalar_v);
    scalar_v_assoc = Assoc(sprintf('%d,',it),'1,',sprintf('%.15f,',scalar_v));
    put(beta_t, scalar_v_assoc);
    
    that = toc(this);
    str = ['Iteration ' num2str(it) ' beta takes: '  num2str(that) sprintf('\n')];
	disp(str); fwrite(fbug, str);

	bet(it) = scalar_v;
	delete(norm_v_temp);
	disp(['beta[' num2str(it) '] = ' num2str(bet(it))]);
    
    
    
    %% beta p2 done.
    
    %%%%%%%    UPDATE Q %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    %% Now leader process broadcast updateQ flag again so that working processes will update vi
    %% v_i+1 = v/beta
    % Broadcast continue to everyone else.
   % MPI_Bcast(leader, updateq_tag, comm, con);
    
   %%%%%%%%%%%%%%%%
    %%%%%%%%%%%%%%%%%%%%%
    str = ['Now broadcasting updateq_tag to everyone ...' sprintf('\n')];
        disp(str); fwrite(fbug,str);
        this = tic;
    
     numCounter = comm_size - 1;
     done = 0;
        while ~done
          % leader receives all the results.
          if numCounter > leader
              %% dest is who sent this message
              send_tag = updateq_tag + numCounter;
                 MPI_Send(numCounter, send_tag, comm, con);
                 numCounter = numCounter - 1;
             
          else % recvCounter  == leader
              done =1;
          end
        end 
    bcast_time = toc(this);
     str= ['Broadcasting costs: ' num2str(bcast_time) 's' sprintf('\n')];
     disp(str); fwrite(fbug,str);
   
  %%%%%%%%%%%%%%%%
    %%%%%%% start next step in the algorithm
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
                 disp(MPI_Recv(dest, leader_tag, comm));
                 %updated_vector(recvCounter) = cellstr(MPI_Recv(dest, leader_tag, comm))
                 recvCounter = recvCounter - 1;
             end
          else % recvCounter  == leader
              done =1;
          end
    end %% end of leader process while
   
    leader_total_time = toc(leader_begin_time);
    str = (['Leader process for updateQ runs: ' num2str(leader_total_time) sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    
    str = ('Now saving the updatedQ to global file ...');
    this = tic;
    disp(str); fwrite(fbug, str);
    result_string = [updated_vector{1} sprintf('%s', updated_vector{2:end})];
    
    inputFilePathPre = '/mytest';
	inputFilePath=[inputFilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global'];
    inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
    

    javaMethod('writeFile',inputobject_v, result_string);
    
	writeTime = toc(this);
	str = (['takes: ' num2str(writeTime) 's' sprintf('\n')]);
	disp(str); fwrite(fbug,str);
    
    pause(2.0);
    %%********************* now asking all working processes to copy the
    %%new v_i_plus_one vector to local machine
     str = ['Now broadcasting copy vector: save_v_i_plus_one_tag to everyone ...' sprintf('\n')];disp(str); fwrite(fbug,str);
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
     str= ['Broadcasting costs: ' num2str(bcast_time) 's' sprintf('\n')];
     disp(str); fwrite(fbug,str);
 
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
    leader_total_time = toc(leader_begin_time);
    str = (['Leader process for copyV_i+1 runs: ' num2str(leader_total_time) sprintf('\n')]);
    disp(str); fwrite(fbug, str);
    
    %%%%**************************  All working processes done copying
    %%%%v_i_plus_one to local machine.
    
   
else %% working processes

%% path to where the Alluxio files are stored
filePathPre = '/mytest';
i = my_rank+1;  %% my_rank starts from 0 to comm_size-1; 

fstat = fopen(['benchmark/v3_' num2str(i) '_proc_MatrixVector.txt'],'w+');
               %% rank 0 is leader process; i ranges from 1 to comm_size-1;
        if(i==2)
        start_col = 1;
        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
        p_end_col = 0;
        else
                if(i<NumOfProcessors)
                        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
                        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
                        p_end_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)));
                end
        end
        if(i==NumOfProcessors)
        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
        end_col = NumOfNodes;
        p_end_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)));
        end
        str = (['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
        
        vectorLength = end_col - start_col + 1;
	%% version 2: reading vector from Alluxio, each process should know which machine it belongs to.
     
    
               [idum, my_machine] = system('hostname'); 
               my_machine = strtrim(my_machine);
		 str = ['My rank id is: ' num2str(i-1) 'and My machine is: ' my_machine sprintf('\n')];
                disp(str); fwrite(fstat, str);		
		
%%%%%%%%%%%%%%%% After setting the machine number, we know where to read the vector from.
		str = (['Now reading vector from Alluxio' sprintf('\n')]);
		disp(str); fwrite(fstat, str);
		
		inputFilePathPre = '/mytest';
		%inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
		inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
        
		%inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
       	inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
		this = tic;
		%vi_row = javaMethod('readFile',inputobject_r);
		vi_val = javaMethod('readFile',inputobject_v);
		readv=toc(this);
		str = ['Read vector takes: ' num2str(readv) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);
		
		str = ['Now constructing the vector'];
		this = tic;
		disp(str); fwrite(fstat, str);
		%my_row = char(vi_row); 
        my_val = char(vi_val);
		%my_row = sscanf(my_row, '%d'); 
        my_val = sscanf(my_val,'%f');
        my_row = 1:NumOfNodes;
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
                        	str = ['Construct sparse: ' num2str(const) 's' sprintf('\n') ];
                         disp(str);fwrite(fstat, str);

                        this = tic;
                        myresult = onepartofmatrix * myVector;
                        multt = toc(this);
                        str= ['Multiplication: ' num2str(multt) 's' sprintf('\t') ];
                        disp(str); fwrite(fstat,str );
		

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%% below writing result back to Alluxio 
		%% [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id' {_r _v} ];
		%{
        outputFilePathPre = '/test';
		outputPath = [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
		%%%%
		%% create the object to write to Alluxio
		str = (['Start writing result back to local lz_vpath alluxio ...  ']);
		disp(str);fwrite(fstat,str);
		myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_r' '|CACHE|CACHE_THROUGH']);
        myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_v' '|CACHE|CACHE_THROUGH']);
		this = tic;
		str_r = sprintf('%d,',start_col:end_col);
		str_v = sprintf('%.15f,',full(myresult));
	        javaMethod('writeFile',myobject_r,str_r);
        	javaMethod('writeFile',myobject_v,str_v);
		writeTime = toc(this);
		str = ([num2str(writeTime) 's' sprintf('\n')]);
		disp(str); fwrite(fstat,str);
        fwrite(fstat, ['Done with writing back mat*vec result back to Alluxio' ]);
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %}
        
		
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Now calculating parallel dot vi*v, we already have part of v calculated locally and we have the whole vi. 
        %% grab part of vi according to the cut table and grab corresponding result of v and do the math parallel_dot_p1
        %% part of v below:
        v_val = full(myresult);
        str = (['Now start calculating vi * v' sprintf('\n')]);   disp(str); fwrite(fstat,str);

        %% total vi is below: 
        myVi = full(myVector);
        %% construct part of vi from start_col:end_col;
        part_myVi = myVi(start_col:end_col);
        
        part_alpha = part_myVi'*v_val;
        str = (['Now writing result back to Accumulo ...' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		this = tic;
        newAssoc = Assoc(sprintf('%d,',(i-1)),'1,',sprintf('%.15f,',part_alpha));
        wb_t = toc(this);
		str= (['Writing back: ' num2str(wb_t) 's' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
        put(dot_temp,newAssoc);
        

         
         %% **************** done with matrix* vector  ******************
         leader_tag = output_tag + my_rank;
         MPI_Send(leader, leader_tag, comm,my_rank);
         %%% ******************************************************
           
         
         
         %%
         %% working process receive the leader's broadcast msg
         str = (['Waiting for leader to continue to onetime_saxv... ' sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         send_tag = onetime_saxv_tag + my_rank;
         con = MPI_Recv(leader, send_tag, comm );  %%% receive bcast_tag
         
         str = (['Received the con signal from leader process now calculating onetime_saxv' sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         
         %%%
         %%%
         % v = v - beta_sax_temp - alpha_sax_temp ; if it>1 in one function
%%		   v = v - alpha_sax_temp; if i==1

        % first we get alpha
        
         [alphaR,alphaC,alphaV]= alpha_t(sprintf('%d,',it),:);
		 if (isempty(alphaV))
        	alpha_value = 0;
         else
        	alpha_value = str2num(alphaV);
         end
         str=(['alpha value is: ' num2str(alpha_value) sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         
         %% construct part of vi from start_col:end_col;
         %part_myVi = myVi(start_col:end_col);  n*1 dimension
         vi_vector = part_myVi .* alpha_value;
         
     if(it == 1)%%  v = v - alpha_sax_temp; if i==1
            
            %% v_vector is from result: v_val (dimension: n*1)
            resultVector = v_val - vi_vector; 

      else %%v = v - beta_sax_temp - alpha_sax_temp ; if it>1
             % v is v_val : n*1 dimension
             %% we get beta_i-1
             str = (['This is when it > 1' sprintf('\n')]);
             disp(str); fwrite(fstat, str);
            [betaRow,betaCol,betaVal]=beta_t(sprintf('%d,',it-1),:);
        	if(~isempty(betaVal))
                beta_value = str2num(betaVal);
            else
                beta_value = 0;
            end
            %%% we get beta_i-1
            
            %%now we read from Alluxio v_i-1  ATTENTION: at the end we need
            %%aggregate all partial vi into a global copy and each machine
            %%obtain one copy
            str = (['Now reading vector i-1 from Alluxio' sprintf('\n')]);
		disp(str); fwrite(fstat, str);
		
		inputFilePathPre = '/mytest';
		inputFilePath=[inputFilePathPre '/' num2str(it-1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
		
		inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
       	inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
		this = tic;
		vi_row = javaMethod('readFile',inputobject_r);
		vi_val = javaMethod('readFile',inputobject_v);
		readv=toc(this);
		str = ['Read vector i-1 takes: ' num2str(readv) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);
		
		str = ['Now constructing the vector i-1'];
		this = tic;
		disp(str); fwrite(fstat, str);
		my_row = char(vi_row); my_val = char(vi_val);
		my_row = sscanf(my_row, '%d'); my_val = sscanf(my_val,'%f'); 	
		myVectorMinus1 = sparse(my_row, 1, my_val, NumOfNodes, 1);
        myVectorMinus1 = full(myVectorMinus1);
		transV = toc(this);	
		str = ['Construction of vector done! It takes ' num2str(transV) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);
        %%
        
        %% get part vi_1 into vi1_vector
        vi1_vector = myVectorMinus1(start_col:end_col);
        vi1_mul_beta_vector = vi1_vector .* beta_value;
        
          %% v_vector is from result: v_val (dimension: n*1) 
        resultVector = v_val - vi_vector - vi1_mul_beta_vector;

     end %% end for calculating onetime_saxv
      %% meanwhile we calculate norm of resultVector
            %%!!!!!!!!!! To be filled with 
         
         norm_result_vector = norm(resultVector)^2;
         put(norm_v_temp,Assoc(sprintf('%d,',i-1),'1,',sprintf('%.15f,',norm_result_vector)));
        
         
         
     %% Done with onetime_saxv send signal back to leader process
      str =(['Done with onetime_saxv, sending signal back to leader ...' sprintf('\n')]);
     disp(str); fwrite(fstat, str);
     leader_tag = output_tag_second + my_rank;
     MPI_Send(leader, leader_tag, comm,my_rank);
    
     
     %% Waiting for leader to send signal to continue to updateQ
     str = (['Waiting for leader to continue update V... ' sprintf('\n')]);
     disp(str); fwrite(fstat, str);
     send_tag = updateq_tag + my_rank;
     con = MPI_Recv(leader, send_tag, comm );
     str = (['Received the con signal from leader process now updating V' sprintf('\n')]);
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
     
     vector_i_plus_one = resultVector .* beta_it_v;
     
     %vector_i_plus_one_row = sprintf('%d,',start_col:end_col);
     vector_i_plus_one_val = sprintf('%.15f,',vector_i_plus_one)
     
    
    %% Done with update Q
    %% Rather than writing to Filesystem, Try to send it back to leader process and see how it performs.
    
    str = (['Done with updateQ, sending signal back to leader process ...' sprintf('\n')]);
	disp(str); fwrite(fstat, str);
    
    leader_tag = output_tag_three + my_rank;
    MPI_Send(leader, leader_tag, comm,vector_i_plus_one_val);
     
    str = (['Now waiting for leader to send out copying v_i+1 signal ...' sprintf('\n')]);disp(str); fwrite(fstat, str);
    send_tag = save_v_i_plus_one_tag + my_rank;
    con = MPI_Recv(leader, send_tag, comm );
    str = (['Received the con signal from leader process now saving V_i+1' sprintf('\n')]);disp(str); fwrite(fstat, str);
 
    str = (['Now saving the updatedQ to local machine ...' sprintf('\n')]); disp(str); fwrite(fstat, str);
   
    this_total = tic;
    
    [idum, my_machine] = system('hostname'); my_machine = strtrim(my_machine); 
    
    FilePathPre = '/mytest';
	inputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global'];
    %outputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
    outputFilePath=[FilePathPre '/' num2str(it+1) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
    
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
  
	writeTime = toc(this_total);
	str = (['It takes: ' num2str(writeTime) 's to save to local machine' sprintf('\n')]);disp(str); fwrite(fstat,str);
    %****************
    
     %% Done with saving v_i+1    
    str = (['Done with saving v_i+1, sending signal back to leader process ...' sprintf('\n')]);
	disp(str); fwrite(fstat, str);
    
    leader_tag = output_tag_four + my_rank;
    MPI_Send(leader, leader_tag, comm,my_rank);
    
    
         end %% end for all working processes

disp('Success');
this = tic;
MPI_Finalize;
that = toc(this);
disp(['Finalization costs: ' num2str(that) 's']);



%% function MPI_Send( dest, tag, comm, varargin )
%% function varargout = MPI_Recv( source, tag, comm )






%disp('Sending to agg');
%fwrite(fstat,['Sending to agg']);
%agg(w);
%disp('Agg is done! I am closed now');
%fwrite(fstat, ['Agg is done! I am closed now.']);
%fclose(fstat);
