function Number = parallel_selective_orthogonalize(k, beta_i, v_path, Q, D, NumOfNodes, NumOfMachines,NumOfProcessors)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File name: parallel_selective_orthogonalize.m
%% This is the function for deciding if an orthogonalization is needed, return the count of orthogonalizations
%% 
%% Input:  
%%   	para1: k, the number of iteration
%% 	para2: beta_i, the ith element in beta
%%	para3: vector V name (V in our algorithm)
%%	para4: path of Q (Q is the decomposed eigenvectors)
%%      para5: path of D (D is the decomposed eigenvalues)
%% Output: 
%%	How many times to orthogonalize 
%% Besides if reorthogonalize, r will be written to table r_path, and v will be updated 
%%
%% Author: Yin Huang
%% Date: Nov,30,2014
%%

disp(['!!!!!!!Now running parallel_so !!!!!!!!!!!!!']);
myDB;

       switch NumOfMachines
         case 1
                machines={'n117'};
         case 2
                machines={'n117' 'n118'};
         case 3
                machines={'n117' 'n118' 'n119'};
         case 4
                machines={'n117' 'n118' 'n119' 'n120'};
         case 5
                machines={'n117' 'n118' 'n119' 'n120' 'n121'};
         case 6
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122'};
         case 7
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123'};
         case 8
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124'};
         case 9
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125'};
         case 10
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126'};
        case 11
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127'};
        case 12
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127' 'n128'};
        case 13
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127' 'n128' 'n129'};
        case 14
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127' 'n128' 'n129' 'n130'};
        case 15
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127' 'n128' 'n129' 'n130' 'n131'};
        case 16
                machines={'n117' 'n118' 'n119' 'n120' 'n121' 'n122' 'n123' 'n124' 'n125' 'n126' 'n127' 'n128' 'n129' 'n130' 'n131' 'n132'};
        end


cur_loop_j = DB('cur_loop_j');
eps = 2.204e-16;
reortho_count = 0;

error_bound = abs(sqrt(eps)*D(k));

for j = 1:k
	cur_error = abs(beta_i * Q(k,j));
	disp(['Error of' num2str(j) '/' num2str(k) ' th vector:' num2str(cur_error) 'compare to ' num2str(error_bound)]);
		
		if(cur_error <= error_bound)
			disp(['V need to be reorthogalized by ' num2str(j) 'th Ritz Vector']);
				reortho_count =  reortho_count + 1;
			disp(['Reorthogonalizing against' num2str(j) 'th Ritz vector']);
			% write a method to compute r r = V[i,:]*Q[:,j] computR.m
		
			%rpath = computeR(k,j,Q, NumOfNodes, NumOfMachines); %% k is the cur_it value, j is current loop id, Q is the eigenVector matrix constructed from T
				%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% output: 'so_rpath'

			disp(['Store j: ' num2str(j) ' into cur_loop_j(1,1) table']);
				loop_j_Assoc = Assoc('1,','1,',sprintf('%d,',j));
			put(cur_loop_j,loop_j_Assoc);
		
       		 %R_output = DB('so_rpath'); delete(R_output);
			eval(pRUN('parallel_computeR',NumOfProcessors,machines)); %% should write to 'so_rpath', all processes should know the cur_it as k, cur_loop_j as j, Q is the eigenVector matrix from T %%%%%%%
				
			eval(pRUN('parallel_rtv_p1',NumOfProcessors,machines));
			parallel_rtv_p2;	
		    p_rtv_temp = DB('rtv_temp');delete(p_rtv_temp);
		  
			eval(pRUN('parallel_so_rrtv',NumOfProcessors,machines)); %% times 'so_rpath' with 'scalar_rtv' and store in 'so_rrtv'
			
	    	eval(pRUN('parallel_so_updatev',NumOfProcessors,machines)); %% lz_vpath is finally updated!!
		
		end
end
	        
Number = reortho_count;
end
