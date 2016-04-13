function saveVectorToGTFS()
%% usage: this function serves to save the updated vector {NumOfNodes}lz_q{iteration} to TFS global file in the following location:
%%% inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global' _r _v  
%%

%%
% Connect to db for global variable 
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

%%%%
vector = [num2str(NumOfNodes) 'lz_q' num2str(it)];
v = DB(vector);


%% setting up the debug location
DebugPathPre = '/home/yhuang9/DebugFolderForTFS/';
DebugPath = ([DebugPathPre '/global_' num2str(it)  'vector_' num2str(NumOfNodes) 'nodes_' num2str(Np) 'machines']);
if(~exist([DebugPath] , 'dir'))
        mkdir([DebugPath] );
end
fstat = fopen( [DebugPath '/savingGlobal.log' ],'w+');
%%%%%%%%%%%%%%%%%%%%%%%%

outputFilePathPre = '/mytest';
outputFilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global' ];

%outputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputFilePath '_r' '|CACHE|CACHE_THROUGH']);
outputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputFilePath '_v' '|CACHE|CACHE_THROUGH']);

%%% start reading from Accumulo for vector
str = ['Now start reading from Accumulo to get vector...' sprintf('\n')];
disp(str); fwrite(fstat,str);
this = tic;
[vecr, vecc, vecv] = v(:,:);
readv = toc(this);
str = ['Read vector: ' num2str(readv) 's' sprintf('\n')];
disp(str); fwrite(fstat,str);



%%%%% start saving the vector to TFS file
this = tic;
%javaMethod('writeFile',outputobject_r,vecr);
javaMethod('writeFile',outputobject_v,vecv);
saveTime = toc(this);
str= ['Saving vector to global vector file takes: ' num2str(saveTime) 's' sprintf('\n')];
disp(str); fwrite(fstat,str);

clear vecr; clear vecc; clear vecv; 
fclose(fstat);


