function result = parallel_dotproduct_p2()
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% File Name: parallel_dotproduct_p2.m
%% Function: p2 of parallel_dotproduct, which will read all data from dot_temp table and sum them up this can be done locally 

%% Author: Yin Huang
%% Date: Dec 11 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%  Above will write NumOfMachines result in the temp table
%  Now we need read all of them and add them up into 
final = 0;
myDB;
temp = DB('dot_temp');

processors_t = DB('NumOfProcessors');
NumOfProcessors = str2num(Val(processors_t('1,','1,')));

%% temp(:,sprintf('%d,',1:NumOfMachines)) will not return the things I need. 
[tRow,tCol,tVal] = temp(sprintf('%d,',1:NumOfProcessors),:); %% This range query works for rows not for cols so this is fine.

if(~isempty(tVal))
%tVal = str2num(tVal);
tVal=sscanf(tVal,'%f');
final = sum(tVal);
else 
final = 0;
end

result = final;
