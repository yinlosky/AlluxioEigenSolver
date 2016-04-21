%filename: parallel_SO
%   Detailed explanation goes here
%{
 parallel_SO implements all the below functions into one MPI call.
 What parallel_SO does is to do v = v - rtvr*v:
 
 The file location of v is:
 file_location = ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
     num2str(i)  'id_tempv'];
  
  vi is stored at: vector_name = [num2str(NumOfNodes) 'lz_q' num2str(it+1)];

  rtv result is saved in rtv_result table in accumulo 

eval(pRUN('parallel_computeR',NumOfProcessors,machines));
 %% should write to 'so_rpath', all processes should know the cur_it as k, 
cur_loop_j as j, 
Q is the eigenVector matrix from T %%%%%%%
 eval(pRUN('parallel_rtv_p1',NumOfProcessors,machines));
 parallel_rtv_p2;	
 p_rtv_temp = DB('rtv_temp');delete(p_rtv_temp);
eval(pRUN('parallel_so_rrtv',NumOfProcessors,machines)); %% times 'so_rpath' with 'scalar_rtv' and store in 'so_rrtv'
eval(pRUN('parallel_so_updatev',NumOfProcessors,machines)); %% lz_vpath is finally updated!!
%}
totaltic = tic;
%disp(['****************** Now Running Alluxio_Row_mv_version3.m ***********************']);
format long;
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
so_rtv_temp = DB('so_rtv_temp');
cur_loop_j = DB('cur_loop_j');
rtv_table = DB('rtv_result');

NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(proc_t('1,','1,')));

norm_v_temp = DB(['lz_norm_v' num2str(NumOfNodes) '_temp']);

it = str2num(Val(cur_it('1,','1,')));  %% current iteration
row = it;
col = str2num(Val(cur_loop_j('1,','1,')));
m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors

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

onetime_saxv_tag = 50000;

updateq_tag = 60000;

save_v_i_plus_one_tag = 70000;

con = 1;

fbug = fopen(['benchmark/' num2str(NumOfMachines) 'machines_' num2str(my_rank+1) ... 
    '_proc_so.txt'],'w+');
fdebug = fopen('benchmark/parallel_so_stat.txt','a+');
% Leader: just waiting to receive all signals from working processes
if(my_rank == leader)
    
    %% waiting for workers to complete calculating r. 
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
    output
    leader_total_time = toc(leader_begin_time);
    str= (['=============================Parallel_SO begins in Iteration ' num2str(it) ...
        '============================' sprintf('\n')]);
    fwrite(fdebug, str);
    str = (['--------------------------ComputeR begin--------------------- ' sprintf('\n') ...
        'MV' sprintf('\t') num2str(leader_total_time) sprintf('\n') 'Time received: ' ...
        datestr(clock,0) sprintf('\n') ...
        '--------------------------ComputeR Done--------------------- ' ... 
        '***********************leader calculates rtv begin**************' sprintf('\n')]);
    disp(str); fwrite(fbug, str);fwrite(fdebug, str);
    
    %% rtv result saved in accumulo table @rtv_part 
    %% Leader process sums up the value in table @rtv_part and write result 
    %% to @rtv, row is the iteration number, val is the result.
    str = (['Leader process now calculates the value of rtv in iteration [' num2str(it) ']' sprintf('\n')]);
    this = tic;
    disp(str); fwrite(fbug, str);
    [tRow,tCol,tVal] = so_rtv_temp(sprintf('%d,',1:NumOfProcessors),:); %% This range query works for rows not for cols so this is fine.

    if(~isempty(tVal))
