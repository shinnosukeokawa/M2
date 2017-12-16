newPackage(
        "GroebnerWalk",
        Version => "1.0.0",
        Date => "November 17, 2017",
        Authors => {{Name => "Dylan Peifer",
                     Email => "djp282@cornell.edu",
                     HomePage => "https://www.math.cornell.edu/~djp282"}},
        Headline => "Compute Groebner bases via the Groebner walk",
        DebuggingMode => true
        )

-- Copyright 2017 Dylan Peifer
-- You may redistribute this file under the terms of the GNU General Public
-- License as published by the Free Software Foundation, either version 2 of
-- the License, or any later version.

export {"groebnerWalk", "setWalkTrace", "getWalkTrace"}

debug Core -- for monomialOrderMatrix and rawGBGetParallelLeadTerms

-------------------------------------------------------------------------------
--- top level functions
-------------------------------------------------------------------------------
groebnerWalk = method(Options => {Strategy => Standard})
groebnerWalk(Ideal, Ring) := GroebnerBasis => opts -> (I, R) -> (
    -- I = an ideal
    -- R = a polynomial ring
    -- returns Groebner basis of the ideal I in the ring R

    groebnerWalk(gb I, R, Strategy => opts.Strategy)
    )
groebnerWalk(GroebnerBasis, Ring) := GroebnerBasis => opts -> (G, R) -> (
    -- G = a Groebner basis of an ideal
    -- R = a polynomial ring
    -- returns Groebner basis of the ideal generated by G in the ring R

    if opts.Strategy === Standard then
        standardWalk(G, R)
    else if opts.Strategy === Generic then
        genericWalk(G, R)
    else
        error "invalid strategy"
    )

walkTrace := 0;
    -- value that determines how much extra information to print
    -- level 0: none
    -- level 1: total conversions
    -- level 2: vector and size of Groebner basis at each conversion
    -- level 3: face codim at each conversion

setWalkTrace = method()
setWalkTrace(ZZ) := ZZ => (n) -> (
    -- n = an integer
    -- sets walkTrace to n
    if n > 2 then << "Warning: computations are much slower with walkTrace > 2"
                  << endl;
    walkTrace = n
    )

getWalkTrace = method()
installMethod(getWalkTrace, () -> walkTrace)
    -- returns the value of walkTrace

-------------------------------------------------------------------------------
--- standard walk
-------------------------------------------------------------------------------
standardWalk = method()
standardWalk(GroebnerBasis, Ring) := GroebnerBasis => (G, Rt) -> (
    -- G = a Groebner basis
    -- Rt = a polynomial ring
    -- returns Groebner basis of the ideal generated by G in the ring Rt

    R := ring G;
    w := weightVector R; -- start weight vector
    wt := weightVector Rt; -- target weight vector
    count := 0; -- count of performed conversions
    
    -- initialization (transfer G to ring with monomial order w, wt, grevlex)
    if walkTrace > 1 then << "Conversion Number: " << count+1 << endl
                          << "Weight Vector: " << w << endl;
    R = newRing(R, MonomialOrder=>{Weights=>w, Weights=>wt});
    G = standardStep(G, R);
    count = count + 1;
    if walkTrace > 1 then << "Size of new Groebner Basis: "
                          << numgens ideal gens G << endl << endl;

    -- step until reaching wt
    while w != wt do (
         w = nextW(G, w, wt);
        if walkTrace > 1 then << "Conversion Number: " << count+1 << endl
                              << "Weight Vector: " << w << endl;

        R = newRing(R, MonomialOrder=>{Weights=>w, Weights=>wt});
        G = standardStep(G, R);
        count = count + 1;
        if walkTrace > 1 then << "Size of new Groebner Basis: "
                              << numgens ideal gens G << endl << endl;
        );

    -- finalization (transfer G from monomial order wt, grevlex to order in Rt)
    if walkTrace > 1 then << "Conversion Number: " << count+1 << endl
                          << "Weight Vector: " << w << endl;
    R = newRing(Rt, MonomialOrder=>{Weights=>wt, (options Rt).MonomialOrder});
    G = standardStep(G, R);
    count = count + 1;
    if walkTrace > 1 then << "Size of new Groebner Basis: "
                          << numgens ideal gens G << endl << endl;

    if walkTrace > 0 then << "Total Conversions: " << count << endl;
    
    -- correct for forceGB not removing content over QQ
    if coefficientRing Rt === QQ then (
        polys := first entries gens G;
	polys = apply(polys, f -> f/(gcd first entries gens content f));
        forceGB sub(matrix {polys}, Rt)
	)
    else
        forceGB sub(gens G, Rt)
    )

