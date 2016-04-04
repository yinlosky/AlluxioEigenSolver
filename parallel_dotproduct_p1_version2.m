%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File Name: parallel_dotproduct_p1_version2.m
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%  Difference between version 1 and version 2 is that in version 2 we store vectors in Alluxio file system to speed up the accessing time.
%%	
%%	Note: both vi and vpath should be divided according to the cut_table 
%%
%%	input lz_vpath: /mytest/NumofNodes_lz_vpath_machineid_{r,v}   
%%	input lz_v{i}: /mytest/{iteration}v_{Numofnodes}nodes_{NumOfProcessors}proc_mymachine_{r,v}
%%
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
%%
%% Author: Yin Huang
%% Date: Mar,28,2016
%% Usage: dotprodcut('test_dot1','test_dot2',3,2)

totaltic = tic;
myDB; %% connect to DB and return a binding named DB.


root = matlabroot;

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
np_t = DB('NumOfProcessors');
cur_it = DB('cur_it');


NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(np_t('1,','1,')));
iteration_id = str2num(Val(cur_it('1,','1,')));

cut_t = DB(['Cut' num2str(NumOfNodes)]);
%vector = [num2str(NumOfNodes) 'lz_q' num2str(str2num(Val(cur_it('1,','1,'))))];

%v = DB([num2str(NumOfNodes) 'lz_vpath']); 
%vi = DB(vector);
% cut_t = DB(['Cut' num2str(NumOfNodes)]);
%output table dot_temp
temp = DB('dot_temp');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%   Parallel part %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



colGap = floor(NumOfNodes / (Np-1));

w = zeros(Np,1,map([Np 1],{},0:Np-1));

myProc = global_ind(w); %Parallel

for i = myProc
	
	%{	
	 if(i>1)
        start_node = (i-1-1)*colGap+1;
        if (i<Np)
        end_node = (i-1)*colGap ;
        else
        end_node = NumOfNodes ;
        end
%}
	fbug = fopen(['benchmark/' num2str(i) '_proc_in_dotMul.txt'],'a+');
	% To get the start_col and end_col for the process that is running individually 
	%% because it is not equally cut so we need deduct previous_end_node cut point from current start point
	%%for numerial calculation 
        if(i>1)
        disp(['My i is: ' num2str(i)]);
%        fwrite(flog, ['My i is: ' num2str(i) sprintf('\n')]);
        if(i==2)  %% because it starts with 1 no need to deduct p_end_node
        start_node = 1;
        end_node = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
	p_end_node = 0;
        else
                if(i<Np)
                        start_node = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
                        end_node = str2num(Val(cut_t(sprintf('%d,',i-1),:)));
			p_end_node = str2num(Val(cut_t(sprintf('%d,',i-2),:)));
                end
        end
        if(i==Np)
        start_node = str2num(Val(cut_t(sprintf('%d,',i-2),:)))+1;
        end_node = NumOfNodes;
	p_end_node = str2num(Val(cut_t(sprintf('%d,',i-2),:)));
        end

	disp(['start index: ' num2str(start_node) ' end index: ' num2str(end_node)]);


	temp_sum = 0;
	vectorLength = end_node - start_node + 1; %% size of the vector
%%%%%%%%%%%%%%%%%% We transfer the assoc results into sparse matrix%%%%%%%%%%%%%%
%%%%% below is the first version which reads vector from accumulo table
 %{
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

	%}

