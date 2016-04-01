%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File Name:parallel_lz_norm_v_p1.m
%% Function: This is p1 to calculate the norm of the 'lz_vpath'
%%
%% Author: Yin Huang
%% Date: Dec, 11, 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tic;
%% Initialize the tables 
myDB;
machines_t = DB('NumOfMachines'); % we parallel on processors level
nodes_t = DB('NumOfNodes');
np_t =DB('NumOfProcessors');
 % cut_t = DB(['Cut' num2str(NumOfNodes)]);
NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
Np = str2num(Val(np_t('1,','1,')));
%cut_t = DB(['Cut' num2str(NumOfNodes)]);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% variables defintion %%%%%%%%%%%%%%%%%%%%%%%%%

Input_table = ([num2str(NumOfNodes) 'lz_vpath']);   % local variable hard coded.
norm_v_temp = (['lz_norm_v' num2str(NumOfNodes) '_temp']); % local variable for temp table, temp table will be read for p2

colGap = floor(NumOfNodes / (Np-1));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

InputT = DB(Input_table); % create a database binding to the input table.
norm_v_temp = DB(norm_v_temp); % create a database binding to the temp table
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%% Parallel read the input_table, and set the range for each reader, each reader will write the sum of sqr in a local directory called lz_norm/iv.txt(i is the id of each reader)

w = zeros(Np,1,map([Np 1],{},0:Np-1));



myMachine = global_ind(w); %Parallel

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% First split the reading from the input table, and calculate the norm(result)^2 and written to local results 
%% Later, all local results are summed up and sqr root for the final norm.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = myMachine
	disp(['My i is:' num2str(i)]);
        if(i>1)
        start_node = (i-1-1)*colGap+1;
        if (i<Np)
        end_node = (i-1)*colGap ;
        else
        end_node = NumOfNodes ;
        end

	length = end_node - start_node+1;
	disp(['start index: ' num2str(start_node) ' end index: ' num2str(end_node) 'length: ' num2str(length)]);
	
	[vr,vc,vv]= InputT(sprintf('%d,',start_node:end_node),:); 
	if(~isempty(vv))
		value = norm(sscanf(vv,'%f'))^2;
	else
		value = 0;
	end
	put(norm_v_temp,Assoc(sprintf('%d,',i-1),'1,',sprintf('%.15f,',value)));
	else 
         disp(['I am just waiting']);
end
end
agg(w); %% wait for processors to finish all the work! This could possibly optimze for performance!!!

