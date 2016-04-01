function var=testMatVecV3(NumOfMachines, NumOfProcessors)
%%
%%	Usage: this function is used to test Alluxio_Row_mv_version3.m which should be run using:
%%			eval('MPI_Run(Alluxio_Row_mv_version3),Np,machines')
%%

%%%% Create a folder benchmark to store the debugging information
if ~exist('testVersion3','dir')
        mkdir('testVersion3');
end
MatMPI_Delete_all;
fname = ('testVersion3/stat.txt');
fstat = fopen(fname,'a+');

machines=getMachines(NumOfMachines);
str = ['Staring test v3 ...' sprintf('\n')];
disp(str); fwrite(fstat, str);
c = num2cell(clock);
fwrite(fstate, datestr(datenum(c{:})));
thisInTest = tic;
eval(MPI_Run('Alluxio_Row_mv_version3', NumOfProcessors, machines));
that = toc(thisInTest);
c = num2cell(clock);
fwrite(fstate, datestr(datenum(c{:})));
str =['Test costs: ' num2str(that) 's' sprintf('\n')];
disp(str); fwrite(fstat,str);
