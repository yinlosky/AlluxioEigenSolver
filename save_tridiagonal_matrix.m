function save_tridiagonal_matrix(alpha, bet, n);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% This function is an internal function that will store the alpha and beta array with length n in 
%%% a table called 'lanczos.ab' and the corresponding trimatrix will be saved in 'lanczos.trimat'
%%% 
%%% author: Yin Huang
%%% date: Dec,2,2014
%%% Note: we need save alpha[1...n] and beta[1...n]

ab = 'lanczos.ab';   % first column is alpha, second column is beta
trimat = 'lanczos.trimat'; % the whole matrix will be converted to a string and saved in this table

myDB;
lan_ab = DB(ab);
lan_trimat = DB(trimat);

%%% put alpha in col 1, and beta in col 2 into table lanczos.ab %%%%%%
row = 1:n;
alphaAsso = Assoc(sprintf('%d,',row),'1,',sprintf('%.15f,',alpha(1:n)));
betAsso = Assoc(sprintf('%d,',row),'2,',sprintf('%.15f,',bet(1:n)));
put(lan_ab, alphaAsso);
put(lan_ab, betAsso);

%%% put the trimatrix into lanczos.trimat, Note we put the matrix into a string and store the string%%%%
T = constructT(n, alpha, bet);
str = mat2str(T);
matAsso = Assoc('1,','1,',str);
put(lan_trimat,matAsso);
