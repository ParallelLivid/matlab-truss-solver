function tests = test_truss_engine
%TEST_TRUSS_ENGINE Regression tests for the numerical solver.

tests = functiontests(localfunctions);
end

function testSingleBar(testCase)
model = base_model();
model.nodes = [0 0; 2 0];
model.members = [1 2];
model.forces = [2 1000 0];
model.supports = [1 1; 2 3];

result = truss_engine(model);

verifyTrue(testCase, result.success, char(result.error));
verifyEqual(testCase, result.memberForces, 1000, 'AbsTol', 1e-8);
verifyEqual(testCase, result.U(3), 1e-6, 'AbsTol', 1e-12);
verifyEqual(testCase, sum(result.reactions(:,3)), -1000, 'AbsTol', 1e-8);
end

function testTriangleEquilibrium(testCase)
model = base_model();
model.nodes = [0 0; 4 0; 2 3.464];
model.members = [1 2; 2 3; 1 3];
model.forces = [3 0 -20000];
model.supports = [1 1; 2 3];

result = truss_engine(model);

verifyTrue(testCase, result.success, char(result.error));
verifyEqual(testCase, result.memberForces(1), 5773.7, 'RelTol', 1e-4);
verifyEqual(testCase, result.memberForces(2:3), [-11547.1; -11547.1], 'RelTol', 1e-4);
horizontalReaction = sum(result.reactions(result.reactions(:,2)==1,3));
verticalReaction = sum(result.reactions(result.reactions(:,2)==2,3));
verifyEqual(testCase, horizontalReaction, 0, 'AbsTol', 1e-7);
verifyEqual(testCase, verticalReaction, 20000, 'AbsTol', 1e-7);
end

function testMechanismIsRejected(testCase)
model = base_model();
model.nodes = [0 0; 1 0; 2 0];
model.members = [1 2; 2 3];
model.forces = [3 0 -1];
model.supports = [1 1; 3 3];

result = truss_engine(model);

verifyFalse(testCase, result.success);
verifyThat(testCase, result.error, matlab.unittest.constraints.ContainsSubstring("Singular"));
end

function testZeroLengthMemberIsRejected(testCase)
model = base_model();
model.nodes = [0 0; 0 0];
model.members = [1 2];
model.supports = [1 1];

result = truss_engine(model);

verifyFalse(testCase, result.success);
verifyThat(testCase, result.error, matlab.unittest.constraints.ContainsSubstring("Zero-length"));
end

function testUnsupportedUnknownForceIsRejected(testCase)
model = base_model();
model.nodes = [0 0; 1 0];
model.members = [1 2];
model.supports = [1 1; 2 3];
model.unknownForces = [2 1];

result = truss_engine(model);

verifyFalse(testCase, result.success);
verifyThat(testCase, result.error, matlab.unittest.constraints.ContainsSubstring("prescribed displacement"));
end

function testOverflowIsRejected(testCase)
model = base_model();
model.nodes = [0 0; 2 0];
model.members = [1 2];
model.supports = [1 1; 2 3];
model.forces = [2 1e308 0; 2 1e308 0];
verify_numerical_failure(testCase, truss_engine(model));

model.forces = [2 1000 0];
model.E = realmax;
model.A = 2;
verify_numerical_failure(testCase, truss_engine(model));

model.E = 1e-200;
model.A = 1;
model.forces = [2 1e200 0];
verify_numerical_failure(testCase, truss_engine(model));
end

function verify_numerical_failure(testCase, result)
verifyFalse(testCase, result.success);
verifyTrue(testCase, contains(result.error, "Numerical overflow"));
verifyEmpty(testCase, result.U);
verifyEmpty(testCase, result.memberForces);
verifyEmpty(testCase, result.reactions);
end

function model = base_model()
model = struct('nodes',[],'members',[],'forces',[],'supports',[], ...
    'E',200e9,'A',0.01);
end
