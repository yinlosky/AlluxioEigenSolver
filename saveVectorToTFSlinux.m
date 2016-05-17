%% function saveVectorToTFSlinux
%% note: this function should be run in the following: eval(pRUN('saveVectorToTFSlinux',NumOfMachines, machines));
%% this file is used to copy the global file 
%% [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v' ];
%%
%% to each individual worker node
%% outputFilePath = [outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine];

%% linux command would be: scp n117:/data/
%% to get the computer name, which is mymachine: [~,name] = system('hostname')
%% getenv('ACCUMULO_HOME') returns the system path of accumulo_home

%% alluxio load command: alluxio fs load /mytest/num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine
timer = tic;

myDB;
nodes_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(nodes_t('1,','1,')));

np_t = DB('NumOfProcessors');
NumOfProcessors = str2num(Val(np_t('1,','1,')));

cur_it = DB('cur_it');
it = str2num(Val(cur_it('1,','1,')));


w = zeros(Np, 1, map([Np 1],{},0:Np-1));
myMachine = global_ind(w);

for i = myMachine
    if i > 1
    ALLUXIO_HOME = getenv('ALLUXIO_HOME');
    [~,mymachine] = system('hostname');
    
    input_filename = [num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_global_v'];
    output_filename = [num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' mymachine '_v'] ;
    disp(output_filename);
    disp(['scp n117:' ALLUXIO_HOME '/underFSStorage/mytest/' input_filename ' ' ALLUXIO_HOME '/underFSStorage/mytest/' output_filename])
    system(['scp n117:' ALLUXIO_HOME '/underFSStorage/mytest/' input_filename ' ' ALLUXIO_HOME '/underFSStorage/mytest/' output_filename]);
    
    system(['alluxio fs load /mytest/' output_filename]);
        
    else
        disp('Leader process idle');
    end
end
agg(w);
totaltime = toc(timer);
disp(['Total time to copy to local directory takes ' num2str(totaltime) 's' sprintf('\n')]);
