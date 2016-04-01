function saveVectorToTFS()
%%%%
%%  usage: This function serves to save the updated vector lz_q{iteration} to TFS named with {iteration}v_{NumOfNodes}nodes_{NumOfProcessors}proc_{machineName}_{r,v}
%% TO save space, my process should be good enough to identify its own machine so that each local machine has a vector copy in its own Alluxio underFSStorage

%% To speed up, I first make a global copy of vector from Accumulo and then each processor make its own local copy from global copy since reading from Accumulo is slow. Reading from global copy resided in Alluxio should be faster than Accumulo

%% 
%%
%%	Note: 1. eval(pRUN('saveVectorToTFS'), NumOfMachines, machines); 
%%	This function should be run at each machine only once. 
%%            2. This file has a hard coded configuration of the cluster machine's names.
%%
%% Date: March 25, 2016



%% connect to db for global variable. 
myDB;

%% import my code for accessing Tachyon File system
import yhuang9.testAlluxio.*;

%%%% To get the number of nodes
nodes_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(nodes_t('1,','1,')));

np_t = DB('NumOfProcessors');
NumOfProcessors = str2num(Val(np_t('1,','1,')));
%%
cur_it = DB('cur_it');
it = str2num(Val(cur_it('1,','1,')));


%% set up the debug folder 
%% i plan to save the debug into /home/yhuang9/DebugFolderForTFS/{iteration}vector
DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
DebugPath = ([DebugPathPre '/' num2str(it)  'vector_' num2str(NumOfNodes) 'nodes_' num2str(Np) 'machines']);
if(~exist([DebugPath] , 'dir'))
        mkdir([DebugPath] );
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% input file path is [num2str(NumOfNodes) 'lz_q' num2str(it)]
%%%%%%%input_path_t = DB([num2str(NumOfNodes) 'lz_q' num2str(it)]);
% /mytest/1v_1048576nodes_106proc_global_r ,v
inputFilePathPre = '/mytest';
inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global' ];

        inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
        %inputobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
        inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% output file name should be: [num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine '_']
outputFilePathPre = '/mytest';

%% TO get the machine names in the cluster
machines = getMachines(Np); %% Note the first machine is not working 

%% Parallel part
%% Np should be equal to the number of machines 
w = zeros(Np, 1, map([Np 1],{},0:Np-1));
myMachine = global_ind(w);

for i = myMachine
	if (i>1)
	%% Proc 1 is not working
	DebugFileName = ([ DebugPath '/'  'machine_' num2str(i) '_savingVectorGolbalToLocal.txt']);
	fstat = fopen(DebugFileName, 'w+');
	mymachine = char(machines(i));
	disp(['myMachine is ' num2str(i)  ' My machine id is ' mymachine sprintf('\n')]);
	fwrite(fstat, ['myMachine is ' num2str(i) ' My machine id is ' mymachine]);
	
	disp(['Now reading the global file vector!' sprintf('\n')]);
	fwrite(fstat, ['Now reading the global file vector!' sprintf('\n')]);
	%% Now reading the global file
	this = tic;
	myVector_r = javaMethod('readFile',inputobject_r);
	myVector_v = javaMethod('readFile',inputobject_v);
	that = toc(this);	
	
	disp(['Reading global vector file costs: ' num2str(that) 's' sprintf('\n')]);
	fwrite(fstat, ['Reading global vector file costs: ' num2str(that) 's' sprintf('\n')]);	
	
	str = ['Now starting writing to my local alluxio ....'];
	disp(str); fwrite(fstat, str);
	
	outputFilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine];
	outputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputFilePath '_r' '|CACHE|CACHE_THROUGH']);
	outputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputFilePath '_v' '|CACHE|CACHE_THROUGH']);
	
	%% start writing
	this = tic;
	javaMethod('writeFile',outputobject_r, myVector_r);
	javaMethod('writeFile',outputobject_v, myVector_v);
	writeTime = toc(this);

	str = ['Writing to local alluxio object takes: ' num2str(writeTime) 's' sprintf('\n')];
	disp(str); fwrite(fstat, str);
	
	str = ['Saving to local copy done!'];
	disp(str); fwrite(fstat, str);
	fclose(fstat);
	else
	disp(['I am just waiting as the leader process 1']);	
	end % end if

end	% end for

agg(w);
