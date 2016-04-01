%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File Name: parallel_dotproduct_p1.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This is the function for alph_i = v_i'.*v (two vectors dotproduct) // both vectors are dense.
%% Input: 
%%  	para1: 'lz_vpath'
%%	para2: vector 2
%%   	para3: Num of nodes in the graph
%% 	para4: Num of machines for parallelization
%% Output: 
%%      Return the value of dot_prodcut R
%%      dot_output table will be created and saved 
%% ------------This function requires some optimization for matrix partition and load balancing------
%% For now I am simply evenly splitting the columns among different processros
%%
%%
%%
%% This is an embarassing parallel job, need attention for parallelization
%%
%% Author: Yin Huang
%% Date: Nov,30,2014
%% Usage: dotprodcut('test_dot1','test_dot2',3,2)

tic;

myDB; %% connect to DB and return a binding named DB.
%machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it = DB('cur_it');

%NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
vector = [num2str(NumOfNodes) 'lz_q' num2str(str2num(Val(cur_it('1,','1,'))))];
v = DB([num2str(NumOfNodes) 'lz_vpath']); 
vi = DB(vector);
% cut_t = DB(['Cut' num2str(NumOfNodes)]);
%output table dot_temp
temp = DB('dot_temp');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   Parallel part %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


machines_t = DB('NumOfMachines');
NumOfMachines = str2num(Val(machines_t('1,','1,')));

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


	temp_sum = 0;
	vectorLength = end_node - start_node + 1; %% size of the vector
%%%%%%%%%%%%%%%%%% We transfer the assoc results into sparse matrix%%%%%%%%%%%%%%

    [vr,vc,vv] = v(sprintf('%d,',start_node:end_node),:);
    [vir,vic,viv] = vi(sprintf('%d,',start_node:end_node),:);	
   % vr = str2num(vr) - (i-2)*colGap  ;  vc = str2num(vc) ; vv = str2num(vv) ;
   % vir = str2num(vir) - (i-2)*colGap  ; vic=str2num(vic)  ; viv = str2num(viv) ;
    vr = sscanf(vr, '%d') - (i-2)*colGap; vc = sscanf(vc,'%d'); vv= sscanf(vv,'%f');
   vir = sscanf(vir, '%d') - (i-2)*colGap; vic = sscanf(vic,'%d'); viv= sscanf(viv,'%f');

	   
    sparse_v = sparse(vc, vr, vv, 1, vectorLength);
    sparse_vi = sparse(vir, vic, viv, vectorLength, 1);
    myresult = sparse_v * sparse_vi;

  newAssoc = Assoc(sprintf('%d,',(i-1)),'1,',sprintf('%.15f,',full(myresult)));
  put(temp,newAssoc);
else % lazy
        disp(['I am just waiting']);
	end
end
agg(w);