%tVal = str2num(tVal);
    tVal=sscanf(tVal,'%f');
    rtv_val = sum(tVal);
    else 
    rtv_val = 0;
    end
    
        that = toc(this);
        str = (['rtv_val calculation' sprintf('\t') num2str(that) sprintf('\n') ...
        '***********************rtv_val done*****************' sprintf('\n')]);
        disp(str); fwrite(fbug,str);fwrite(fdebug, str);
        delete(so_rtv_temp);
        rtv_temp_Assoc = Assoc(sprintf('%d,',it),'1,',sprintf('%.15f,',rtv_val));
        put(rtv_table, rtv_temp_Assoc);

    %%%%%%%%%% Done calculating rtv and saved in table: rtv_table %%%%%%%%%%%%
 
   
    %%%%%% Now begin to calculate update_v
    %1. leader broadcast a signal to proceed with vi*v for all working
    %processes
    
     % Broadcast coefficients to everyone else.   Now continuing to onetimesaxv ...
     str = ['------------------------updateV begin-------------------' ... 
        'Time broadcasts: ' datestr(clock, 0) sprintf('\n')];
        disp(str); fwrite(fbug,str); fwrite(fdebug,str);
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
     str= ['Broadcasting done time: ' datestr(clock,0) sprintf('\n') 'Broadcasting' sprintf('\t') num2str(bcast_time) sprintf('\n')];
     disp(str); fwrite(fbug,str);fwrite(fdebug, str);
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
    str = ['Waiting for all processes: updatev to finish ...' sprintf('\n')];
    disp(str); fwrite(fbug,str);
    while ~done
          % leader receives all the results.
          if recvCounter > leader
              %% dest is who sent this message
              dest = recvCounter;
              
              
              leader_tag = output_tag_second + recvCounter;
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
    output
    leader_total_time = toc(leader_begin_time);
    str = (['updatev' sprintf('\t') num2str(leader_total_time) sprintf('\n') ...
        'Time received: ' datestr(clock,0) sprintf('\n') ...
        '--------------------------updatev done-----------------------' sprintf('\n')]);
    disp(str); fwrite(fbug, str);fwrite(fdebug, str);
    
    
       
    str = ['Leader process Computing beta[' num2str(it) ']...'];
    disp(str); fwrite(fbug,str)
    str = ['************************beta begins********************' sprintf('\n')];
    disp(str); fwrite(fbug, str);fwrite(fdebug, str);
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
    str = ['beta' sprintf('\t')  num2str(that) sprintf('\n') ...
       '************************beta done*******************' sprintf('\n') ];
	disp(str); fwrite(fbug, str);fwrite(fdebug, str);

	bet(it) = scalar_v;
	delete(norm_v_temp);
	disp(['beta[' num2str(it) '] = ' num2str(bet(it))]);
  
else %% working processes

%% TO calculate how much time spending on syn and doing the computation 
fstat = fopen(['timer/parallel_so_' num2str(NumOfMachines) 'machines_' num2str(my_rank+1) '_timer.txt'],'a+');
   
%% path to where the Alluxio files are stored
filePathPre = '/mytest';
i = my_rank+1;  %% my_rank starts from 0 to comm_size-1; so I starts from 1 to comm_size

%% pace is used to save the schedule time from cut table since we have sliced 1048576 into 135 slices. 
%% now we are testing 3 machines, 5machines, 9machines, 16 machines. 
%%   1+7*2= 15, 1+7*4 = 29, 1+ 7*8 = 57, 1+ 7*15 = 136
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

