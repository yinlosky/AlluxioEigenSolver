%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File Name: parallel_update_q.m
%% Function: lz_q{it+1} =  lz_vpath * (1/beta_it)
%% Input:
%%	it should be read from 'cur_it ('1,','1,') '
%% 	lz_vpath should be read from 'lz_vpath'
%% 	beta should be read from 'beta('it,','1,')'
%%
%% Author: Yin Huang
%% Date: Dec 11,2014
myDB;
machines_t = DB('NumOfMachines'); % we parallel on processors level
np_t = DB('NumOfProcessors');

nodes_t = DB('NumOfNodes');
cur_it = DB('cur_it');
it = str2num(Val(cur_it('1,','1,')));

NumOfNodes = str2num(Val(nodes_t('1,','1,')));

	% cut_t = DB(['Cut' num2str(NumOfNodes)]);


update_lz_vpath = DB([num2str(NumOfNodes) 'lz_vpath']);
update_q_beta_t = DB('beta');


NumOfMachines = str2num(Val(machines_t('1,','1,')));
Np = str2num(Val(np_t('1,','1,')));

update_q_output = DB([num2str(NumOfNodes) 'lz_q' num2str(it+1)]);
if(~isempty(update_q_beta_t(sprintf('%d,',it),'1,')))
beta_it_v = str2num(Val(update_q_beta_t(sprintf('%d,',it),'1,')));
beta_it_v = 1./beta_it_v;
else
beta_it_v = 0;
end
	colGap = floor(NumOfNodes / (Np-1));
	
w = zeros(Np,1,map([Np 1],{},0:Np-1));

	myMachine = global_ind(w); %Parallel
	for i = myMachine
	
		if(i>1)
        start_node = (i-1-1)*colGap+1;
        if (i<Np)
        end_node = (i-1)*colGap ;
        else
        end_node = NumOfNodes ;
        end


		disp(['start index: ' num2str(start_node) ' end index: ' num2str(end_node)]);
	disp(['Iteration ' num2str(it) ' beta ' num2str(beta_it_v) ' times' num2str(NumOfNodes) 'lz_vpath' ]);
	%% Below for loop will make sure the 0 values will be written to the table,
	% We need fill with 0s to make sure our query will return the same sequence of value to calculate v = v- sax_alpha_temp - sax_beta_temp
	%% HOWEVER, since we use the full function to fill 0s , we don't need to concern about 0s. 
		
	%% Read vector
	[vr,vc,vv] =  update_lz_vpath(sprintf('%d,',start_node:end_node),:);
	vv = sscanf(vv,'%f');
	vv = vv .* beta_it_v;
	put(update_q_output, Assoc(vr,'1,', sprintf('%.15f,',vv)));
	
	disp(['Insertation done!']);	
		else 
         disp(['I am just waiting']);
	end
end

disp(['Waiting to be agged!']);
agg(w);


