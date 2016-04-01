function parallel_lz_norm_B_p2(Np)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Second, we will read all the temporary results and sum them and sqr root not parallel 
%%
%% The result will be stored in scalar_b, and also in table scalar_b.	
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Initialize the tables 
myDB;
%machines_t = DB('NumOfMachines');
nodes_t = DB('NumOfNodes');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%NumOfMachines = str2num(Val(machines_t('1,','1,')));
%NumOfMachines = 1;
%NumOfNodes = str2num(Val(nodes_t('1,','1,')));
%NumOfNodes = 16;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


%%%%%%%%%%%%%%%%%%

disp('Running p2!');
temp_t = DB('lz_norm_B_temp2'); % remove the temp table if exisits already 
%disp('Try to verify if temp_t has 2 elemetns!');
temp_t(:,:);
tic;
myProc = 1:Np;
scalar_b=0;
for i= myProc
	disp(num2str(i));
	temp = str2num(Val(temp_t(sprintf('%d,',i),'1,')));
	disp(['temp ' num2str(i) 'th is: ' num2str(temp)]);
	scalar_b = scalar_b+ temp;
end
disp(['Before sqrt: ' sprintf('%.15f,', scalar_b)]);
scalar_b = sqrt(scalar_b);
disp(['After sqrt: ' sprintf('%.15f,', scalar_b)]);

OutputT = DB('scalar_b');
A = Assoc('1,','1,',sprintf('%.15f,',scalar_b));
put(OutputT, num2str(A)); %% when insert into accumulo table, Associative array should be transferred into string type
disp(['In p2 Sum is: ' sprintf('%.15f',scalar_b)]);
disp(['In table: ' num2str(Val(OutputT('1,','1,')))]);
sumTime=toc;
 disp(['Time for summing the local files' num2str(sumTime)]);

