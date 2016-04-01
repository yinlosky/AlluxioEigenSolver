%%%%%%%%%%%%%%%Filename: Alluxio_Row_mv_version2.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% Function: This file will read rows of matrix from Alluxio and multiply the vector {NumOfNodes}lz_q{cur_it}
%% Result will be saved at [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id' {_r _v} ];

%%
%% {NumOfNodes}lz_vpath = matrix * {NumOfNodes}lz_q{cur_it}
%% %% Version 2 will read vector from Alluxio as well to see how much faster we can get 
%% Date: Mar-25-2016
totaltic = tic;
myDB; %% connect to DB and return a binding named DB.
disp(['****************** Now Running Alluxio_Row_mv_version2.m ***********************']);

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it= DB('cur_it');
proc_t = DB('NumOfProcessors');

NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
NumOfProcessors = str2num(Val(proc_t('1,','1,')));
%vector = [num2str(NumOfNodes) 'lz_q' num2str(str2num(Val(cur_it('1,','1,'))))];
it = str2num(Val(cur_it('1,','1,')));
m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors
%output = DB([num2str(NumOfNodes) 'lz_vpath']);
%v = DB(vector);
num = DB(['Entries' num2str(NumOfNodes)]);  %% This table stores the elements for each column

w = zeros(Np,1,map([Np 1],{},0:Np-1));

myProc = global_ind(w); %Parallel

%% path to where the Alluxio files are stored
filePathPre = '/mytest';

 %%% TO log the performance%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%           if(~exist([root '/timing'],'dir'))
 %               mkdir([root '/timing']);
  %         else
   %             rmdir([root '/timing'],'s')
    %            mkdir([root '/timing']);
     %       end

        %fname = ([root '/timing' '/stat.txt']);
        %fstat = fopen(fname,'a+');

 %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
for i = myProc
        if(i>1)

                disp(['My i is: ' num2str(i)]);
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
        fname = ([root '/timing/v2_' num2str(i)  '_stat_Alluxio.txt']);
        fstat = fopen(fname,'w+');
	fbug = fopen(['benchmark/' num2str(i) '_proc_MatrixVector.txt'],'w+');

                            %% Read the vector Version 1 reading from Accumulo table (XXXX) too slow.
			%{
		   disp(['Now reading vector']);
  		   fwrite(fstat, ['Now reading vector']);
                        this = tic;
                        [vecr,vecc,vecv] = v(:,'1,');
                        vecr = str2num(vecr);
                        vecc = str2num(vecc);
                        vecv = str2num(vecv);
                        myVector = sparse(vecr,vecc,vecv,NumOfNodes,1);
                        readv = toc(this);
			disp(['Read vector: ' num2str(readv) 's' sprintf('\t')]);
                         fwrite(fstat, ['Read vector: ' num2str(readv) 's' sprintf('\t') ]);
                        %%%%%
			%}
	
	%% version 2: reading vector from Alluxio, each process should know which machine it belongs to.
	%%
	%% TO determine which machine each process belongs to,
	%%   if rem(procID-1, TotalMachine-1) == 0, then procID belongs to the last machine machines(NumOfMachines);
	%% else procID belongs to the machines(rem+1);
               [idum, my_machine] = system('hostname'); 
               my_machine = strtrim(my_machine);
		 str = ['My process id is: ' num2str(i) 'and My machine is: ' my_machine sprintf('\n')];
                disp(str); fwrite(fstat, str);		
		
%%%%%%%%%%%%%%%% After setting the machine number, we know where to read the vector from.
		str = (['Now reading vector from Alluxio' sprintf('\n')]);
		disp(str); fwrite(fstat, str);
		
		inputFilePathPre = '/mytest';
		inputFilePath=[inputFilePathPre '/' num2str(it) 'v_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' my_machine];
		
		inputobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_r' '|CACHE|CACHE_THROUGH']);
       		inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' inputFilePath '_v' '|CACHE|CACHE_THROUGH']);
		this = tic;
		my_row = javaMethod('readFile',inputobject_r);
		my_val = javaMethod('readFile',inputobject_v);
		readv=toc(this);
		str = ['Read vector takes: ' num2str(readv) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);
		
		str = ['Now constructing the vector'];
		this = tic;
		disp(str); fwrite(fstat, str);
		my_row = char(my_row); my_val = char(my_val);
		my_row = sscanf(my_row, '%d'); my_val = sscanf(my_val,'%f'); 	
		myVector = sparse(my_row, 1, my_val, NumOfNodes, 1);
		transV = toc(this);	
		str = ['Construction of vector done! It takes ' num2str(transV) 's' sprintf('\n')];
		disp(str); fwrite(fstat, str);	
			% for columns = start_col:end_col
                       % if(exist([root '/mydata' num2str(NumOfNodes) '/' num2str(i) '.txt']))  %% We have one row to multiply
            
                       %% According to the way we write the files the file name is: filePathPre/mydata{NumOfNodes}_{ProcessId}_{r,c,v}
                filePath = ([filePathPre '/mydata' num2str(NumOfNodes) '_' num2str(i) ]);
                
                 	%% Create the following three objects for writing strings
        myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_r' '|CACHE|CACHE_THROUGH']);
        myobject_c = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_c' '|CACHE|CACHE_THROUGH']);
        myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' filePath '_v' '|CACHE|CACHE_THROUGH']);
                  this = tic; 
        myRow = javaMethod('readFile',myobject_r);

        myCol = javaMethod('readFile',myobject_c);

        myVal = javaMethod('readFile',myobject_v);
        readlocal = toc(this);
	disp(['Read processor id: ' num2str(i) ' from file costs: ' num2str(readlocal) 's' sprintf('\t')]);
        fwrite(fstat, ['Read processor id: ' num2str(i) ' from file costs: ' num2str(readlocal) 's' sprintf('\t') ]);
        %% COnvert the Assoc into Matrix format....             
        %% convert java string to matlab char
        myRow = char(myRow); myCol = char(myCol); myVal = char(myVal); 
        %% convert char into numeric type
        myRow = sscanf(myRow,'%d'); myCol = sscanf(myCol,'%d'); myVal=sscanf(myVal,'%f');
        this = tic;
        %onerowofmatrix = sparse(inputData(:,1),inputData(:,2),inputData(:,3),1,NumOfNodes);
                        onepartofmatrix = sparse(myRow-start_col+1,myCol,myVal,end_col-start_col+1,NumOfNodes);
                        const = toc(this);
                         fwrite(fstat, ['Construct sparse: ' num2str(const) 's' sprintf('\n') ]);

                        this = tic;
                        myresult = onepartofmatrix * myVector;
                        multt = toc(this);
                         fwrite(fstat, ['Multiplication: ' num2str(multt) 's' sprintf('\t') ]);
		
		%% below commented: writing result back to the Accumulo 
		%{
                        %%full(myresult) is the value
                        this = tic;
                         put(output, Assoc(sprintf('%d,',start_col:end_col),'1,',sprintf('%.15f,',full(myresult)))); %% columns is actually the row id
                        putt = toc(this);
                           fwrite(fstat, ['Write back: ' num2str(putt) 's' sprintf('\n') ]);
		%}

		%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
		%% below writing result back to Alluxio 
		%% [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num3str(NumOfProcessors) 'proc_' myprocessid '_id' {_r _v} ];
		outputFilePathPre = '/mytest';
		outputPath = [outputFilePathPre '/vpath' num2str(it) '_' num2str(NumOfNodes) 'nodes_' num2str(NumOfProcessors) 'proc_' num2str(i) '_id'];
		%%%%
		%% create the object to write to Alluxio
		myobject_r = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_r' '|CACHE|CACHE_THROUGH']);
        	myobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' outputPath '_v' '|CACHE|CACHE_THROUGH']);
		str = (['Start writing result back to local lz_vpath alluxio ...  ']);	
		this = tic;
		str_r = sprintf('%,',start_col:end_col);
		str_v = sprintf('%.15f,',full(myresult));
	        javaMethod('writeFile',myobject_r,str_r);
        	javaMethod('writeFile',myobject_v,str_v);
		writeTime = toc(this);
		str = ([num2str(writeTime) 's' sprintf('\n')]);
		disp(str); fwrite(fstat,str);
		
                 %  end
         %       end
                    fwrite(fstat, ['Done' ]);
                    fclose(fstat);
        else
        disp(['I am just waiting!']);
	fbug = fopen(['benchmark/' num2str(i) '_proc_MatrixVector.txt'],'w+');
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


%disp('Sending to agg');
%fwrite(fstat,['Sending to agg']);
%agg(w);
%disp('Agg is done! I am closed now');
%fwrite(fstat, ['Agg is done! I am closed now.']);
%fclose(fstat);