%%%%%%%%%%%%%%%   version 2 in which vectors are read from Alluxio file system
%%
%%   Begin Version 2
%%
 	%% first set up the debug info location 
	fname = ([root '/timing/vectorv2_' num2str(i)  '_stat_Alluxio.txt']);
    fstat = fopen(fname,'w+');
	str = ['Now reading vector and vi from Alluxio ...'];
	disp(str); fwrite(fstat, str);
	
	%% identify the machine id  
	[idum, my_machine] = system('hostname');
        my_machine = strtrim(my_machine);
        str = ['My process id is: ' num2str(i) 'and My machine is: ' my_machine sprintf('\n')];
        disp(str); fwrite(fstat, str);

	%%% now read the lz_vpath vector
	%lz_vpath: inputFilePath = [inputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' num2str(i) '_id'];
	%%%%%%%%%%%%%%%% After setting the machine number, we know where to read the vector from.
                str = (['Now reading lz_vpath vector from Alluxio' sprintf('\n')]);
                disp(str); fwrite(fstat, str);

                inputFilePathPre = '/mytest';
		inputFilePath = [inputFilePathPre '/vpath' num2str(iteration_id) '_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
	
                inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
                inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
                this = tic;
                my_row = javaMethod('readFile',inputobject_r);
                my_val = javaMethod('readFile',inputobject_v);
                readv=toc(this);
                str = ['Read lz_vpath vector takes: ' num2str(readv) 's' sprintf('\n')];
                disp(str); fwrite(fstat, str);

                str = ['Now constructing the vector'];
                this = tic;
                disp(str); fwrite(fstat, str);
                my_row = char(my_row); my_val = char(my_val);
		
                %my_lz_vpath_asso = Assoc(my_row, '1,', my_val);
		%[vr,vc,vv] = my_lz_vpath_asso(sprintf('%d,',start_node:end_node),:);
		vr = sscanf(my_row, '%d') - (i-2)*colGap; vv= sscanf(my_val,'%f');
		sparse_v = sparse(1, vr, vv, 1, vectorLength);
		transV = toc(this);
                str = ['Construction of lz_vpath vector done! It takes ' num2str(transV) 's' sprintf('\n')];
                disp(str); fwrite(fstat, str);
	%%%% read lz_vpath done

	 %%% now read the lz_v{i}: 
% Old: /mytest/{iteration}v_{Numofnodes}nodes_{NumOfProcessors}proc_mymachine_{r,v} vector
% New or latest:[outputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id'];   

 %%%%%%%%%%%%%%%% After setting the machine number, we know where to read the vector from.
                str = (['Now reading lz_vi vector from Alluxio' sprintf('\n')]);
                disp(str); fwrite(fstat, str);

                inputFilePathPre = '/mytest';
                inputFilePath=[inputFilePathPre '/' num2str(iteration_id) 'v_'  num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];

                inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
                inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
                this = tic;
                my_row = javaMethod('readFile',inputobject_r);
                my_val = javaMethod('readFile',inputobject_v);
                readv=toc(this);
                str = ['Read lz_vi vector takes: ' num2str(readv) 's' sprintf('\n')];
                disp(str); fwrite(fstat, str);

                str = ['Now constructing the vector'];
                this = tic;
                disp(str); fwrite(fstat, str);
                my_row = char(my_row); my_val = char(my_val);
                %my_lz_vi_asso = Assoc(my_row, '1,', my_val);
                %[vir,vic,viv] = my_lz_vi_asso(sprintf('%d,',start_node:end_node),:);
                vir = sscanf(my_row, '%d') - p_end_node; viv= sscanf(my_val,'%f');
                sparse_vi = sparse(vir, 1, viv, vectorLength, 1);
                transV = toc(this);
                str = ['Construction of lz_vi vector done! It takes ' num2str(transV) 's' sprintf('\n')];
                disp(str); fwrite(fstat, str);
        %%%% read lz_vi done

		str =(['*******Now calculating the result of vpath*vi*********' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		this = tic;
		myresult = sparse_v * sparse_vi;
		resultT = toc(this);
		str=(['Calculation: ' num2str(resultT) 's' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		
		
		str = (['Now writing result back to Accumulo ...' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		this = tic;
		newAssoc = Assoc(sprintf('%d,',(i-1)),'1,',sprintf('%.15f,',full(myresult)));
 		put(temp,newAssoc);
		wb_t = toc(this);
		str= (['Writing back: ' num2str(wb_t) 's' sprintf('\n')]);
		disp(str);fwrite(fstat,str);
		fclose(fstat);
	
else % lazy
        disp(['I am just waiting']);
	end
end
beforeTime = toc(totaltic);
str = (['Before agg total time is: ' num2str(beforeTime) 's']); 
disp(str); fwrite(fbug, str);
agg(w);
afterTime = toc(totaltic);
str = (['After agg total time is: ' num2str(afterTime) 's']);
disp(str); fwrite(fbug, str);
fclose(fbug);
