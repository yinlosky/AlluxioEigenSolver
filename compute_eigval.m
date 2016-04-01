function compute_eigval(it, alpha, bet, eig_k);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% This function serves to compute the eigvals of the Tmatrix, which are approximately the eigvals of the input matrix. 
%%
%%
%% Author: Yin Huang
%% Date: Dec 3, 2014

Tm = constructT(it, alpha, bet);
[myQ, myD] = eig(Tm);
disp('----------EigenValues of Tm are:--------------');
myD = diag(myD)
if(it >= eig_k)
disp('TOP K eigenValues are:');
myD(1:eig_k)
end
end


