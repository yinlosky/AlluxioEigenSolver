function [ output_args ] = saveVectorToAlluxio( FilePath, Msg )
%saveToAlluxio Summary:
%       This function serves to save Msg into the filepath to Alluxio
%   If we save vector to Alluxio we only need save the value since the 
%  scheduler knows the row range, and vector has '1,' for all columns.
import yhuang9.testAlluxio.* ;

outputobject_v = AlluxioWriteRead(['alluxio://n117.bluewave.umbc.edu:19998|' ...
    FilePath '_v' '|CACHE|CACHE_THROUGH']);
this = tic;
javaMethod('writeFile', outputobject_v, Msg);
savetime = toc(this);
disp([sprintf('\n') 'Saving to Alluxio costs: ' num2str(savetime) sprintf('\n')]);
end