%fstat = fopen(['benchmark/v3_' num2str(i) '_proc_MatrixVector.txt'],'w+');
               %% rank 0 is leader process; i ranges from 1 to comm_size-1;
        if(i==2)
        start_col = 1;
        %end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:))); before using
        %pace
        end_col = str2num(Val(cut_t(sprintf('%d,',(i-1)*pace),:)));
       
        else
                if(i<NumOfProcessors)
                        start_col = str2num(Val(cut_t(sprintf('%d,',(i-2)*pace),:)))+1;
                        end_col = str2num(Val(cut_t(sprintf('%d,',(i-1)*pace),:)));
                        
                end
        end
        if(i==NumOfProcessors)
        start_col = str2num(Val(cut_t(sprintf('%d,',(i-2)*pace),:)))+1;
        end_col = NumOfNodes;
        
        end
        str = (['**************Iteration ' num2str(it) '*****************' sprintf('\n') 'Start_col : end_col ' ...
        num2str(start_col) ' : ' num2str(end_col) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
        
        vectorLength = end_col - start_col + 1;
      
        
        %%%%% reading tempv from Alluxio_Row_mv_version5_p1.m 
		str = (['Now reading vector from Alluxio' sprintf('\n')]);
		disp(str); fwrite(fstat, str);
		
        
        %file_location = ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
        % num2str(i)  'id_tempv'];
        
		inputFilePathPre = '/mytest';
		inputFilePath=[inputFilePathPre '/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
            num2str(i) 'id_tempv'];
		v_val = readVectorFromAlluxio(inputFilePath);
        
		
		str = ['Now constructing the vector'];
		this = tic;
		disp(str); fwrite(fstat, str);
		%my_row = char(vi_row); 
        my_val = char(v_val);
		%my_row = sscanf(my_row, '%d'); 
        my_val = sscanf(my_val,'%f');
        my_row = 1:vectorLength;
		myVector = sparse(my_row, 1, my_val, vectorLength, 1);
		transV = toc(this);	
		str = ['Construction of vector done! It takes ' num2str(transV) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);	
		
        %%%%% reading tempv done in myVector %%%%%%%%%%%%%%%%%
        
        %%%%% start computingR  %%%%%%%%%%%%%%%%
        str = ['Now computingR'];
		this = tic;
		disp(str); fwrite(fstat, str);
		
        
        %===== decompose R_TMatrix  begin
        alpha_arr = zero(1,row);
        if (row-1 > 1)
        beta_arr = zero(1,row-1);
        end
        for temp_ind = 1:row
         alpha_arr(1,temp_ind) = str2num(Val(alpha_t(sprintf('%d,',temp_ind),:)));
        end
        main_diag = alpha_arr;
        
        if(row<2)
            R_Tmatrix = diag(main_diag);
        else
            main_diag = alpha_arr;
            for temp_ind = 1:row-1
            beta_arr(1,temp_ind) = str2num(Val(beta_t(sprintf('%d,',temp_ind),:)));
            end
            off_diag = beta_arr;
            R_Tmatrix = diag(main_diag) + diag(off_diag,1) + diag(off_diag,-1);
        end

        [myQ, myD] = eig(R_Tmatrix);
        %===== decompose R_Tmatrix done
        
        %%=======prepare accessing {NumOfNodes}lz_q{it} ====== 
        v_prefix = ([num2str(NumOfNodes) 'lz_q']);   %% v_prefix is lz_q to retrieve the tables named from lz_q{1:row}
        table_names = cell(row,1);
        for i = 1:row
            table_names{i} = [v_prefix num2str(i)];
        end
        tables = cell(row,1);
        for i = 1:row
            tables{i} = DB(table_names{i});
        end
        %%=======prepare accessing {NumOfNodes}lz_q{it} done ====
        
        
        %%====== start computing R =========
        RVector=[];
        for j = start_col:end_col  % j is the row id for output
        row_sum = 0;
            for k = 1:row             % k is the matrix row iterator id we need read elements from lz_q{1:row} also k is the row id for vector Q	
             v_k = myQ(k,col);	  % v_k is the k-th row from col-th column of Q; v_k will multiply j-th row from lz_q{1:row}
             table = tables{k};
                if(~isempty(table(sprintf('%d,',j),'1,')))
                m_k = str2num(Val(table(sprintf('%d,',j),'1,')));
                else
                m_k=0;
                end 
            row_sum = row_sum + v_k*m_k;
            end
        RVector(size(RVector,2)+1) =row_sum;  
        end
	    %put(R_output,Assoc(sprintf('%d,',start_col:end_col),'1,',sprintf('%.15f,',valVector)));
	    %% RVector is the result.
        
        transV = toc(this);
		str = ['ComputingR done! It takes ' num2str(transV) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);	
        
        
		
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %% Now calculating parallel dot vi*v, we already have part of v calculated locally and we have the whole vi. 
        %% grab part of vi according to the cut table and grab corresponding result of v and do the math parallel_dot_p1
        %% part of v below:
        str = (['Now start calculating rt * v' sprintf('\n')]);   disp(str); fwrite(fstat,str);
        mytic = tic;
        
        v_val = full(myVector);
        r_prime = RVector';

        part_alpha = r_prime*v_val;
        
        str = (['Now writing result back to Accumulo ...' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		this = tic;
        newAssoc = Assoc(sprintf('%d,',i),'1,',sprintf('%.15f,',part_alpha));
        wb_t = toc(this);
		str= (['Writing back: ' num2str(wb_t) 's' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
        put(so_rtv_temp,newAssoc);
        
        timer = toc(mytic);
        str = (['vi*v costs ' num2str(timer) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
         
        str = (['Now sending done vi * v to leader process']);
        disp(str); fwrite(fstat,str);
        
        mytic = tic;
        %% **************** done with rtv  ******************
        
        
        leader_tag = output_tag + my_rank;
        MPI_Send(leader, leader_tag, comm,my_rank);
        timer = toc(mytic);
        str = (['sending signal costs: ' num2str(timer) sprintf('\n') 'Time sent: ' ...
            datestr(clock, 0) sprintf('\n')]);
        disp(str); fwrite(fstat,str);
      
         %%% ******************************************************
         %%
         %% working process receive the leader's broadcast msg
         str = (['Waiting for leader to continue to updateV... ' sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         send_tag = onetime_saxv_tag + my_rank;
         con = MPI_Recv(leader, send_tag, comm );  %%% receive bcast_tag
         
         str = (['Received the con signal from leader process now updating v' ...
             sprintf('\n') 'Time received: ' datestr(clock, 0) sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         
         %%% v = v - rtv*r
     

        % first we get rtv
        
         [alphaR,alphaC,alphaV]= rtv_table(sprintf('%d,',it),:);
		 if (isempty(alphaV))
        	my_rtv_value = 0;
         else
        	my_rtv_value = str2num(alphaV);
         end
         str=(['rtv value is: ' num2str(my_rtv_value) sprintf('\n')]);
         disp(str); fwrite(fstat, str);
         %%%%%%
        
         rtvr_vector = my_rtv_value .* RVector;
         
         myVector = myVector - rtvr_vector;
          
      %% meanwhile we calculate norm of resultVector
         
         norm_result_vector = norm(myVector)^2;
         put(norm_v_temp,Assoc(sprintf('%d,',(i-1)),'1,',sprintf('%.15f,',norm_result_vector)));
                 
         
         
     %% Done with onetime_saxv send signal back to leader process
     mytic = tic;
     leader_tag = output_tag_second + my_rank;
     MPI_Send(leader, leader_tag, comm,my_rank);
     timer = toc(mytic);
     str =(['Done with updatingV, sending signal back to leader ...' sprintf('\n') 'Time sent: ' ...
     datestr(clock, 0) sprintf('\n')]);
     disp(str); fwrite(fstat, str);
     
     %% We need save resultVector to alluxio because p2 will need read the result
         %%% saveToAlluxio(FileLocation, Msg); 
         msg = sprintf('%.15f', myVector);
         file_location = ['/mytest/' num2str(NumOfNodes) 'nodes_' num2str(it) 'it_' ...
         num2str(i)  'id_tempv'];
         saveVectorToAlluxio(file_location, msg);
 
end %% end for all working processes
fclose(fbug);fclose(fdebug);
disp('Success');
this = tic;
MPI_Finalize;
that = toc(this);
disp(['Finalization costs: ' num2str(that) 's']);


