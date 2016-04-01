%%%%%%%%%%%%%%%Filename: LHD_Row_mv.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% Function: This file will read rows of matrix from local disk and multiply the vector {NumOfNodes}lz_q{cur_it}, the result will be saved to NumOfNodeslz_vpath
%% {NumOfNodes}lz_vpath = matrix * {NumOfNodes}lz_q{cur_it}
%%

myDB; %% connect to DB and return a binding named DB.
disp(['****************** Now Running Row_mv.m ***********************']);
 
%% create a mydata folder in the installation directory of matlab

root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
cur_it= DB('cur_it');
%initM_edges = DB('edges');
proc_t=DB('NumOfProcessors');


NumOfProcessors = str2num(Val(proc_t('1,','1,')));
%EdgesPerVertex = str2num(Val(initM_edges('1,','1,')));
NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
vector = [num2str(NumOfNodes) 'lz_q' num2str(str2num(Val(cur_it('1,','1,'))))];

%m = DB(['M' num2str(NumOfNodes) '_' num2str(EdgesPerVertex)]);
m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors
 output = DB([num2str(NumOfNodes) 'lz_vpath']);
v = DB(vector);
num = DB(['Entries' num2str(NumOfNodes)]);  %% This table stores the elements for each column

w = zeros(Np,1,map([Np 1],{},0:Np-1));

myProc = global_ind(w); %Parallel
	
 %%% TO log the performance%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
	 %  if(~exist([root '/timing'],'dir'))
        %	mkdir([root '/timing']);
	%   else 
	%	rmdir([root '/timing'],'s')
	%	mkdir([root '/timing']);
         %   end

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
		     fname = ([root '/timing/' num2str(i) '_'  'Machines'  num2str(NumOfMachines) '_'  datestr(now)  '_stat.txt']);
                  fstat = fopen(fname,'a+');

		            %% Read the vector
                        this = tic;
                        [vecr,vecc,vecv] = v(:,'1,');
                        vecr = sscanf(vecr,'%f');
                        %vecc = str2num(vecc);
                        vecv = sscanf(vecv,'%f');
                        myVector = sparse(vecr,1,vecv,NumOfNodes,1);
                        readv = toc(this);
                         fwrite(fstat, ['Read vector: ' num2str(readv) 's' sprintf('\t') ]);
			%%%%%%

	% for columns = start_col:end_col
                        if(exist([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines)  '/' num2str(i) '_' num2str(NumOfProcessors)  '.txt']))  %% We have one row to multiply
		
			this = tic;
                        inputData = dlmread([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines)  '/' num2str(i) '_' num2str(NumOfProcessors) '.txt']);
			readlocal = toc(this);
			fwrite(fstat, ['Read processor id: ' num2str(i) ' from file costs: ' num2str(readlocal) 's' sprintf('\t') ]);
			
			this = tic;
			%onerowofmatrix = sparse(inputData(:,1),inputData(:,2),inputData(:,3),1,NumOfNodes);
			onepartofmatrix = sparse(inputData(:,1)-start_col+1,inputData(:,2),inputData(:,3),end_col-start_col+1,NumOfNodes);
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

			
	
			          
                   end
		  disp('Insertation done!');
         %       end
                    fwrite(fstat, ['Done' ]);
		    fclose(fstat);
        else
        disp(['I am just waiting!']);
        end
end
disp('Waiting to be agged!');
agg(w);
