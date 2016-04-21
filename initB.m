%%
%% initB script is used for parallelizing to initialize the B vector
%%
%% Connect to database 
myDB;
format long e;

%% Create the table to store 
nodes_t=DB('NumOfNodes');
NumOfNodes=str2num(Val(nodes_t(:,:)));
machines_t=DB('NumOfMachines');
NumOfMachines=str2num(Val(machines_t(:,:)));

B=DB(['B' num2str(NumOfNodes)]);



%% Parallel populate the B{NumOfNodes} table
gap = floor(NumOfNodes/Np);
w=zeros(NumOfMachines,1,map([Np 1],{},0:Np-1));
myMachine = global_ind(w);

for i = myMachine
        start_node = (i-1)*gap+1;
        if(i<NumOfMachines)
        end_node = i*gap;
        else
        end_node = NumOfNodes;
        end
        length = end_node - start_node+1;
        disp(length);
        rowStr = sprintf('%d,',start_node:end_node);
        disp(rowStr);
        valStr = sprintf('%.15f,', rand(1,length,'double'));
        %colStr = sprintf('%d,',ones(1,length));
        newAssoc = Assoc(rowStr,'1,',valStr);
        put(B,newAssoc);
end
agg(w);




