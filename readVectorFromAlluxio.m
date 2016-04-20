function [ output ] = readVectorFromAlluxio( FilePath )
%UNTITLED4 Summary of this function goes here
%   Detailed explanation goes here
import yhuang9.testAlluxio.* ;

inputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' ...
    FilePath '_v' '|CACHE|CACHE_THROUGH']);
this = tic;
output=javaMethod('readFile', inputobject_v);
savetime = toc(this);
disp([sprintf('\n') 'Reading from Alluxio costs: ' num2str(savetime) sprintf('\n')]);
end

