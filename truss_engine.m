function result = truss_engine(model)
%TRUSS_ENGINE Solve a linear-elastic 2-D pin-jointed truss.
%
% MODEL contains node coordinates, member connectivity, nodal forces,
% supports, Young's modulus E, and cross-sectional area A. The returned
% structure contains nodal displacements, axial member forces, and reactions.
%
% Positive member force denotes tension; negative denotes compression.

%% Initialize output and validate the model

result = struct( ...
    'success', false, ...
    'error', "", ...
    'memberForces', [], ...
    'U', [], ...
    'reactions', []);

[ok, message, data] = validate_model(model);
if ~ok
    result.error = message;
    return
end

nodes = data.nodes;
members = data.members;
forces = data.forces;
supports = data.supports;
nNodes = size(nodes, 1);
nDof = 2*nNodes;

%% Assemble the global stiffness matrix and load vector

K = zeros(nDof);
for i = 1:size(members, 1)
    [ke, dof] = member_stiffness(nodes, members(i,:), data.E, data.A);
    K(dof,dof) = K(dof,dof) + ke;
end

F = zeros(nDof, 1);
for i = 1:size(forces, 1)
    node = forces(i,1);
    F(2*node-1:2*node) = F(2*node-1:2*node) + forces(i,2:3).';
end

if any(~isfinite(K), 'all') || any(~isfinite(F))
    result.error = "Numerical overflow during stiffness or load assembly.";
    return
end

%% Apply support restraints

% fixedMask maps each support type to its restrained global degrees of
% freedom. Odd degree numbers are X; even degree numbers are Y.
fixedMask = false(nDof, 1);
for i = 1:size(supports, 1)
    node = supports(i,1);
    switch supports(i,2)
        case 1
            fixedMask(2*node-1:2*node) = true;
        case 2
            fixedMask(2*node-1) = true;
        case 3
            fixedMask(2*node) = true;
    end
end

fixed = find(fixedMask);
free = find(~fixedMask);
if isempty(fixed)
    result.error = "Add supports before solving.";
    return
end
if isempty(free)
    result.error = "No free degrees of freedom; the structure is fully restrained.";
    return
end

%% Solve the free degrees of freedom

Kff = K(free,free);
if rcond(Kff) < 1e-12
    result.error = "Singular stiffness matrix; check supports and member connectivity.";
    return
end

U = zeros(nDof, 1);
U(free) = Kff \ F(free);
if any(~isfinite(U))
    result.error = "Numerical overflow while solving displacements.";
    return
end

%% Recover member forces and support reactions

memberForces = zeros(size(members,1), 1);
for i = 1:size(members,1)
    n1 = members(i,1);
    n2 = members(i,2);
    delta = nodes(n2,:) - nodes(n1,:);
    lengthMember = hypot(delta(1), delta(2));
    direction = delta/lengthMember;
    dof = [2*n1-1, 2*n1, 2*n2-1, 2*n2];
    memberForces(i) = (data.E*data.A/lengthMember) * ...
        [-direction, direction] * U(dof);
end

reactionVector = K*U - F;
if any(~isfinite(memberForces)) || any(~isfinite(reactionVector))
    result.error = "Numerical overflow while computing member forces or reactions.";
    return
end
reactions = zeros(numel(fixed), 3);
for i = 1:numel(fixed)
    dof = fixed(i);
    % Reaction rows contain node, direction (1=X or 2=Y), and force.
    reactions(i,:) = [ceil(dof/2), 2-mod(dof,2), reactionVector(dof)];
end

%% Publish a successful result

result.success = true;
result.memberForces = memberForces;
result.U = U;
result.reactions = reactions;
end

function [ok, message, data] = validate_model(model)
%VALIDATE_MODEL Check the fields and array shapes used by the solver.

ok = false;
message = "";
data = struct();

required = {'nodes','members','forces','supports','E','A'};
if ~isstruct(model) || ~all(isfield(model, required))
    message = "Model must define nodes, members, forces, supports, E, and A.";
    return
end
if isfield(model,'unknownForces') && ~isempty(model.unknownForces)
    message = "Unknown force magnitudes require prescribed displacement constraints and are not supported.";
    return
end

data.nodes = model.nodes;
data.members = model.members;
data.forces = model.forces;
data.supports = model.supports;
data.E = model.E;
data.A = model.A;

if ~isnumeric(data.nodes) || size(data.nodes,2) ~= 2 || isempty(data.nodes) || ...
        any(~isfinite(data.nodes), 'all')
    message = "Nodes must be a finite N-by-2 numeric array.";
    return
end
if ~isnumeric(data.members) || size(data.members,2) ~= 2 || isempty(data.members) || ...
        any(~isfinite(data.members), 'all')
    message = "Members must be a finite M-by-2 numeric array.";
    return
end
if ~isempty(data.forces) && (~isnumeric(data.forces) || size(data.forces,2) ~= 3 || ...
        any(~isfinite(data.forces), 'all'))
    message = "Forces must be a finite N-by-3 numeric array.";
    return
end
if ~isempty(data.supports) && (~isnumeric(data.supports) || size(data.supports,2) ~= 2 || ...
        any(~isfinite(data.supports), 'all'))
    message = "Supports must be a finite N-by-2 numeric array.";
    return
end
if ~isscalar(data.E) || ~isfinite(data.E) || data.E <= 0 || ...
        ~isscalar(data.A) || ~isfinite(data.A) || data.A <= 0
    message = "E and A must be positive finite scalars.";
    return
end

nNodes = size(data.nodes,1);
if any(data.members ~= round(data.members), 'all') || ...
        any(data.members < 1, 'all') || any(data.members > nNodes, 'all')
    message = "Member node indices must be integers that reference existing nodes.";
    return
end
if any(data.members(:,1) == data.members(:,2))
    message = "A member cannot connect a node to itself.";
    return
end
memberLengths = hypot( ...
    data.nodes(data.members(:,2),1)-data.nodes(data.members(:,1),1), ...
    data.nodes(data.members(:,2),2)-data.nodes(data.members(:,1),2));
if any(memberLengths <= 1e-12)
    message = "Zero-length members are not allowed.";
    return
end

if ~isempty(data.forces) && (any(data.forces(:,1) ~= round(data.forces(:,1))) || ...
        any(data.forces(:,1) < 1) || any(data.forces(:,1) > nNodes))
    message = "Force node indices must reference existing nodes.";
    return
end
if ~isempty(data.supports) && (any(data.supports(:,1) ~= round(data.supports(:,1))) || ...
        any(data.supports(:,1) < 1) || any(data.supports(:,1) > nNodes) || ...
        any(data.supports(:,2) ~= round(data.supports(:,2))) || ...
        any(~ismember(data.supports(:,2), 1:3)))
    message = "Supports must reference existing nodes and use type 1, 2, or 3.";
    return
end

ok = true;
end

function [ke, dof] = member_stiffness(nodes, member, E, A)
%MEMBER_STIFFNESS Return one bar's global stiffness matrix and DOF indices.

n1 = member(1);
n2 = member(2);
delta = nodes(n2,:) - nodes(n1,:);
lengthMember = hypot(delta(1), delta(2));
c = delta(1)/lengthMember;
s = delta(2)/lengthMember;
ke = (E*A/lengthMember) * [ ...
     c^2,  c*s, -c^2, -c*s; ...
     c*s,  s^2, -c*s, -s^2; ...
    -c^2, -c*s,  c^2,  c*s; ...
    -c*s, -s^2,  c*s,  s^2];
dof = [2*n1-1, 2*n1, 2*n2-1, 2*n2];
end