standardStep = method()
standardStep(GroebnerBasis, Ring) := GroebnerBasis => (G, R) -> (
    -- G = a Groebner basis over a ring with order compatible with w
    -- R = a ring with monomial order starting with weight w
    -- returns Groebner basis of the ideal generated by G in the ring R

    -- drop to gens of gb of initial ideal in old ring
    oldInG := leadTerm(1, sub(gens G, R));
    if walkTrace > 2 then << "Face Codimension: " << faceCodimension oldInG
                          << endl;

    -- cross to gens of gb of initial ideal in new ring
    newInG := gens gb ideal oldInG;

    -- lift to gb of ideal in new ring
    H := sub(newInG, ring G);
    forceGB sub(H - H % G, R)
    )

nextW = method()
nextW(GroebnerBasis, List, List) := List => (G, w, wt) -> (
    -- G = a Groebner basis
    -- w = a weight vector in the cone of G
    -- wt = a weight vector
    -- returns first weight vector on the line from w to wt in a wall of the
    --     cone of G, scaled to have integer components

    V := unique boundingVectors(G);
    tvals := for v in V list (
	if dot(wt, v) >= 0 then continue;
	dot(w, v)/(dot(w, v) - dot(wt, v))
	);
    t := min(1, min tvals);
    w = (1-t)*w + t*wt;
    w = w / (gcd w);
    apply(w, x -> lift(x, ZZ))
    )

-------------------------------------------------------------------------------
--- generic walk
-------------------------------------------------------------------------------
genericWalk = method()
genericWalk(GroebnerBasis, Ring) := GroebnerBasis => (G, R) -> (
    -- G = a Groebner basis
    -- R = a polynomial ring
    -- returns Groebner basis of the ideal generated by G in the ring R

    S := weightVectors ring G; -- start order
    T := weightVectors R; -- target order
    count := 0; -- count of performed conversions

    -- find first bounding vector
    v := nextV(G, {}, S, T);

    -- step until receiving done signal {} from nextV
    while v != {} do (
        if walkTrace > 1 then << "Conversion Number: " << count+1 << endl
                          << "Bounding Vector: " << v << endl;

	G = genericStep(G, v, R);
	count = count + 1;
        if walkTrace > 1 then << "Size of new Groebner Basis: "
                              << numgens ideal gens G << endl << endl;

	v = nextV(G, v, S, T);
        );

    -- finalization (transfer G to order in R)
    if walkTrace > 0 then << "Total Conversionss: " << count << endl;  

    -- correct for forceGB not removing content over QQ
    if coefficientRing R === QQ then (
        polys := first entries gens G;
	polys = apply(polys, f -> f/(gcd first entries gens content f));
        forceGB sub(matrix {polys}, R)
	)
    else
        forceGB sub(gens G, R)
    )

genericStep = method()
genericStep(GroebnerBasis, List, Ring) := GroebnerBasis => (G, v, R) -> (
    -- G = a Groebner basis
    -- v = bounding vector for wall of cone of G
    -- R = ring with target monomial order
    -- returns Groebner basis in next cone on generic path to R

    -- drop to gens of initial ideal at v
    inI := parallelLeadTerms(G, v);
    if walkTrace > 2 then << "Face Codimension: " << faceCodimension inI
                          << endl;

    -- compute gb of initial ideal over target order
    H := gb ideal sub(inI, R);

    -- lift to new gb of ideal
    M := sub(gens H, ring G);
    markedGB(sub(leadTerm H, ring G), M - M % G)
    )

