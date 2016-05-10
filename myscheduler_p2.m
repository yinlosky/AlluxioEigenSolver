function myscheduler_p2(Np, EdgesPerVertex)
%%
%% This function is used to schedule the cut table for all processors accross the cluster
%%

%% Connect to the DB first
myDB;

%% Total number of nodes
nodes_t = DB('NumOfNodes');
NumOfNodes = str2num(Val(nodes_t('1,','1,')));

% Connect to the matrix table
m = DB(['M' num2str(NumOfNodes)]);

%% Output table is Cut{NumOfNodes}
thisout = DB(['Entries' num2str(NumOfNodes)]);
cut = DB(['Cut' num2str(NumOfNodes)]);

%% Calculate the average load
%% old unoptimized code
%[tr,tc,tv]=thisout(:,:);
%TotalEn = sum(str2num(tv));

TotalEn = 0;

step = 50000;
totalIndex = floor(NumOfNodes / step);

for i = 1:totalIndex
    disp(num2str(i));
    if i == totalIndex
        start_ind = (i-1) * step+1;
        end_ind = NumOfNodes;
        [tr,tc,tv]=thisout(sprintf('%d,',start_ind:end_ind),:);
        TotalEn = TotalEn+sum(str2num(tv));
    else
        start_ind = (i-1)* step+1;
        end_ind = i*step;
        [tr,tc,tv]=thisout(sprintf('%d,',start_ind:end_ind),:);
        TotalEn = TotalEn+sum(str2num(tv));
    end
end


disp(['Total entries are: ' num2str(TotalEn)]);
load = TotalEn/(Np-1); % process 0 is just waiting
disp(['Load is: ' num2str(load)]);
avgCol = floor(NumOfNodes/(Np-1));



%% First I need some ticks as a dividing marks
%% The number of ticks = (Np - 2) THe reason of subtracting 2 is because process 0 is not working.

%% load is the average number of elements for each process
%% StandardM[] is the original mark for each process, which is the equal division of the array. 
startCol = 1;
my_step = ceil(load * (EdgesPerVertex/NumOfNodes)); %% set the step as sparseness * load
for ticks = 1 : Np-2

  endCol = [floor(startCol / avgCol ) + 1]  * avgCol;
 % disp(['Start:end is ' num2str(startCol) ':' num2str(endCol)]);
  [outputr,outputc,outputv] = thisout(sprintf('%d,',(startCol):endCol),:);
  outputv = str2num(outputv);
  CurrentLoad = sum(outputv);
 % disp(['Current load is ' num2str(CurrentLoad)]);
	if CurrentLoad > load
 		while CurrentLoad > load
	      		CurrentLoad = CurrentLoad - str2num(Val(thisout(sprintf('%d,',endCol),:)));
            % comment below to set the step so the scheduler will converge
            % faster
            %    endCol = endCol - 1;
                endCol = endCol - my_step;
             
        
        end
	%	disp(['CurrentLoad is: ' num2str(CurrentLoad) ' Load is ' num2str(load)  ]); 
	%	disp(['endCol is: ' num2str(endCol)]);
	else
	%	disp(['Executing the else part!']); 
		while CurrentLoad < load
			%endCol = endCol + 1;
             endCol = endCol + my_step;
			CurrentLoad = CurrentLoad + str2num(Val(thisout(sprintf('%d,',endCol),:)));
		end
	end
	startCol = endCol+1;
        put(cut, Assoc(sprintf('%d,',ticks), '1,',sprintf('%d,',endCol)));  	

end  % end for

