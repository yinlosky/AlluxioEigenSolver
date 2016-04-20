function [ Mat_str ] = convertJavaToMat( Java_str )
%UNTITLED8 Summary of this function goes here
%   Detailed explanation goes here
 
Mat_char = char(Java_str);
Mat_str = sscanf(Mat_char,'%f');

end

