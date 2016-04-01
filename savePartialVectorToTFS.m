function savePartialVectorToTFS()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   FileName: savePartialVectorToTFS.m
%%   Usage: this function is used to save partial of vi to each local machine for vi * v operation according to Cut table. 
%%   Parameters: 1. NumOfMachines
%%               2. FilePath to store in TFS (For test purpose, I hard coded the path)
%%
%%  Output: Assoc arrays will be written into the following in-memory files with row, col, val files in in-memory files. The reason is Assoc2CSVstr has bugs for large strings. 

%%	Input: = ['/mytest' '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine]; 
%%	Output: [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id']; 
%%  

%%%% Connect to database first %%%%%%
myDB;

%%%% Import my code for accessing Tachyon file system
import yhuang9.testAlluxio.*;

%%%% To get the number of nodes
nodes_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(nodes_t('1,','1,')));

%% To get the name of Cut{NumOfNodes} table which shows the schedule of col range
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors

%%% To get the number of machines in the cluster this serves to help run different sets of experiments
machines_t = DB('NumOfMachines');

numOfMachines = str2num(Val(machines_t('1,','1,')));

%% get current iteration
cur_it= DB('cur_it');
it = str2num(Val(cur_it('1,','1,')));

%% Below is for debugging purpose
DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
DebugPath = ([DebugPathPre '/partVi_' num2str(NumOfNodes) '_' num2str(numOfMachines) '_' num2str(Np)]);
if(~exist([DebugPath] , 'dir'))
        mkdir([DebugPath] );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Below is the parallel part for storing the data from local global TFS to local part vi TFS

%% ['/mytest' '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine];

inputFilePre = '/mytest/';
[idum, my_machine] = system('hostname');
my_machine = strtrim(my_machine);
inputFilePath = ([inputFilePre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(Np) 'proc_' my_machine]);

inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);

%% Parallel part
w = zeros(Np,1,map([Np 1],{},0:Np-1));
myProc = global_ind(w); %Parallel

for i = myProc    % i starts from 1
	% set up the debug file for each process
	flog = fopen([DebugPath '/partVi_' num2str(i) '_process_debug.txt'],'w+');	
      
        % To get the start_col and end_col for the process that is running individually 
	if(i>1)
        disp(['My i is: ' num2str(i)]);
        fwrite(flog, ['My i is: ' num2str(i) sprintf('\n')]);
        if(i==2)
        start_col = 1;
        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
        else
                if(i<Np)
                        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
                        end_col = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
                end
        end
        if(i==Np)
        start_col = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
        end_col = NumOfNodes;
        end
        disp(['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col) sprintf('\n')] );
        fwrite(flog, ['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col) sprintf('\n')]);      

	%Output: [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num4str(NumOfProcessors) 'proc_' myprocessid '_id'];
	outputFilePathPre = '/mytest'
	outputfilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(Np) 'proc_' num2str(i) '_id'];
		
	%% Create the following two objects for writing strings
	myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputfilePath '_r' '|CACHE|CACHE_THROUGH']);
	%myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
	myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputfilePath '_v' '|CACHE|CACHE_THROUGH']);
	
	str = (['Start reading from global vi local machine ... ']);
	disp(str); fwrite(flog, str);
	%% Read from the table and calculate the total time 
	this = tic; 
	%[myAssoc_r myAssoc_c myAssoc_v] = mIt(sprintf('%d,',start_col:end_col),:);
	 my_row = javaMethod('readFile',inputobject_r);
         my_val = javaMethod('readFile',inputobject_v);
        readTime = toc(this);
	str = ([num2str(readTime) 's' sprintf('\n')]);
	disp(str); fwrite(flog, str);

	%% now convert the string into Associative array 
	my_row = char(my_row); my_val = char(my_val);
	mIt = Assoc(my_row, '1,', my_val);
	[myAssoc_r myAssoc_c myAssoc_v] = mIt(sprintf('%d,',start_col:end_col),:);	
	%% save the row, val string into TFS files and save the time
	str = (['Now writing partial vi to local machine ... ']);
	disp(str); fwrite(flog, str);
	this = tic;
        javaMethod('writeFile',myobject_r,myAssoc_r);
	%javaMethod('writeFile',myobject_c,myAssoc_c);
	javaMethod('writeFile',myobject_v,myAssoc_v);
	saveTime = toc(this);
	str = ([num2str(saveTime) 's' sprintf('\n')]);
        disp(str); fwrite(flog, str);
	%% clear unused variable to save space
        clear myAssoc_r;
        clear myAssoc_c;
	clear myAssoc_v;

        %% We write a {i}_done.txt file to indicate the completion of the execution of the code
	fclose(fopen([DebugPath '/' num2str(i) '_done.txt'],'w+'));
	fclose(flog);

	else
	%% Process 1 simply waits without doing anything. 
	disp(['I am just waiting as process 1!']);
        end
end   %% end for loop


agg(w);