nextV = method()
nextV(GroebnerBasis, List, List, List) := List => (G, v, S, T) -> (
    -- G = a Groebner basis
    -- v = a bounding vector of cone of G
    -- S = starting weight vectors on generic walk
    -- T = target weight vectors on generic walk
    -- returns next bounding vector on generic path from S to T

    V := unique select(boundingVectors(G), w -> any(w, i -> i < 0));

    -- select bounding vectors such that 0 <_S w
    V = select(V, w -> (for i from 0 to #S-1 do (
                            a := dot(S#i, w);
	                    if a == 0 then continue;
	                    return a > 0;
                            );
		        return false;
		       ));

    -- select bounding vectors such that w <_T 0
    V = select(V, w -> (for i from 0 to #T-1 do (
	                    a := dot(T#i, w);
			    if a == 0 then continue;
			    return a < 0;
                            );
		        return false;
		       ));

    -- except in first step, select bounding vectors greater than current v
    if #v != 0 then V = select(V, w -> isFacetLessThan(v, w, S, T));

    -- if no bounding vectors remain, return {} to signal done
    if #V == 0 then return {};

    -- find minimum v and return it
    minv := V#0;
    for i from 1 to #V-1 do (
    	if isFacetLessThan(V#i, minv, S, T) then minv = V#i;
	);
    minv
    )

-------------------------------------------------------------------------------
--- auxiliary functions
-------------------------------------------------------------------------------
boundingVectors = method()
boundingVectors(GroebnerBasis) := List => (G) -> (
    -- G = a Groebner basis
    -- returns list of vectors bounding the cone of G

    H := first entries gens G;
    inH := first entries leadTerm G;
    flatten apply(#inH, i -> (
        g := H#i; 
        lt := inH#i;
        m := first exponents lt;
        apply(exponents(g-lt), e -> m-e)))
    )

weightVectors = method()
weightVectors(Ring) := List => (R) -> (
    -- R = a polynomial ring
    -- returns a list of weight vectors giving the monomial order of R

    M := monomialOrderMatrix R;
    n := #(options R).Variables; -- size for weight vectors

    head := entries M_0;
    tail := if M_1 === Lex then
                for i from 0 to n-1 list esubi(i, n)
            else if M_1 === RevLex then
                for i from 0 to n-1 list -esubi(n-i-1, n)
	    else
	    	error "invalid monomial order";

    head | tail
    )

weightVector = method()
weightVector(Ring) := List => (R) -> (
    -- R = a polynomial ring
    -- returns an initial weight vector for the monomial order of R

    first weightVectors R
    )

parallelLeadTerms = method()
parallelLeadTerms(GroebnerBasis, List) := Matrix => (G, v) -> (
    -- G = a Groebner basis
    -- v = a bounding vector
    -- returns lead terms of G with following terms that have exponent vector
    --     which differs from lead by a multiple of v

    map(ring G, rawGBGetParallelLeadTerms(raw G, v))
    )

isFacetLessThan = method()
isFacetLessThan(List, List, List, List) := Boolean => (u, v, S, T) -> (
    -- u = bounding vector as a list
    -- v = bounding vector as a list
    -- S = list of weight vectors for the starting term order
    -- T = list of weight vectors for the ending term order
    -- returns if u <= v under the facet preorder

    -- compute and compare (i,j) entries of Tuv^TS^T and Tvu^TS^T
    for i from 0 to #T-1 do (
	for j from 0 to #S-1 do (
	    TuvS := dot(T#i, u) * dot(S#j, v);
	    TvuS := dot(T#i, v) * dot(S#j, u);
	    if TuvS == TvuS then continue;
	    return TuvS < TvuS;
	    );
	);
    return false; -- all comparisons were equal
    )

faceCodimension = method()
faceCodimension(Matrix) := ZZ => (H) -> (
    -- H = generators of inI as a matrix (like gens gb returns)
    -- returns codimension of the face containing the weight vector that gives
    --     inI

    p := flatten entries H;
    V := flatten apply(p, f -> apply(exponents f, m -> m - first exponents f));
    rank matrix V
    )

esubi = method()
esubi(ZZ, ZZ) := List => (i, n) -> (
    -- i = an integer
    -- n = an integer
    -- returns a list of length n with n-1 zeroes and 1 one in the ith position

    toList(i:0) | {1} | toList(n-i-1:0)
    )

