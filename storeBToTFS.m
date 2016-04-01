function storeBToTFS()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%   FileName: storeBToTFS.m
%%   Function: This function serves to store random vector B to TFS. Since TFS is a global directory, we plan to use a different file name to differentiate the data for different nodes. For example, node 2 will store the data to a file called mydata{NumOfNodes}_{2}.txt
%%
%%   Parameters: 1. NumOfMachines
%%               2. FilePath to store in TFS (For test purpose, I hard coded the path)
%%
%%  Output: Assoc arrays will be written into the following in-memory files with row, col, val files in in-memory files. The reason is Assoc2CSVstr has bugs for large strings. 
%%  

%%%% Connect to database first %%%%%%
myDB;

%%%% Import my code for accessing Tachyon file system
import yhuang9.testAlluxio.*;

%%%% To get the number of nodes
nodes_t = DB('Scale');
NumOfNodes = 2^str2num(Val(nodes_t('1,','1,')));


%%% To get the number of machines in the cluster this serves to help run different sets of experiments
machines_t = DB('NumOfMachines');

NumOfMachines = str2num(Val(machines_t('1,','1,')));

%% Filepath to store in TFS
filePathPre = '/mytest';

%% Below is for debugging purpose
DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
DebugPath = ([DebugPathPre '/saveB_' num2str(NumOfNodes) '_' num2str(NumOfMachines) '_' num2str(Np)]);
if(~exist([DebugPath] , 'dir'))
        mkdir([DebugPath] );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Below is the parallel part for storing the data from table to TFS

%% Set the table to read from
mIt = DB(['B' num2str(NumOfNodes)]);

%% Parallel part
w=zeros(NumOfMachines,1,map([NumOfMachines 1],{},0:NumOfMachines-1));
myMachine = global_ind(w);

for i = myMachine    % i starts from 1
	% set up the debug file for each process
	flog = fopen([DebugPath '/saveB_' num2str(i) '_process_debug.txt'],'w+');
    
    %% To set up the location where to store the data from the table
	filePath = ([filePathPre '/myB' num2str(NumOfNodes) '_' num2str(i) ]);
        
 	%% Now we begin to store the data reading from start_col to end_col to filePath
	%myobject=AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '|CACHE|CACHE_THROUGH']);
	
    
	%% Create the following three objects for writing strings
	myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_r' '|CACHE|CACHE_THROUGH']);
	myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
	myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_v' '|CACHE|CACHE_THROUGH']);
	
	%% Read from the table and calculate the total time 
	this = tic; 
	%	myAssoc = mIt(sprintf('%d,',start_col:end_col),:);   %% Saving the Assoc directly (Not working for big data)
	[myAssoc_r,myAssoc_c,myAssoc_v] = mIt(:,:);
    readTime = toc(this);
	fwrite(flog, ['Reading above columns costs: ' num2str(readTime) 's' sprintf('\n')]);
	
	%% save the row, col, val string into TFS files and save the time
	this = tic;
    javaMethod('writeFile',myobject_r,myAssoc_r);
	javaMethod('writeFile',myobject_c,myAssoc_c);
	javaMethod('writeFile',myobject_v,myAssoc_v);
	saveTime = toc(this);
	fwrite(flog, ['Saving above three string costs: ' num2str(saveTime) 's' sprintf('\n')]);

     %% clear unused variable to save space
    clear myAssoc_r;
    clear myAssoc_c;
	clear myAssoc_v;

        %% We write a {i}_done.txt file to indicate the completion of the execution of the code
	fclose(fopen([DebugPath '/' num2str(i) '_done_saveB.txt'],'w+'));
	fclose(flog); 
      
end   %% end for loop


agg(w);


