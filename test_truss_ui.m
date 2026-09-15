function tests = test_truss_ui
%TEST_TRUSS_UI Regression tests for UI callbacks and preset definitions.

tests = functiontests(localfunctions);
end

function setup(testCase)
existing = findall(groot,'Type','figure');
truss_ui;
created = setdiff(findall(groot,'Type','figure'),existing);
testCase.TestData.fig = created(1);
end

function teardown(testCase)
delete(testCase.TestData.fig);
end

function testFirstSupportAfterStartupAndClear(testCase)
fig = testCase.TestData.fig;
for attempt = 1:2
    nodesTab = findall(fig,'Type','uitab','Title','  Nodes  ');
    addNode = findall(nodesTab,'Text','+ Add');
    addNode.ButtonPushedFcn(addNode,[]);
    addSupport = findall(fig,'Text','+ Add Support');
    addSupport.ButtonPushedFcn(addSupport,[]);
    supports = table_with_columns(fig,{'Node';'Type'});
    verifyEqual(testCase,size(supports.Data,1),1);
    verifyEqual(testCase,supports.Data{1,1},1);
    clearButton = findall(fig,'Text','Clear All');
    clearButton.ButtonPushedFcn(clearButton,[]);
end
end

function testInvalidEndpointPreservesModel(testCase)
fig = testCase.TestData.fig;
select_preset(fig,'Simple Triangle');
members = table_with_columns(fig,{'ID';'Node 1';'Node 2'});
original = members.Data;
for value = {NaN,Inf,-Inf,'bad',[],[1 2],1i}
    event = struct('Indices',[1 2],'NewData',value{1}, ...
        'PreviousData',original{1,2});
    members.CellEditCallback(members,event);
    verifyEqual(testCase,members.Data,original);
end
solve_model(fig);
results = table_with_columns(fig,{'Mbr';'Force (N)';'State'});
verifyEqual(testCase,size(results.Data,1),3);
verifyEqual(testCase,results.Data{1,2},5773.7,'RelTol',1e-4);
end

function testNamedDiagonalForces(testCase)
fig = testCase.TestData.fig;
for name = {'Pratt Truss (6-panel)','Howe Truss (6-panel)'}
    select_preset(fig,name{1});
    solve_model(fig);
    results = table_with_columns(fig,{'Mbr';'Force (N)';'State'});
    verifyEqual(testCase,size(results.Data,1),25);
    diagonals = cell2mat(results.Data(20:25,2));
    if startsWith(name{1},'Pratt')
        verifyGreaterThan(testCase,diagonals,0);
    else
        verifyLessThan(testCase,diagonals,0);
    end
end
end

function select_preset(fig,name)
dropdowns = findall(fig,'Type','uidropdown');
for dropdown = dropdowns.'
    if any(strcmp(dropdown.Items,name))
        dropdown.Value = name;
        dropdown.ValueChangedFcn(dropdown,struct('Value',name));
        return
    end
end
error('Preset not found.');
end

function solve_model(fig)
buttons = findall(fig,'Type','uibutton');
button = buttons(contains(string({buttons.Text}),'SOLVE'));
button.ButtonPushedFcn(button,[]);
end

function tbl = table_with_columns(fig,columns)
tables = findall(fig,'Type','uitable');
for tbl = tables.'
    if isequal(tbl.ColumnName,columns), return; end
end
error('Table not found.');
end
