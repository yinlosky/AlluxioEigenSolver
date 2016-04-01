%function scheduler()
%%%
%% This scheduler will first find the entries for each column of our input matrix to calculate the total number of entries in the matrix;
%% Based on the number of entries, we want to evenly distribute the work load to our workers.
%%
%% Input: NumOfMachines, NumOfProcessors, NumOfNodes
%% Output: The cut of the input matrix for each processor will be written to a table named Cut{NumOfNodes} in our accumulo table 

%Connection to the Database;
myDB;


%The name of the input matrix is named as M{2^Scale}
scale_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(scale_t('1,','1,')));
m = DB(['M' num2str(NumOfNodes)]);

%%%% Output is called Entries{NumOfNodes}
thisout = DB(['Entries' num2str(NumOfNodes)]);
cut = DB(['Cut' num2str(NumOfNodes)]);

%%%% Start the parallel part for the scheduler
colGap = floor(NumOfNodes / (Np-1)); %% Actually working processors = Np-1 ; because processor 0 is doing nothing
w = zeros(Np,1,map([Np 1],{},0:Np-1));
myProc = global_ind(w); %Parallel

%%%%%%%%
for i = myProc
        disp(['My processes # is :' num2str(i)]);
    if(i>1)
        start_col = (i-1-1)*colGap+1;
        if (i<Np)
        end_col = (i-1)*colGap ;
        else
        end_col = NumOfNodes ;
        end
            disp(['start_col: ' num2str(start_col) ' end_col: ' num2str(end_col)]);
                AvalStr ='';
                for j = start_col:end_col
                itic = tic;
                numofentries = nnz(m(sprintf('%d,',j),:));
                oneq = toc(itic);
                disp([num2str(j) 'th time: ' num2str(oneq) ' entries: ' num2str(numofentries)]);
                AvalStr = strcat(AvalStr, sprintf('%d,',numofentries));
                end
                ArowStr = sprintf('%d,', start_col:end_col);
                AcolStr = '1,';
                put(thisout,Assoc(ArowStr,AcolStr,AvalStr));
        else
                disp(['I am just waiting!']);
        end
end
agg(w);


