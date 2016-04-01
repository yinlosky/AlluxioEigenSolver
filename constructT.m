function Tmatrix = constructT(k, alpha, bet)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% filename: constructT.m
%% function: This function is used to construct the tridiagonal matrix T from alpha and beta array
%% Input: para1 iteration number k
%%	  para2 alpha array
%%        para3 beta array
%% Output: Tridiagonal matrix T

%% Note: k: [1,m] m is the max iteration
%%       alpha: index starts with 1 in matlab and the length of alpha is m
%%       beta: index starts with 1 and the length of beta is m 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp(['**************Now constructing T matrix from alpha and beta******************']);

%%construct tridiagonal matrix T from alpha(1:m) and beta(2:m)
	main_diag = alpha(1:k);
	if(k<2)
        	Tmatrix = diag(main_diag);
	else 
		main_diag = alpha(1:k);
		off_diag = bet(1:k-1);
                Tmatrix = diag(main_diag) + diag(off_diag,1) + diag(off_diag,-1);
		Tmatrix
	end
end
