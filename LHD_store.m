%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Filename: LHD_store.m
%% Function: This file will save the corresponding part of input matrix to local disk for speeding up future computation. 
myDB; %% connect to DB and return a binding named DB.

%% create a mydata folder in the installation directory of matlab
root = matlabroot;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

  % if(~exist([root '/mydata'],'dir'))
  %      mkdir([root '/mydata']);
  %      end
  %  if(~exist([root '/storelog'],'dir'))
  %      mkdir([root '/storelog']);
   %     end

	

machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');
%initM_edges = DB('edges');
proc_t=DB('NumOfProcessors');

EdgesPerVertex = str2num(Val(initM_edges('1,','1,')));

NumOfProcessors = str2num(Val(proc_t('1,','1,')));

NumOfMachines = str2num(Val(machines_t('1,','1,')));
NumOfNodes = str2num(Val(nodes_t('1,','1,')));


%     if(~exist([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines) ],'dir'))
 %       mkdir([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines) ]);
 %    else
%	rmdir([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines) ],'s');
%	mkdir([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines) ]);
 %       end
  %  if(~exist([root '/storelog' num2str(NumOfNodes) '_' num2str(NumOfMachines)] , 'dir'))
   %     mkdir([root '/storelog' num2str(NumOfNodes) '_' num2str(NumOfMachines) ]);
  %  else
%	rmdir([root '/storelog' num2str(NumOfNodes) '_' num2str(NumOfMachines)  ] ,'s');
%	mkdir([root '/storelog' num2str(NumOfNodes) '_' num2str(NumOfMachines)  ]);
 %       end





disp(['****************** Now Running Store.m ***********************']);

m = DB(['M' num2str(NumOfNodes)]);
cut_t = DB(['Cut' num2str(NumOfNodes)]);   %% Cut table assigns the tasks to the processors

num = DB(['Entries' num2str(NumOfNodes)]);  %% This table stores the elements for each column

w = zeros(Np,1,map([Np 1],{},0:Np-1));

myProc = global_ind(w); %Parallel



%%% Split the tasks based on the cut{numofnodes} table, cut_t(i-1,:) is the end column for current i and cut_t(i-2,:)+1 is the start_col for current i

