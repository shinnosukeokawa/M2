--- status: Draft, not done
--- author(s): MES
--- notes: bug exists

document { 
     Key => {truncate,
	  (truncate,ZZ,Module),
	  (truncate,List,Module),
	  (truncate,ZZ,Ideal),
	  (truncate,List,Ideal)},
     Headline => "truncate the module at a specified degree",
     Usage => "truncate(i,M)",
     Inputs => {
	  "i" => "an integer or a list of integers, representing a degree or multi-degree",
	  "M" => "a module or an ideal"
	  },
     Outputs => {
	  "the ideal or submodule of M consisting of all elements of degree >= i."
	  },
     "If ", TT "i", " is a multi-degree, then the result is the submodule generated by all elements
     of degree exactly ", TT "i", ", together with all generators of ", TT "M", " whose first degree is higher than the
     first entry in ", TT "i", ".",
     EXAMPLE {
	  "R = ZZ/101[a..c];",
      	  "truncate(2,R^1)",
      	  "truncate(2, ideal(a,b,c^3)/ideal(a^2,b^2,c^4))",
	  "truncate(2,ideal(a,b*c,c^7))"
	  },
     PARA{},
     "The base may be ZZ, or another polynomial ring.  In this case, the generators may not
     be minimal.",
     EXAMPLE {
	  "A = ZZ[x,y,z];",
	  "truncate(2,ideal(3*x,5*y,15))",
	  "truncate(2,comodule ideal(3*x,5*y,15))"
	  },
     EXAMPLE {
	  "L = ZZ/691[x,y,z];",
	  "B = L[s,t,Join=>false];",
	  "truncate(2,ideal(3*x*s,5*y*t^2,s*t))",
	  "truncate(2,comodule ideal(3*x,5*y,15))"
	  },
     "The following includes the generator of degree {8,20}.",
     EXAMPLE {
      	  "S = ZZ/101[x,y,z,Degrees=>{{1,3},{1,4},{1,-1}}];",
      	  "truncate({7,24}, S^1 ++ S^{{-8,-20}})"
	  },
     Caveat => {
	  "Bug: The answer is not correct in the example over a polynomial ring!",
	  PARA{},
	  "If the degrees of the variables are not all one, then there is
     	  currently a bug in the routine: some generators of higher degree
	  than ", TT "i", " may be duplicated in the generator list."
	  },
     SeeAlso => {comodule}
     }

TEST ///
-- Singly generated case
R = QQ[a..d]
I = ideal(b*c-a*d,b^2-a*c,d^10)
truncate(2,I)
truncate(3,I)
trim oo
betti oo

R = QQ[a..d,Degrees=>{3,4,7,9}]
I = ideal(a^3,b^4,c^6)
truncate(12,I)

R = ZZ[a,b,c]
I = ideal(15*a,21*b,19*c)
truncate(2,comodule I)
///