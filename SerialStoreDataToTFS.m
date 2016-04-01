function SerialStoreDataToTFS(Np)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   FileName: SerialStoreDataToTFS.m
%%   Function: This function serves to store data to TFS. Since TFS is a global directory, we plan to use a different file name to differentiate the data for different nodes. For example, node 2 will store the data to a file called mydata{NumOfNodes}_{2}.tx
%%   Note: My parallel version is malfunctioning, because according to the log info, my n118 client fails to connect to the master. As a result I am writing this file to store the data from Accumulo table in a serial fashion. 
%%
%%   Parameters: 1. NumOfMachines
%%               2. FilePath to store in TFS (For test purpose, I hard coded the path)
%%  

%%%% Connect to database first %%%%%%
myDB;

%%%% Import my code for accessing Tachyon file system
import yhuang9.testAlluxio.*;

%%%% To get the number of nodes
nodes_t = DB('Scale');
NumOfNodes = 2^str2num(Val(nodes_t('1,','1,')));

%% To get the name of Cut{NumOfNodes} table which shows the schedule of col range
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors

%%% To get the number of machines in the cluster this serves to help run different sets of experiments
machines_t = DB('NumOfMachines');

numOfMachines = str2num(Val(machines_t('1,','1,')));

%% Filepath to store in TFS
filePathPre = '/mytest';

%% Below is for debugging purpose
DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
DebugPath = ([DebugPathPre '/' num2str(NumOfNodes) '_' num2str(numOfMachines) '_' num2str(Np)]);
if(~exist([DebugPath] , 'dir'))
        mkdir([DebugPath] );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Below is the parallel part for storing the data from table to TFS

%% Set the table to read from
mIt = DB(['M' num2str(NumOfNodes)]);

%%%%%%%%% Comment below part to run as in a serial fashion
%% Parallel part
%     w = zeros(Np,1,map([Np 1],{},0:Np-1));
%     myProc = global_ind(w); 
%Parallel

for i = 1 : Np    % i starts from 1
	% set up the debug file for each process
	flog = fopen([DebugPath '/' num2str(i) '_process_debug.txt'],'w+');	
      
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
        disp(['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col)]);
        fwrite(flog, ['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col)]);      
	
        %% To set up the location where to store the data from the table
	filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
        
 	%% Now we begin to store the data reading from start_col to end_col to filePath
	%myobject=AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '|CACHE|CACHE_THROUGH']);
	
	%% Create the following three objects for writing strings
        myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_r' '|CACHE|CACHE_THROUGH']);
        myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
        myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_v' '|CACHE|CACHE_THROUGH']);	

	%% Read from the table and calculate the total time 
	this = tic; 
	%myAssoc = mIt(sprintf('%d,',start_col:end_col),:);  % Saving Assoc directly(Not working for big data)
	[myAssoc_r myAssoc_c myAssoc_v] = mIt(sprintf('%d,',start_col:end_col),:);
	readTime = toc(this);
	disp(['Reading above columns costs: ' num2str(readTime) 's' sprintf('\n') ]);
	fwrite(flog, ['Reading above columns costs: ' num2str(readTime) 's' sprintf('\n')]);
	
   	%% convert the associative array into csv string
	%myStr = Assoc2CSVstr(myAssoc, char(10),',');
	%clear myAssoc;
	%% save the csv string into TFS and save the time
	this = tic;
        %javaMethod('writeFile',myobject,myStr);

	% save the row, col, val string into TFS files and save the time
	javaMethod('writeFile',myobject_r,myAssoc_r);
	clear myAssoc_r;
        javaMethod('writeFile',myobject_c,myAssoc_c);
	clear myAssoc_c;
        javaMethod('writeFile',myobject_v,myAssoc_v);
	clear myAssoc_v;
	saveTime = toc(this);
	disp(['Saving above columns costs: ' num2str(saveTime) 's' sprintf('\n') ]);
	fwrite(flog, ['Saving above columns costs: ' num2str(saveTime) 's' sprintf('\n')]);

	%% clear unused variable to save space
        %clear myAssoc_r;
    	%clear myAssoc_c;
	%clear myAssoc_v;
        %% We write a {i}_done.txt file to indicate the completion of the execution of the code
	disp([ 'Process: ' num2str(i) ' Done!']);
	fclose(fopen([DebugPath '/' num2str(i) '_done.txt'],'w+'));
	fclose(flog);

	else
	%% Process 1 simply waits without doing anything. 
	disp(['I am just waiting as process 1!']);
        end
end   %% end for loop


% Below is an aggregation part for parallel code.
% agg(w);

