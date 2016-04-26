function [StartVertex EndVertex] = SymKronGraph500NoPerm(TotalNum,EdgesPerVertex,ProcId, it_num)
  %Graph500NoPerm: Generates symmetric graph edges using the same 2x2 Kronecker algorithm (R-MAT) as the Graph500 benchmark, but no permutation of vertex labels is performed.
%IO user function.
  %  Usage:
  %    [StartVertex EndVertex] = Graph500NoPerm(SCALE,edgefactor)
  %  Inputs:
%    SCALE = integer scale factor that sets the max number of vertices to 2^SCALE
  %    EdgesPerVertex = sets the total number of edges to M = K*N;
% Outputs:
%    StartVertex = Mx1 vector of integer start vertices in the range [1,N]
  %    EndVertex = Mx1 vector of integer end vertices in the range [1,N]
% The output will also be written to a file named Heigen{scale}_randnum.edge  
%pause(120*ProcId);

[idum, my_machine] = system('hostname'); 
 my_machine = strtrim(my_machine);

  N = TotalNum-1;              % Set  power of number of vertices..
  SCALE = log2(TotalNum);

  M = round(EdgesPerVertex .* N);     % Compute total number of edges to generate.

  A = 0.57; B = 0.19;  C = 0.19;   D = 1-(A+B+C);  % Set R-MAT (2x2 Kronecker) coefficeints.

  ij = ones (2, M);           % Initialize index arrays.
  ab = A + B;                 % Normalize coefficients.
  c_norm = C/(1 - (A + B));
a_norm = A/(A + B);
disp(['Starting to initialize...' sprintf('\n')]);
for ib = 1:SCALE            % Loop over each scale.
           ii_bit = rand(1, M) > ab;
jj_bit = rand(1, M) > ( c_norm * ii_bit + a_norm * not (ii_bit) );
ij = ij + 2^(ib-1) * [ii_bit; jj_bit];
  end

  StartVertex = ij(1,:).';     % Copy to output.
  EndVertex = ij(2,:).';       % Copy to output.
  fidEdge =fopen(['it' num2str(it_num) '_Heigen' num2str(TotalNum) '_' my_machine '_' num2str(feature('getpid'))  '.edge'],'w');
  disp(['Writing to local disk for Heigen!!!' sprintf('\n')]);
  this = tic;
  for index = 1:M
      myStr = sprintf('%d\t%d',StartVertex(index),EndVertex(index));
      if (index ~= M)
      fwrite(fidEdge,myStr);
      fwrite(fidEdge,sprintf('\n'));
      else
        fwrite(fidEdge,myStr);
      end
  end
  wtime = toc(this);
  disp(['Writing time: ' num2str(wtime) 's' sprintf('\n')]);
  startv = ij(1,:).';
  endv = ij(2,:).';
  StartVertex = vertcat(startv,endv);
  EndVertex = vertcat(endv,startv);
  disp(['Writing done! Now return from function.' sprintf('\n')]);
end

