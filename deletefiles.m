%%%%%%%%%%%%%%%Filename: deletefiles.m%%%%%%%%%%%%%%%%%%%%%%%%%
%% Function: This file will read rows of matrix from local disk and multiply the vector {NumOfNodes}lz_q{cur_it}, the result will be saved to NumOfNodeslz_vpath
%% {NumOfNodes}lz_vpath = matrix * {NumOfNodes}lz_q{cur_it}
%%
myDB;
d = DB('NumOfNodes');
NumOfNodes = str2num(Val(d('1,','1,')));
disp(['****************** Now Running deleting files.m ***********************']);
 
%% create a mydata folder in the installation directory of matlab
root = matlabroot;
if(exist([root '/mydata' num2str(NumOfNodes)],'dir'))
        rmdir([root '/mydata' num2str(NumOfNodes)], 's');
        end