for i = myProc
	 flog = fopen([root '/storelog' num2str(NumOfNodes) '_' num2str(NumOfMachines)   '/' num2str(i) '.txt'],'w');

    if(i>1)
	


	disp(['My i is: ' num2str(i)]);
	fwrite(flog, ['My i is: ' num2str(i) sprintf('\n')]);
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
	fwrite(flog, ['Start_col : end_col ' num2str(start_col) ' : ' num2str(end_col)]);

	%fid = fopen([root '/mydata/' num2str(i) '.txt'],'a');
	 for columns = start_col:end_col
	 % fid = fopen([root '/mydata/' num2str(i) '_' num2str(columns)  '.txt'],'w');
	disp(['columns is ' num2str(columns)]);
	fwrite(flog, ['columns is ' num2str(columns)]);

		[mr,mc,maxCol] = num(sprintf('%d,',columns),:);
			maxCol= str2num(maxCol);
			if(maxCol~=0)
			%% my old approach write rows of the matrix to a single file, this is not only inefficient but also a waste of space
			% fid = fopen([root '/mydata' num2str(NumOfNodes)  '/' num2str(i) '_' num2str(columns)  '.txt'],'w');
			%% I am writing to a single file

			fid = fopen([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines)  '/' num2str(i) '_' num2str(NumOfProcessors)  '.txt'],'a+');
			mIt = Iterator(m,'elements',maxCol);
                         [localr,localc,localv] = mIt(sprintf('%d,',columns),:);
                           % localr = str2num(localr);
			%for the row we use 1, because we are doing row of matrix times the vector
			    localc = sscanf(localc,'%d');
                            localv = sscanf(localv,'%f');
                          
			   % localr = ones(size(localc,1),1);
			    localr = sscanf(localr,'%d');
                	    data_dump = [localr,localc,localv];
			    fprintf( fid,'%d %d %f\n', data_dump');         
			    fclose(fid);  
                          end
           end
	  % fclose(fid);
	else
	disp(['I am just waiting!']);
	end
end
     
     fid = fopen([root '/mydata' num2str(NumOfNodes) '_' num2str(NumOfMachines)  '/done.txt'],'w');
     fwrite(fid, '** Done**');
     fclose(fid);
     fclose(flog);
agg(w);

%{
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% parallel part %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% For now split is evenly distributed among the machines
%p = floor(NumOfNodes / NumOfMachines);
%colGap = floor(NumOfNodes / NumOfMachines);
%NpPerMachine = floor(Np/NumOfMachines);
%lazy = ceil(Np/NumOfMachines);

colGap = floor(NumOfNodes / (Np-1)); %% Actually working processors = Np - 1; Because the process 0 is just waiting.

%rowCut = floor(Np/NumOfMachines);
%colCut = NumOfMachines;
w = zeros(Np,1,map([Np 1],{},0:Np-1));

myProc = global_ind(w); %Parallel
%SecondD = global_ind(w,2);

%We will let the first machine serve as a namenode to wait for all worknodes to finish, the first ceil(Np/NumOfMachines) will be left to the rest nodes to finish
for i = myProc
	disp(['My processes # is :' num2str(i)]);
    if (i>1)
        start_col = (i-1-1)*colGap+1;
        if (i<Np)
        end_col = (i-1)*colGap ;
        else
        end_col = NumOfNodes ;
        end
            disp(['start_col: ' num2str(start_col) ' end_col: ' num2str(end_col)]);

            ArowStr = '';
	    AcolStr = '';
            AvalStr = '';
	   tic;	
	    allM = m(sprintf('%d,',start_col:end_col),:);
	   queryT = toc;
	  disp(['Query time is: ' num2str(queryT)]);	
            for columns = start_col:end_col
                %// We are gonna assume that our memory is big enough to hold one column of the input matrix. 

                %//Jvector is the corresponding vector row value to be multiplied to our input matrix m.
                %// if Jvector is zero there is no need to do the calculation because all elements will become zero.
                %// columns is the row index for our vector
		%tic;
                %disp(['Current column is ' num2str(columns)])
	%	tic;
                    if(~isempty(Val(v(sprintf('%d,',columns),:))))
                     Jvector = str2num(Val(v(sprintf('%d,',columns),:)));
			%tic;
                        % allM = m(sprintf('%d,',columns),:);
		 	%queryT=toc;
			%disp(['Query time is: ' num2str(queryT)]);
		%	tic;
                         [localr,localc,localv] = allM(sprintf('%d,',columns),:);
                         if(~isempty(localv))
                            localv = str2num(localv);
                            localv = localv * Jvector;
                           % ArowStr = localr
                           % AcolStr = sprintf('%d,',columns)
                           % AvalStr = sprintf('%.15f,',localv)
			     ArowStr = strcat(ArowStr,sprintf('%d,',str2num(localc)));
                            AcolStr =  strcat(AcolStr,sprintf('%d,',str2num(localr)));
                            AvalStr = strcat(AvalStr, sprintf('%.15f,',localv));
                           % put(temp,Assoc(ArowStr,AcolStr,AvalStr));
                          end
		%	calT=toc;
		%	disp(['Cal time is: ' num2str(calT)]); 
                    end
	%	iterationT=toc;
	%	disp(['One iteration time is: ' num2str(iterationT)]);
		
           end
	   put(temp,Assoc(ArowStr,AcolStr,AvalStr));
		else
		disp(['I am just waiting']);
		end	   
	 
	end % end for lazy
	
   %% End for w
totalT=toc;
disp(['Total Running time is: ' num2str(totalT)]);
tic;
agg(w);
waitingT=toc;
disp(['Total syn time is: ' num2str(waitingT)]);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%}
