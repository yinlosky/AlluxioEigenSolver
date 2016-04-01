%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% Second, we will read all the temporary results and sum them and sqr root not parallel 
%%
%% The result will be stored in scalar_b, and also in table scalar_b.	
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disp('Running p2!');
temp_t = DB(['lz_norm_v' num2str(NumOfNodes) '_temp']); % remove the temp table if exisits already 
p = DB('NumOfProcessors');
NumOfProcessors = str2num(Val( p(:,:)));
disp(['Try to verify if temp_t has ' num2str(NumOfProcessors)  ' elemetns!']);
temp_t(:,:)

cur_it = DB('cur_it');
my_it =  str2num(Val(cur_it('1,','1,')));
OutputT = DB('beta');

 [temp_t_Row,temp_t_Col,temp_t_Val] = temp_t(sprintf('%d,',1:NumOfProcessors),:);
 if(isempty(temp_t_Val))
	scalar_v = 0;
 else scalar_v = sum(str2num(temp_t_Val));
 end   %%% Calcualate the total sum of the values	


%disp(['Before sqrt: ' sprintf('%.15f,', scalar_v)]);
scalar_v = sqrt(scalar_v);
%disp(['After sqrt: ' sprintf('%.15f,', scalar_v)]);


A = Assoc(sprintf('%d,',my_it),'1,',sprintf('%.15f,',scalar_v));  % result will be written to beta_t(it, 1)
put(OutputT, num2str(A)); %% when insert into accumulo table, Associative array should be transferred into string type
%disp(['In p2 Sum is: ' sprintf('%.15f',scalar_v)]);
%disp(['In table: ' num2str(Val(OutputT(sprintf('%d,',my_it),'1,')))]);
