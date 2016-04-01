%%%%%%%%%%%%%%%Filename: Alluxio_Row_mv.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% Function: This file will read rows of matrix from Alluxio and multiply the vector {NumOfNodes}lz_q{cur_it}, the result will be saved to NumOfNodeslz_vpath
%% {NumOfNodes}lz_vpath = matrix * {NumOfNodes}lz_q{cur_it}
%%
%% Date: Mar-19-2016

myDB; %% connect to DB and return a binding named DB.
disp(['****************** Now Running Alluxio_Row_mv.m ***********************']);

%% Import my Java code for R/W in-memory files
import yhuang9.testAlluxio.* ;

%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it= DB('cur_it');


NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
vector = [num2str(NumOfNodes) 'lz_q' num2str(str2num(Val(cur_it('1,','1,'))))];

m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors
 output = DB([num2str(NumOfNodes) 'lz_vpath']);
v = DB(vector);
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
                     fname = ([root '/timing/' num2str(i)  '_stat_Alluxio.txt']);
                  fstat = fopen(fname,'w+');

                            %% Read the vector

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
                        %%%%%%

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
        myRow = sscanf(myRow,'%d'); myCol = sscanf(myCol,'%d'); myVal=sscanf(myVal,'%d');
        this = tic;
        %onerowofmatrix = sparse(inputData(:,1),inputData(:,2),inputData(:,3),1,NumOfNodes);
                        onepartofmatrix = sparse(myRow-start_col+1,myCol,myVal,end_col-start_col+1,NumOfNodes);
                        const = toc(this);
                         fwrite(fstat, ['Construct sparse: ' num2str(const) 's' sprintf('\n') ]);

                        this = tic;
                        myresult = onepartofmatrix * myVector;
                        multt = toc(this);
                         fwrite(fstat, ['Multiplication: ' num2str(multt) 's' sprintf('\t') ]);

                        %%full(myresult) is the value
                        this = tic;
                         put(output, Assoc(sprintf('%d,',start_col:end_col),'1,',sprintf('%.15f,',full(myresult)))); %% columns is actually the row id
                        putt = toc(this);
                           fwrite(fstat, ['Write back: ' num2str(putt) 's' sprintf('\n') ]);




                 %  end
         %       end
                    fwrite(fstat, ['Done' ]);
                    %fclose(fstat);
        else
        disp(['I am just waiting!']);
        end
end

disp('Sending to agg');
fwrite(fstat, 'Sending to agg');
agg(w);
disp('Agg is done! I am closed now');
fwrite(fstat, 'Agg is done! I am closed now.');
fclose(fstat);