dot = method()
dot(List, List) := ZZ => (v, w) -> (
    -- v = a vector as a list
    -- w = a vector as a list
    -- returns the dot product of v and w

    sum(apply(#v, i -> v#i * w#i))
    )

-------------------------------------------------------------------------------
--- documentation
-------------------------------------------------------------------------------
beginDocumentation()

doc ///
Key
  GroebnerWalk
Headline
  Compute Groebner bases via the Groebner walk
Description
  Text
    The Groebner walk is a Groebner basis conversion algorithm. This means it
    takes a Groebner basis of an ideal with respect to one monomial order and
    changes it into a Groebner basis of the same ideal over a different
    monomial order. Conversion algorithms can be useful since sometimes when a
    Groebner basis over a difficult monomial order (such as lexicographic or an
    elimination order) is desired, it can be faster to compute a Groebner basis
    directly over an easier order (such as graded reverse lexicographic) and
    then convert rather than computing directly in the original order. Other
    examples of conversion algorithms include FGLM and Hilbert-driven
    Buchberger.
    
    The Groebner walk performs conversion by traveling through the Groebner
    fan. The Groebner basis is the same for all vectors inside a cone of the
    fan, and when crossing a face into a new cone a (hopefully small)
    adjustment of the Groebner basis is all that must be computed.
    Further background and details can be found in the following resources:
    
    Cox, Little, O'Shea - Using Algebraic Geometry (2005)
    
    Amrhein, Gloor, Kuchlin - On the Walk (1997)
    
    Collart, Kalkbrenner, Mall - Converting Bases with the Groebner Walk (1997)
    
    Fukuda, Jensen, Lauritzen, Thomas - The Generic Grobner Walk (2007)
    
    Tran - A Fast Algorithm for Grobner Basis Conversion and its Applications
    (2000)
    
    In Macaulay2, monomial orders must be given as options to rings. For
    example, the following ideal has monomial order given by first using a
    weight vector and then breaking ties with graded reverse lexicographic.
  Example
    R1 = QQ[x,y,z,u,v, MonomialOrder=>Weights=>{1,1,1,0,0}];
    I1 = ideal(u + u^2 - 2*v - 2*u^2*v + 2*u*v^2 - x,
               -6*u + 2*v + v^2 - 5*v^3 + 2*u*v^2 - 4*u^2*v^2 - y,
	       -2 + 2*u^2 + 6*v - 3*u^2*v^2 - z);
  Text
    If we want a Groebner basis of I with respect to the monomial order
    given by using a different weight vector and then graded reverse
    lexicographic we could substitute and compute directly,
  Example
    R2 = QQ[x,y,z,u,v, MonomialOrder=>Weights=>{0,0,0,1,1}];
    I2 = sub(I1, R2);
    elapsedTime gb I2
  Text
    but it is faster to compute directly in the first order and then use the
    Groebner walk.
  Example
    elapsedTime groebnerWalk(gb I1, R2)
Caveat
  The target ring must be the same ring as the ring of the starting ideal,
  except with different monomial order. The ring must be a polynomial ring
  over a field.
SeeAlso
  groebnerBasis
///

doc ///
Key
  groebnerWalk
  (groebnerWalk, GroebnerBasis, Ring)
  (groebnerWalk, Ideal, Ring)
Headline
  convert a Groebner basis
Usage
  H = groebnerWalk(G, R)
  H = groebnerWalk(I, R)
Inputs
  G: GroebnerBasis
     the starting Groebner basis
  I: Ideal
     the starting ideal
  R: Ring
     a ring with the target monomial order
Outputs
  H: GroebnerBasis
     the new Groebner basis in the target monomial order
Description
  Text
    The Groebner walk takes a Groebner basis of an ideal with respect to one
    monomial order and changes it into a Groebner basis of the same ideal over
    a different monomial order. The initial order is given by the ring of G
    and the target order is the order in R. When given an ideal I as input a
    Groebner basis of I in the ring of I is initially computed directly, and
    then this Groebner basis is converted into a Groebner basis in the ring R.
  Example
    KK = ZZ/32003;
    R1 = KK[x,y,z,u,v, MonomialOrder=>Eliminate 3];
    I1 = ideal(3 - 2*u + 2*u^2 - 2*u^3 - v + u*v + 2*u^2*v^3 - x,
               6*u + 5*u^2 - u^3 + v + u*v + v^2 - y,
	       -2 + 3*u - u*v + 2*u*v^2 - z);
    R2 = KK[x,y,z,u,v, MonomialOrder=>Weights=>{0,0,0,1,1}];
    groebnerWalk(I1, R2)
Caveat
  The target ring R must be the same ring as the ring of G or I, except with
  different monomial order. R must be a polynomial ring over a field.
SeeAlso
  GroebnerWalk
  setWalkTrace
  getWalkTrace
  groebnerBasis
///

doc ///
Key
  [groebnerWalk, Strategy]
Headline
  specify the algorithm for groebnerWalk
Usage
  H = groebnerWalk(G, R, Strategy => Generic)
Description
  Text
    Choose which algorithm to use for the Groebner walk. Options are Standard
    for the original algorithm of Collart, Kalkbrener, and Mall and Generic
    for the generic walk of Fukuda, Jensen, Lauritzen, and Thomas. The default
    option is Standard.
  Example
    KK = ZZ/32003;
    R1 = KK[x,y,z,u,v, MonomialOrder=>Eliminate 3];
    I1 = ideal(3 - 2*u + 2*u^2 - 2*u^3 - v + u*v + 2*u^2*v^3 - x,
               6*u + 5*u^2 - u^3 + v + u*v + v^2 - y,
	       -2 + 3*u - u*v + 2*u*v^2 - z);
    R2 = KK[x,y,z,u,v, MonomialOrder=>Weights=>{0,0,0,1,1}];
    groebnerWalk(I1, R2, Strategy=>Generic)
SeeAlso
  GroebnerWalk
  groebnerWalk
///
    
doc ///
Key
  setWalkTrace
  (setWalkTrace, ZZ)
Headline
  set value of walkTrace
Usage
  setWalkTrace(n)
Inputs
  n: ZZ
     the desired value of walkTrace
Description
  Text
    The value of walkTrace determines how much additional information is
    printed during a call to @TO groebnerWalk@. The function @TO setWalkTrace@
    allows the user to change the value of walkTrace.
    
    Levels of walkTrace are as follows:
    
    Level 0: No additional information is printed. This is the default level.
    
    Level 1: The total number of conversions performed during the algorithm is
    printed at the end of the computation. Conversions are sometimes done in
    initialization and finalization at the start and end of the path, and
    otherwise happen at faces in the Groebner fan.
    
    Level 2: All Level 1 information is printed, and the current vector and
    size of the Groebner basis are printed at each conversion step. Since
    information is printed at each conversion, this level is helpful for
    verifying that the computation is proceeding and noticing where the
    algorithm gets stuck.
    
    Level 3: All Level 2 information is printed, and the codimension of the
    face in the Groebner fan where the conversion is taking place is printed
    at each conversion. Note that running on Level 3 will significantly slow
    down the computation, and is not recommended except for testing.

    For example, running the following code at the default Level 0 prints
    nothing
  Example
    R1 = ZZ/32003[x,y,z, MonomialOrder=>Weights=>{1,10,100}];
    I1 = ideal(y-x^2, z-x^3);
    R2 = ZZ/32003[x,y,z, MonomialOrder=>Lex];
    groebnerWalk(gb I1, R2)
  Text
    while running at Level 2 gives some conversion information.
  Example
    setWalkTrace 2;
    groebnerWalk(gb I1, R2)
SeeAlso
  groebnerWalk
  getWalkTrace
///

doc ///
Key
  getWalkTrace
Headline
  get current value of walkTrace
Usage
  n = getWalkTrace()
Outputs
  n: ZZ
     the current value of walkTrace
Description
  Text
    The value of walkTrace determines how much additional information is
    printed during a call to @TO groebnerWalk@. The function @TO getWalkTrace@
    allows the user to check the current value of walkTrace.
    
    Levels of walkTrace are as follows:
    
    Level 0: No additional information is printed. This is the default level.
    
    Level 1: The total number of conversions performed during the algorithm is
    printed at the end of the computation. Conversions are sometimes done in
    initialization and finalization at the start and end of the path, and
    otherwise happen at faces in the Groebner fan.
    
    Level 2: All Level 1 information is printed, and the current vector and
    size of the Groebner basis are printed at each conversion step. Since
    information is printed at each conversion, this level is helpful for
    verifying that the computation is proceeding and noticing where the
    algorithm gets stuck.
    
    Level 3: All Level 2 information is printed, and the codimension of the
    face in the Groebner fan where the conversion is taking place is printed
    at each conversion. Note that running on Level 3 will significantly slow
    down the computation, and is not recommended except for testing.
  Example
    getWalkTrace()
    setWalkTrace 2;
    getWalkTrace()
SeeAlso
  groebnerWalk
  setWalkTrace
///

-------------------------------------------------------------------------------
--- tests
-------------------------------------------------------------------------------
TEST /// -- esubi and dot
debug GroebnerWalk
assert(esubi(1,4) == {0,1,0,0})
assert(esubi(0,3) == {1,0,0})
assert(dot({1,0,0}, {2,4,6}) == 2)
assert(dot({1,2,3}, {5,7,11}) == 52)
///

TEST /// -- weightVector and weightVectors
debug GroebnerWalk
R1 = QQ[x,y,z]
R2 = QQ[x,y,z, MonomialOrder=>Lex]
R3 = QQ[x,y,z, MonomialOrder=>{Weights=>{1,2,3}, Weights=>{0,2,1}}]
R4 = QQ[x,y,z, MonomialOrder=>Eliminate 2]

assert(weightVector R1 == {1,1,1})
assert(weightVector R2 == {1,0,0})
assert(weightVector R3 == {1,2,3})
assert(weightVector R4 == {1,1,0})

assert(weightVectors R1 == {{1,1,1}, {0,0,-1}, {0,-1,0}, {-1,0,0}})
assert(weightVectors R2 == {{1,0,0}, {0,1,0}, {0,0,1}})
assert(weightVectors R3 == {{1,2,3}, {0,2,1}, {1,1,1}, {0,0,-1}, {0,-1,0}, {-1,0,0}})
assert(weightVectors R4 == {{1,1,0}, {1,1,1}, {0,0,-1}, {0,-1,0}, {-1,0,0}})
///

TEST /// -- bounding vectors
debug GroebnerWalk
R = QQ[x,y,z]
I = ideal(y-x^2, z-x^3)
assert(boundingVectors gb I == {{-1,2,-1}, {1,1,-1}, {2,-1,0}})

R = QQ[x,y,z, MonomialOrder=>Lex]
I = sub(I, R)
assert(boundingVectors gb I == {{0,3,-2}, {1,-2,1}, {1,1,-1}, {2,-1,0}})
///

TEST /// -- parallelLeadTerms
debug GroebnerWalk
R = QQ[x,y,z]
I = ideal(x*y^4*z + y^2 + x*y, x^2*y^2*z + x + y^3*z, z^2 + z)
G = gb I
assert(parallelLeadTerms(G, {0,0,1}) == matrix {{z^2 + z, x*z + x, y^2*z + y^2,
                                                 x^3, y^4, x^2*y^2}})
assert(parallelLeadTerms(G, {2,-1,0}) == matrix {{z^2, x*z, y^2*z, x^3 + x*y,
	    	    	    	    	    	  y^4, x^2*y^2 + y^3}})
assert(parallelLeadTerms(G, {1,1,1}) == matrix {{z^2, x*z, y^2*z, x^3, y^4,
	    	    	    	    	    	 x^2*y^2}})
///

TEST /// -- isFacetLessThan
debug GroebnerWalk
S = {{1,0,0}, {0,1,0}, {0,0,1}}
T = {{1,1,1}, {0,2,-1}, {3,5,1}}
assert(isFacetLessThan({2,0,-1}, {1,2,3}, S, T))
assert(not isFacetLessThan({1,2,3}, {1,1,1}, S, T))
assert(not isFacetLessThan({4,5,6}, {8,10,12}, S, T))
assert(isFacetLessThan({0,4,5}, {0,2,3}, S, T))
///

TEST /// -- faceCodimension
debug GroebnerWalk
R = QQ[x,y,z]
assert(faceCodimension matrix {{y^2-x*z, x*y, x^2}} == 1)
assert(faceCodimension matrix {{y^2-x*z, x*y-z, x^2}} == 2)
assert(faceCodimension matrix {{y^2-x*z, x*y-z, x^2-y}} == 2)
assert(faceCodimension matrix {{x^2*y^2 - x*y^2 + y^2, x^3 - x^2}} == 1)
///

TEST /// -- standardWalk, standardStep, and nextW
debug GroebnerWalk
R1 = QQ[x,y,z, MonomialOrder=>Weights=>{1,1,10}]
I1 = ideal(y^2-x, z^3-x)
R2 = QQ[x,y,z, MonomialOrder=>Weights=>{10,1,1}]

w = weightVector R1
wt = weightVector R2
G = gb I1

w = nextW(G, w, wt)
assert(w == {2,1,9})
R = newRing(R1, MonomialOrder=>{Weights=>w, Weights=>wt})
G = standardStep(G, R)
assert(gens G == matrix {{x-y^2, z^3-y^2}})

w = nextW(G, w, wt)
assert(w == {10,1,1})
R = newRing(R1, MonomialOrder=>{Weights=>w, Weights=>wt})
G = standardStep(G, R)
assert(gens G == matrix {{z^3-y^2, x-y^2}})

assert(gens groebnerWalk(I1, R2) == gens gb sub(I1, R2))
///

TEST /// -- genericWalk, genericStep, and nextV
debug GroebnerWalk
R1 = QQ[x,y,z, MonomialOrder=>Weights=>{1,1,10}]
I1 = ideal(y^2-x, z^3-x)
R2 = QQ[x,y,z, MonomialOrder=>Weights=>{10,1,1}]

S = weightVectors R1
T = weightVectors R2
G = gb I1

v = nextV(G, {}, S, T)
assert(v == {-1,2,0})
G = genericStep(G, v, R2)
use R1
assert(gens G == matrix {{z^3-y^2, y^2-x}})

assert(gens groebnerWalk(I1, R2, Strategy => Generic) == gens gb sub(I1, R2))
///

TEST /// -- setWalkTrace and getWalkTrace
assert(getWalkTrace() == 0)
setWalkTrace 2
assert(getWalkTrace() == 2)
///

TEST /// -- groebnerWalk
R1 = QQ[x,y,z, MonomialOrder=>Weights=>{1,1,10}]
I1 = ideal(y^2-x, z^3-x)
R2 = QQ[x,y,z, MonomialOrder=>Weights=>{10,1,1}]
G1 = groebnerWalk(I1, R2)
G2 = groebnerWalk(I1, R2, Strategy=>Generic)
G3 = gb sub(I1, R2)
assert(gens G1 == gens G3)
assert(gens G2 == gens G3)

R1 = ZZ/32003[x,y,z, MonomialOrder=>Weights=>{1,1,10}]
I1 = ideal(y^2-x, z^3-x)
R2 = ZZ/32003[x,y,z, MonomialOrder=>Weights=>{10,1,1}]
G1 = groebnerWalk(I1, R2)
G2 = groebnerWalk(I1, R2, Strategy=>Generic)
G3 = gb sub(I1, R2)
assert(gens G1 == gens G3)
assert(gens G2 == gens G3)

R1 = ZZ/32003[x,y,z, MonomialOrder=>Weights=>{1,100,1}]
I1 = ideal(y^2-x, z^3-x)
R2 = ZZ/32003[x,y,z, MonomialOrder=>Lex]
G1 = groebnerWalk(I1, R2)
G2 = groebnerWalk(I1, R2, Strategy=>Generic)
G3 = gb sub(I1, R2)
assert(gens G1 == gens G3)
assert(gens G2 == gens G3)

R1 = QQ[x,y,z,u,v, MonomialOrder=>Weights=>{1,1,1,0,0}]
I1 = ideal(u + u^2 - 2*v - 2*u^2*v + 2*u*v^2 - x,
           -6*u + 2*v + v^2 - 5*v^3 + 2*u*v^2 - 4*u^2*v^2 - y,
	   -2 + 2*u^2 + 6*v - 3*u^2*v^2 - z)
R2 = QQ[x,y,z,u,v, MonomialOrder=>Weights=>{0,0,0,1,1}]
G1 = groebnerWalk(I1, R2)
G2 = groebnerWalk(I1, R2, Strategy => Generic)
G3 = gb sub(I1, R2)
assert(gens G1 == gens G3)
assert(gens G2 == gens G3)
///

end