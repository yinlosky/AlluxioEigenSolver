%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File name: onetime_saxv.m
%% Function: This function will calculate v = v - beta_sax_temp - alpha_sax_temp ; if it>1 in one function
%%					  v = v - alpha_sax_temp; if i==1
%% input:    alpha_sax_temp is the table 'alpha_sax_temp';
%% 	     beta_sax_temp is the table 'beta_sax_temp'
%%	     v is from 'mv_output'
%% 			
%% Output:  'lz_vpath'
%%
%% Author: Yin Huang
%% Date: Dec 11, 2014

myDB; %% connect to DB and return a binding named DB.

machines_t = DB('NumOfMachines');% we parallel on the processors' level
np_t = DB('NumOfProcessors');
nodes_t = DB('NumOfNodes');
cur_it = DB('cur_it');
NumOfNodes = str2num(Val(nodes_t('1,','1,')));
Np = str2num(Val(np_t('1,','1,')));


v = DB([num2str(NumOfNodes) 'lz_vpath']);

NumOfMachines = str2num(Val(machines_t('1,','1,')));

	%cut_t = DB(['Cut' num2str(NumOfNodes)]);

it = str2num(Val(cur_it('1,','1,')));
	colGap = floor(NumOfNodes / (Np-1));

alpha_t= DB('alpha');
beta_t = DB('beta');

%% output table %%%%%%%%%%%%%%%%%
      parallel_sax_v_t = DB([num2str(NumOfNodes) 'lz_vpath']);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

disp(['**************In onetime_saxv****************' sprintf('\n')  'Calcuating lz_vpath = lz_vpath - beta_sax_temp - alpha_sax_temp with colGap: ' num2str(colGap)]);
	

w = zeros(Np,1,map([Np 1],{},0:Np-1));
	myMachine = global_ind(w); %Parallel
	for i = myMachine
	 if(i>1)
        start_node = (i-1-1)*colGap+1;
        if (i<Np)
        end_node = (i-1)*colGap ;
        else
        end_node = NumOfNodes ;
        end
	disp(['start index: ' num2str(start_node) ' end index: ' num2str(end_node)]);
	vectorLength = end_node - start_node + 1;
%%% we keep the for loop because we need make sure the query return value sequence is the same or it will give the wrong answer.
		
        if(it == 1) %% v = v - alpha_i * vi
			
		  %% we get the v_vector from v table
		  [vr,vc,vv] = v(sprintf('%d,',start_node:end_node),:);
		 % vr = str2num(vr) - (i-2)*colGap; vc = str2num(vc); vv = str2num(vv);
		 vr = sscanf(vr,'%d') - (i-2)*colGap; vc = sscanf(vc,'%d'); vv = sscanf(vv,'%f');
		  v_vector = sparse(vr, vc, vv, vectorLength, 1);

              
                   %% we get alpha_i 
				
	[alphaR,alphaC,alphaV]= alpha_t(sprintf('%d,',it),:);
		if (isempty(alphaV))
        		alpha_value = 0;
			else
        		alpha_value = str2num(alphaV);
		end

		%% we get  v_i
		  vector_i = [num2str(NumOfNodes) 'lz_q' num2str(it)];
        	  vector_i_t = DB(vector_i);
		  [vir,vic,viv] = vector_i_t(sprintf('%d,',start_node:end_node),:);
		 %vir = str2num(vir) - (i-2)*colGap; vic = str2num(vic); viv = str2num(viv);
		  vir = sscanf(vir,'%d') - (i-2)*colGap; vic = sscanf(vic,'%d'); viv = sscanf(viv,'%f');
		  viv = viv .* alpha_value;
		 vi_vector = sparse(vir, vic,viv, vectorLength, 1);	
	      	
		%% we calculate v = v - vi* alpha_i;
    		valVector = full(v_vector) - full(vi_vector);
                %% save result to v; 
		put(parallel_sax_v_t,Assoc(sprintf('%d,',start_node:end_node),'1,',sprintf('%.15f,',valVector)));

	else    %% v = v - beta_i-1*v_i-1 - alpha_i * v_i
		
		 %% we get the v_vector from v table
                  [vr,vc,vv] = v(sprintf('%d,',start_node:end_node),:);
                  %vr = str2num(vr) - (i-2)*colGap; vc = str2num(vc); vv = str2num(vv);

		 vr = sscanf(vr,'%d') - (i-2)*colGap; vc = sscanf(vc,'%d'); vv = sscanf(vv,'%f');
                  v_vector = sparse(vr, vc, vv, vectorLength, 1);


                   %% we get alpha_i 

        [alphaR,alphaC,alphaV]= alpha_t(sprintf('%d,',it),:);
                if (isempty(alphaV))
                        alpha_value = 0;
                        else
                        alpha_value = str2num(alphaV);
                end

                %% we get  v_i
                  vector_i = [num2str(NumOfNodes) 'lz_q' num2str(it)];
                  vector_i_t = DB(vector_i);
                  [vir,vic,viv] = vector_i_t(sprintf('%d,',start_node:end_node),:);
                 vir = sscanf(vir,'%d') - (i-2)*colGap; vic = sscanf(vic,'%d'); viv = sscanf(viv,'%f'); 
		% vir = str2num(vir) - (i-2)*colGap; vic = str2num(vic); viv = str2num(viv);
                  viv = viv .* alpha_value;
                 vi_vector = sparse(vir, vic,viv, vectorLength, 1);

                %% we calculate v = v - vi* alpha_i;
                valVector = full(v_vector) - full(vi_vector);

		%% we get beta_i-1

	[betaRow,betaCol,betaVal]=beta_t(sprintf('%d,',it-1),:);
        	if(~isempty(betaVal))
                beta_value = str2num(betaVal);
    		else
       		 beta_value = 0;
    		end
		%% we get v_i-1
	       vector_i1 = [num2str(NumOfNodes) 'lz_q' num2str(it-1)];
                  vector_i1_t = DB(vector_i1);
                  [vi1r,vi1c,vi1v] = vector_i1_t(sprintf('%d,',start_node:end_node),:);
                  vi1r = sscanf(vi1r,'%d') - (i-2)*colGap; vi1c = sscanf(vi1c,'%d'); vi1v = sscanf(vi1v,'%f');
		% vi1r = str2num(vi1r)-(i-2)*colGap ; vi1c = str2num(vi1c); vi1v = str2num(vi1v);
                  vi1v = vi1v .* beta_value;
                 vi1_vector = sparse(vi1r, vi1c,vi1v, vectorLength, 1);

                valVector = valVector - full(vi1_vector);


                %% save result to v; 
                put(parallel_sax_v_t,Assoc(sprintf('%d,',start_node:end_node),'1,',sprintf('%.15f,',valVector)));
				
		end
	else 
         disp(['I am just waiting']);
	end
	end

	agg(w);

