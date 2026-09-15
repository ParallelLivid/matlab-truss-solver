function truss_ui()
%TRUSS_UI  Interactive 2-D truss solver — graphical front-end.
%
%   Run:  truss_ui
%
%   Requires truss_engine.m on the MATLAB path (same folder is fine).
%
%   Sign convention (truss_engine):
%     Positive member force  →  Tension      (member elongates)
%     Negative member force  →  Compression  (member shortens)
%
%   Support types:
%     1 – Pin       (X and Y fixed)
%     2 – Roller-X  (only X fixed)
%     3 – Roller-Y  (only Y fixed)

%% Shared state

model  = make_model();
result = empty_result();

%% Layout constants

FW   = 1340;  FH   = 840;
TBH  = 58;    SBH  = 32;      % toolbar height, status-bar height
LW   = 326;   RW   = 298;     % left panel, right panel widths
CW   = FW - LW - RW;          % canvas width
% The tab strip occupies about 26 pixels of the tab group's height.
TH   = FH - TBH - SBH - 10;   % tab group outer height
TCH  = TH - 26;                % tab content height (subtract tab strip)

%% Colour palette

BG   = [0.10 0.11 0.15];
PNL  = [0.15 0.16 0.21];
TLB  = [0.18 0.19 0.26];
BLU  = [0.22 0.57 0.92];
GRN  = [0.17 0.70 0.43];
RED  = [0.83 0.24 0.24];
AMB  = [0.95 0.65 0.14];
TXT  = [0.93 0.94 0.96];
STXT = [0.57 0.60 0.67];
TRED = [0.93 0.22 0.22];
TBLU = [0.24 0.53 0.96];
GRNG = [0.35 0.88 0.50];
DIVC = [0.22 0.24 0.32];      % divider colour

%% Input-panel geometry

P    = 10;    % standard padding
LBH  = 18;   % label height
FLH  = 28;   % field / button height
TW   = LW - 16;  % table width inside tab (4px margin each side + 4 border)
DBTM = 38;   % table bottom clearance (above delete button)

% Vertical positions for tabs with one input row.
SEC1Y = TCH - P - LBH;           % section header row (1 input row tabs)
INP1Y = SEC1Y - P - FLH;         % input field row 1
DIV1Y = INP1Y - P - 2;           % divider line (1-row input)
TH1   = DIV1Y - P - DBTM;        % table height (1-row input tabs)

% Vertical positions for tabs with two input rows.
SEC2Y = TCH - P - LBH;
INP2Y = SEC2Y - P - FLH;         % input field row 1
INP3Y = INP2Y - P - FLH;         % input field row 2
DIV2Y = INP3Y - P - 2;           % divider line (2-row input)
TH2t  = DIV2Y - P - DBTM;        % table height (2-row input tabs)

%% Main window

fig = uifigure('Name','2-D Truss Solver', ...
    'Position',[60 40 FW FH],'Color',BG,'Resize','off');

%% Toolbar

tb = uipanel(fig,'Position',[0 FH-TBH FW TBH], ...
    'BackgroundColor',TLB,'BorderType','none');

xl = 12;
tb_label(tb,'Preset:',xl,20,46);  xl = xl + 48;
presetDD = uidropdown(tb, ...
    'Items',{'— Custom —','Simple Triangle', ...
             'Pratt Truss (6-panel)','Warren Truss (6-panel)', ...
             'Howe Truss (6-panel)','Cantilever Truss','Roof Truss (Fink)'}, ...
    'Position',[xl 16 196 28],'ValueChangedFcn',@cb_preset);
xl = xl + 204;

uipanel(tb,'Position',[xl 10 1 38],'BackgroundColor',DIVC,'BorderType','none');
xl = xl + 10;

uibutton(tb,'Text','▶  SOLVE', ...
    'Position',[xl 16 116 28],'BackgroundColor',GRN, ...
    'FontColor','white','FontWeight','bold','FontSize',13, ...
    'ButtonPushedFcn',@cb_solve);
xl = xl + 124;

uibutton(tb,'Text','Clear All', ...
    'Position',[xl 16 86 28],'BackgroundColor',RED, ...
    'FontColor','white','FontWeight','bold','FontSize',11, ...
    'ButtonPushedFcn',@cb_clear);
xl = xl + 96;

uipanel(tb,'Position',[xl 10 1 38],'BackgroundColor',DIVC,'BorderType','none');
xl = xl + 12;

showLbl = uicheckbox(tb,'Text','  Node IDs','Value',true, ...
    'Position',[xl 19 98 22],'FontColor',TXT,'FontSize',11, ...
    'ValueChangedFcn',@(~,~) redraw());
xl = xl + 104;

showMag = uicheckbox(tb,'Text','  Force Values','Value',false, ...
    'Position',[xl 19 122 22],'FontColor',TXT,'FontSize',11, ...
    'ValueChangedFcn',@(~,~) redraw());

%% Input tabs

lp = uipanel(fig,'Position',[0 SBH LW FH-TBH-SBH], ...
    'BackgroundColor',PNL,'BorderType','none');
tg = uitabgroup(lp,'Position',[4 4 LW-8 TH]);

% Nodes tab

tNd = uitab(tg,'Title','  Nodes  ','BackgroundColor',PNL);

sec_label(tNd,'ADD NODE',4,SEC1Y,TW);
tb_label(tNd,'X (m):',4,INP1Y+5,44);
nxE = uieditfield(tNd,'numeric','Value',0, ...
    'Position',[50 INP1Y 70 FLH]);
tb_label(tNd,'Y (m):',128,INP1Y+5,44);
nyE = uieditfield(tNd,'numeric','Value',0, ...
    'Position',[174 INP1Y 70 FLH]);
uibutton(tNd,'Text','+ Add','Position',[250 INP1Y 60 FLH], ...
    'BackgroundColor',BLU,'FontColor','white','FontWeight','bold', ...
    'ButtonPushedFcn',@(~,~) add_node());
divider(tNd,4,DIV1Y,TW);

nodeTbl = uitable(tNd,'ColumnName',{'ID','X (m)','Y (m)'}, ...
    'ColumnWidth',{40,132,132},'ColumnEditable',[false true true], ...
    'Position',[4 DBTM TW TH1],'RowName',{},'FontSize',11, ...
    'CellEditCallback',@cb_nd_edit);

uibutton(tNd,'Text','⊖  Delete Selected','Position',[4 6 148 26], ...
    'BackgroundColor',[0.25 0.14 0.14],'FontColor',[1 0.6 0.6],'FontSize',10.5, ...
    'ButtonPushedFcn',@(~,~) del_row('node'));

% Members tab

tMb = uitab(tg,'Title','  Members  ','BackgroundColor',PNL);

sec_label(tMb,'ADD MEMBER',4,SEC1Y,TW);
tb_label(tMb,'Node 1:',4,INP1Y+5,52);
m1E = uieditfield(tMb,'numeric','Value',1,'Position',[58 INP1Y 60 FLH], ...
    'Limits',[1 Inf]);
tb_label(tMb,'Node 2:',126,INP1Y+5,52);
m2E = uieditfield(tMb,'numeric','Value',2,'Position',[180 INP1Y 60 FLH], ...
    'Limits',[1 Inf]);
uibutton(tMb,'Text','+ Add','Position',[250 INP1Y 60 FLH], ...
    'BackgroundColor',BLU,'FontColor','white','FontWeight','bold', ...
    'ButtonPushedFcn',@(~,~) add_member());
divider(tMb,4,DIV1Y,TW);

memTbl = uitable(tMb,'ColumnName',{'ID','Node 1','Node 2'}, ...
    'ColumnWidth',{54,124,124},'ColumnEditable',[false true true], ...
    'Position',[4 DBTM TW TH1],'RowName',{},'FontSize',11, ...
    'CellEditCallback',@cb_mb_edit);

uibutton(tMb,'Text','⊖  Delete Selected','Position',[4 6 148 26], ...
    'BackgroundColor',[0.25 0.14 0.14],'FontColor',[1 0.6 0.6],'FontSize',10.5, ...
    'ButtonPushedFcn',@(~,~) del_row('member'));

% Forces tab

tFc = uitab(tg,'Title','  Forces  ','BackgroundColor',PNL);

sec_label(tFc,'ADD FORCE',4,SEC2Y,TW);
tb_label(tFc,'Node:',4,INP2Y+5,40);
fnE = uieditfield(tFc,'numeric','Value',1,'Position',[46 INP2Y 46 FLH], ...
    'Limits',[1 Inf]);
tb_label(tFc,'Fx (N):',100,INP2Y+5,50);
fxE = uieditfield(tFc,'numeric','Value',0,'Position',[152 INP2Y 86 FLH]);
tb_label(tFc,'Fy (N):',4,INP3Y+5,50);
fyE = uieditfield(tFc,'numeric','Value',-10000,'Position',[56 INP3Y 86 FLH]);
uibutton(tFc,'Text','+ Add','Position',[152 INP3Y 86 FLH], ...
    'BackgroundColor',BLU,'FontColor','white','FontWeight','bold', ...
    'ButtonPushedFcn',@(~,~) add_force());
divider(tFc,4,DIV2Y,TW);

fceTbl = uitable(tFc,'ColumnName',{'Node','Fx (N)','Fy (N)'}, ...
    'ColumnWidth',{52,126,126},'ColumnEditable',[false true true], ...
    'Position',[4 DBTM TW TH2t],'RowName',{},'FontSize',11, ...
    'CellEditCallback',@cb_fc_edit);

uibutton(tFc,'Text','⊖  Delete Selected','Position',[4 6 148 26], ...
    'BackgroundColor',[0.25 0.14 0.14],'FontColor',[1 0.6 0.6],'FontSize',10.5, ...
    'ButtonPushedFcn',@(~,~) del_row('force'));

% Supports tab

tSp = uitab(tg,'Title','  Supports  ','BackgroundColor',PNL);

sec_label(tSp,'ADD SUPPORT',4,SEC2Y,TW);
tb_label(tSp,'Node:',4,INP2Y+5,40);
spnE = uieditfield(tSp,'numeric','Value',1,'Position',[46 INP2Y 46 FLH], ...
    'Limits',[1 Inf]);
tb_label(tSp,'Type:',100,INP2Y+5,38);
spDD = uidropdown(tSp, ...
    'Items',{'Pin  (X + Y fixed)','Roller – X fixed','Roller – Y fixed'}, ...
    'Position',[140 INP2Y 168 FLH]);
uibutton(tSp,'Text','+ Add Support','Position',[4 INP3Y 148 FLH], ...
    'BackgroundColor',BLU,'FontColor','white','FontWeight','bold', ...
    'ButtonPushedFcn',@(~,~) add_support());
divider(tSp,4,DIV2Y,TW);

supTbl = uitable(tSp,'ColumnName',{'Node','Type'}, ...
    'ColumnWidth',{52,240},'ColumnEditable',[false false], ...
    'Position',[4 DBTM TW TH2t],'RowName',{},'FontSize',11);

uibutton(tSp,'Text','⊖  Delete Selected','Position',[4 6 148 26], ...
    'BackgroundColor',[0.25 0.14 0.14],'FontColor',[1 0.6 0.6],'FontSize',10.5, ...
    'ButtonPushedFcn',@(~,~) del_row('support'));

%% Truss canvas

ax = uiaxes(fig,'Position',[LW SBH CW FH-TBH-SBH], ...
    'Color',[0.06 0.07 0.10], ...
    'XColor',STXT,'YColor',STXT, ...
    'GridColor',[0.20 0.23 0.30],'GridAlpha',0.50, ...
    'XGrid','on','YGrid','on', ...
    'FontSize',10,'DataAspectRatio',[1 1 1]);
hold(ax,'on');  box(ax,'on');

%% Results panel

RPH = FH - TBH - SBH;    % full height of results panel
rp  = uipanel(fig,'Position',[LW+CW SBH RW RPH], ...
    'BackgroundColor',PNL,'BorderType','none');

uilabel(rp,'Text','RESULTS', ...
    'Position',[6 RPH-40 RW-12 30], ...
    'FontColor',TXT,'FontSize',14,'FontWeight','bold', ...
    'HorizontalAlignment','center');

resLbl = uilabel(rp,'Text','Press  ▶ SOLVE  to analyse.', ...
    'Position',[6 RPH-72 RW-12 28], ...
    'FontColor',STXT,'FontSize',10.5, ...
    'HorizontalAlignment','center','WordWrap','on');

divider(rp,6,RPH-80,RW-12);

uilabel(rp,'Text','Member Forces', ...
    'Position',[6 RPH-106 RW-12 20], ...
    'FontColor',STXT,'FontSize',10,'FontWeight','bold');

mfTbl = uitable(rp,'ColumnName',{'Mbr','Force (N)','State'}, ...
    'ColumnWidth',{44,108,98},'ColumnEditable',[false false false], ...
    'Position',[4 196 RW-8 RPH-308],'RowName',{},'FontSize',10.5);

divider(rp,6,184,RW-12);

uilabel(rp,'Text','Reaction Forces', ...
    'Position',[6 162 RW-12 20], ...
    'FontColor',STXT,'FontSize',10,'FontWeight','bold');

rxTbl = uitable(rp,'ColumnName',{'Node','DOF','Reaction (N)'}, ...
    'ColumnWidth',{50,50,168},'ColumnEditable',[false false false], ...
    'Position',[4 4 RW-8 154],'RowName',{},'FontSize',10.5);

%% Status bar

sb    = uipanel(fig,'Position',[0 0 FW SBH], ...
    'BackgroundColor',TLB,'BorderType','none');
sbLbl = uilabel(sb,'Text', ...
    'Ready – load a preset or enter nodes and members manually.', ...
    'Position',[10 7 FW-20 20],'FontColor',STXT,'FontSize',11);

% Visit each tab once so its controls render before user interaction.
tg.SelectedTab = tMb; drawnow;
tg.SelectedTab = tFc; drawnow;
tg.SelectedTab = tSp; drawnow;
tg.SelectedTab = tNd; drawnow;

%% Initial display

refresh_tables();
redraw();

%% Callback functions

    function cb_solve(~,~)
        clear_results();
        setstatus('Solving…');  drawnow;
        try
            result = truss_engine(model);
            if result.success
                setstatus(sprintf( ...
                    'Solved  –  %d nodes  |  %d members  |  %d DOFs', ...
                    size(model.nodes,1), size(model.members,1), ...
                    2*size(model.nodes,1)));
                update_results();
            else
                msg = char(result.error);
                setstatus(['Error: ' msg]);
                resLbl.Text      = msg;
                resLbl.FontColor = RED;
            end
        catch ME
            setstatus(['Exception: ' ME.message]);
            resLbl.Text      = ME.message;
            resLbl.FontColor = RED;
        end
        redraw();
    end

    function cb_clear(~,~)
        model  = make_model();
        result = empty_result();
        presetDD.Value = '— Custom —';
        refresh_tables();
        redraw();
        clear_results();
        setstatus('Cleared.');
    end

    function cb_preset(~, ev)
        nm = ev.Value;
        if strcmp(nm,'— Custom —'), return; end
        model  = load_preset(nm);
        result = empty_result();
        refresh_tables();
        redraw();
        clear_results();
        setstatus(sprintf('Preset "%s" loaded – press  ▶ SOLVE  to analyse.', nm));
    end

    % Add-item callbacks

    function add_node()
        invalidate_results();
        model.nodes(end+1,:) = [nxE.Value, nyE.Value];
        refresh_tables();  redraw();
        n = size(model.nodes,1);
        setstatus(sprintf('Node %d added at (%.4g, %.4g) m.', ...
            n, nxE.Value, nyE.Value));
    end

    function add_member()
        n1 = round(m1E.Value);  n2 = round(m2E.Value);
        N  = size(model.nodes,1);
        if n1<1 || n2<1 || n1>N || n2>N
            setstatus('Error: member node index out of range.');  return
        end
        if n1 == n2
            setstatus('Error: member node indices must differ.');  return
        end
        invalidate_results();
        model.members(end+1,:) = [n1, n2];
        refresh_tables();  redraw();
        setstatus(sprintf('Member %d added: %d → %d.', ...
            size(model.members,1), n1, n2));
    end

    function add_force()
        nd = round(fnE.Value);
        N  = size(model.nodes,1);
        if nd<1 || nd>N
            setstatus('Error: force node index out of range.');  return
        end
        invalidate_results();
        model.forces(end+1,:) = [nd, fxE.Value, fyE.Value];
        refresh_tables();  redraw();
        setstatus(sprintf('Force added at node %d: Fx=%.4g N, Fy=%.4g N.', ...
            nd, fxE.Value, fyE.Value));
    end

    function add_support()
        nd = round(spnE.Value);
        N  = size(model.nodes,1);
        if nd<1 || nd>N
            setstatus('Error: support node index out of range.');  return
        end
        switch spDD.Value
            case 'Pin  (X + Y fixed)', t = 1;
            case 'Roller – X fixed',   t = 2;
            otherwise,                 t = 3;
        end
        invalidate_results();
        model.supports(model.supports(:,1)==nd,:) = [];
        model.supports(end+1,:) = [nd, t];
        refresh_tables();  redraw();
        setstatus(sprintf('Support added at node %d (%s).', nd, spDD.Value));
    end

    % Table-edit callbacks

    function cb_nd_edit(~, ev)
        invalidate_results();
        r = ev.Indices(1);  c = ev.Indices(2);
        if c == 2, model.nodes(r,1) = ev.NewData; end
        if c == 3, model.nodes(r,2) = ev.NewData; end
        redraw();
    end

    function cb_mb_edit(src, ev)
        r = ev.Indices(1);  c = ev.Indices(2);
        if ~isnumeric(ev.NewData) || ~isreal(ev.NewData) || ...
                ~isscalar(ev.NewData) || ~isfinite(ev.NewData)
            src.Data{r,c} = ev.PreviousData;
            setstatus('Error: member node index must be a finite number.');
            return
        end
        v = round(ev.NewData);
        N = size(model.nodes,1);
        if v<1 || v>N
            src.Data{r,c} = ev.PreviousData;  return
        end
        otherMemberColumn = 3-(c-1);
        if v == model.members(r,otherMemberColumn)
            src.Data{r,c} = ev.PreviousData;
            setstatus('Error: member node indices must differ.');
            return
        end
        invalidate_results();
        if c == 2, model.members(r,1) = v; end
        if c == 3, model.members(r,2) = v; end
        redraw();
    end

    function cb_fc_edit(~, ev)
        invalidate_results();
        r = ev.Indices(1);  c = ev.Indices(2);
        if c == 2, model.forces(r,2) = ev.NewData; end
        if c == 3, model.forces(r,3) = ev.NewData; end
        redraw();
    end

    % Delete selected rows and dependent model entries.

    function del_row(kind)
        switch kind
            case 'node',    tbl = nodeTbl;
            case 'member',  tbl = memTbl;
            case 'force',   tbl = fceTbl;
            case 'support', tbl = supTbl;
        end
        sel = tbl.Selection;
        if isempty(sel)
            setstatus('Click a row in the table to select it, then press Delete.');
            return
        end
        rows = sort(unique(sel(:,1)), 'descend');
        invalidate_results();
        for k = 1:numel(rows)
            r = rows(k);
            switch kind
                case 'node'
                    model.nodes(r,:) = [];
                    if ~isempty(model.members)
                        bad = model.members(:,1)==r | model.members(:,2)==r;
                        model.members(bad,:) = [];
                        if ~isempty(model.members)
                            model.members(model.members>r) = ...
                                model.members(model.members>r) - 1;
                        end
                    end
                    if ~isempty(model.forces)
                        model.forces(model.forces(:,1)==r,:) = [];
                        if ~isempty(model.forces)
                            model.forces(model.forces(:,1)>r,1) = ...
                                model.forces(model.forces(:,1)>r,1) - 1;
                        end
                    end
                    if ~isempty(model.supports)
                        model.supports(model.supports(:,1)==r,:) = [];
                        if ~isempty(model.supports)
                            model.supports(model.supports(:,1)>r,1) = ...
                                model.supports(model.supports(:,1)>r,1) - 1;
                        end
                    end
                case 'member',  model.members(r,:)  = [];
                case 'force',   model.forces(r,:)   = [];
                case 'support', model.supports(r,:) = [];
            end
        end
        refresh_tables();
        redraw();
    end

%% UI state helpers

    function refresh_tables()
        N = size(model.nodes,1);
        if N > 0
            nd_ids = arrayfun(@node_label, (1:N)', 'UniformOutput', false);
            nodeTbl.Data = [nd_ids, num2cell(model.nodes)];
        else
            nodeTbl.Data = {};
        end

        M = size(model.members,1);
        if M > 0
            mb_names = arrayfun(@member_label, (1:M)', 'UniformOutput', false);
            memTbl.Data = [mb_names, num2cell(model.members)];
        else
            memTbl.Data = {};
        end

        if ~isempty(model.forces)
            fceTbl.Data = num2cell(model.forces);
        else
            fceTbl.Data = {};
        end

        tnm = {'Pin (X+Y)','Roller-X','Roller-Y'};
        if ~isempty(model.supports)
            sd = [num2cell(model.supports(:,1)), tnm(model.supports(:,2))'];
            supTbl.Data = sd;
        else
            supTbl.Data = {};
        end
    end

    function update_results()
        if ~result.success, return; end
        mf = result.memberForces;
        M  = size(model.members,1);

        dat = cell(M,3);
        for i = 1:M
            dat{i,1} = member_label(i);
            dat{i,2} = round(mf(i), 4);
            if     mf(i) >  1e-9, dat{i,3} = 'Tension';
            elseif mf(i) < -1e-9, dat{i,3} = 'Compression';
            else,                  dat{i,3} = 'Zero';
            end
        end
        mfTbl.Data = dat;

        tmax = max([0; mf(mf> 1e-9)]);
        cmax = abs(min([0; mf(mf<-1e-9)]));
        resLbl.Text = sprintf( ...
            'Max tension: %s\nMax compression: %s', ...
            fmt_force(tmax), fmt_force(cmax));
        resLbl.FontColor = GRN;

        rxn = result.reactions;
        rxns = cell(size(rxn,1),3);
        directions = {'X','Y'};
        for i = 1:size(rxn,1)
            rxns{i,1} = node_label(rxn(i,1));
            rxns{i,2} = directions{rxn(i,2)};
            rxns{i,3} = round(rxn(i,3),4);
        end
        rxTbl.Data = rxns;
    end

    function clear_results()
        mfTbl.Data  = {};
        rxTbl.Data  = {};
        resLbl.Text      = 'Press  ▶ SOLVE  to analyse.';
        resLbl.FontColor = STXT;
    end

    function invalidate_results()
        result = empty_result();
        presetDD.Value = '— Custom —';
        clear_results();
    end

    function setstatus(msg)
        sbLbl.Text = msg;
    end

%% Drawing functions

    function redraw()
        cla(ax);
        nd = model.nodes;
        if isempty(nd)
            title(ax,'No nodes – add nodes to begin.', ...
                'Color',STXT,'FontSize',11);
            return
        end

        NN    = size(nd,1);
        hasMF = result.success && ...
                (numel(result.memberForces) == size(model.members,1));

        % Set square axis limits from the node bounds before drawing.
        xlo = min(nd(:,1));  xhi = max(nd(:,1));
        ylo = min(nd(:,2));  yhi = max(nd(:,2));
        xrng = xhi - xlo;    yrng = yhi - ylo;
        span = max([xrng, yrng, 1.0]);
        pad  = 0.22 * span;
        xctr = (xlo + xhi) / 2;
        yctr = (ylo + yhi) / 2;
        half = span/2 + pad;
        xlim(ax, [xctr - half, xctr + half]);
        ylim(ax, [yctr - half, yctr + half]);

        symD = 0.046 * span;   % symbol size scaled to span

        % Draw members with result colors after a successful solve.
        for i = 1:size(model.members,1)
            n1=model.members(i,1); n2=model.members(i,2);
            if n1<1||n2<1||n1>NN||n2>NN, continue; end
            xv=[nd(n1,1) nd(n2,1)]; yv=[nd(n1,2) nd(n2,2)];
            if hasMF
                f = result.memberForces(i);
                if     f >  1e-9, col=TRED; lw=3.0;
                elseif f < -1e-9, col=TBLU; lw=3.0;
                else,             col=[0.58 0.61 0.68]; lw=1.8;
                end
            else
                col=[0.52 0.56 0.64]; lw=2.0;
            end
            plot(ax, xv, yv, '-','Color',col,'LineWidth',lw);

            % Member values are opt-in because labels overlap on dense trusses.
            mx=(xv(1)+xv(2))/2; my=(yv(1)+yv(2))/2;
            if hasMF && showMag.Value
                lbl = [member_label(i) '  ' fmt_force(result.memberForces(i))];
                text(ax, mx, my, lbl, ...
                    'Color',AMB,'FontSize',8.5,'FontWeight','bold', ...
                    'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                    'Interpreter','none');
            end
        end

        % Draw support symbols at their assigned nodes.
        for i = 1:size(model.supports,1)
            n = model.supports(i,1);  t = model.supports(i,2);
            if n<1||n>NN, continue; end
            draw_support(nd(n,1), nd(n,2), t, symD);
        end

        % Scale all load arrows from the largest applied component.
        if ~isempty(model.forces)
            fmax = max(abs(model.forces(:,2:3)),[],'all');
            if fmax < 1e-12, fmax = 1; end
            sc = 0.18 * span / fmax;
            for i = 1:size(model.forces,1)
                n = model.forces(i,1);
                if n<1||n>NN, continue; end
                fx=model.forces(i,2); fy=model.forces(i,3);
                if abs(fx)+abs(fy) < 1e-12, continue; end
                draw_arrow(nd(n,1), nd(n,2), fx, fy, sc);
            end
        end

        % Draw nodes last so they remain visible above other symbols.
        for i = 1:NN
            plot(ax, nd(i,1), nd(i,2), 'o', ...
                'MarkerSize',10, ...
                'MarkerFaceColor',[0.97 0.85 0.24], ...
                'MarkerEdgeColor',[0.12 0.12 0.12], ...
                'LineWidth',1.3);
            if showLbl.Value
                text(ax, nd(i,1), nd(i,2), ['  ' node_label(i)], ...
                    'Color',[0.97 0.85 0.24],'FontSize',10, ...
                    'FontWeight','bold','VerticalAlignment','bottom', ...
                    'Interpreter','none');
            end
        end

        % Label the canvas and summarize the current model.
        xlabel(ax,'x (m)','Color',STXT,'FontSize',11);
        ylabel(ax,'y (m)','Color',STXT,'FontSize',11);
        ttl = sprintf('%d nodes  |  %d members', NN, size(model.members,1));
        if hasMF
            ttl = [ttl '  |  solved   (Red = Tension,  Blue = Compression)'];
        end
        title(ax, ttl,'Color',TXT,'FontSize',11.5,'FontWeight','bold');
    end

    function draw_support(x, y, t, d)
        lw = 2.0;
        switch t
            case 1  % Pin – triangle pointing up toward node
                tx = [x-d,  x,   x+d, x-d];
                ty = [y-2*d, y,  y-2*d, y-2*d];
                plot(ax,tx,ty,'-','Color',GRNG,'LineWidth',lw);
                for hk = -2:2
                    hx = x + hk*0.4*d;
                    plot(ax,[hx, hx-0.36*d],[y-2*d, y-2.6*d], ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end

            case 2  % Roller – X restrained (vertical wall on left)
                plot(ax,[x x],[y-1.4*d y+1.4*d],'-','Color',GRNG,'LineWidth',lw+0.5);
                theta = linspace(0,2*pi,28);  r0 = d*0.18;
                for hk = -1:1
                    cx2 = x + 0.85*d;  cy2 = y + hk*d;
                    plot(ax,cx2+r0*cos(theta),cy2+r0*sin(theta), ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end
                for hk = -1:1
                    plot(ax,[x+2*r0, x+0.85*d-r0],[y+hk*d, y+hk*d], ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end

            case 3  % Roller – Y restrained (horizontal ground)
                plot(ax,[x-1.4*d x+1.4*d],[y y],'-','Color',GRNG,'LineWidth',lw+0.5);
                theta = linspace(0,2*pi,28);  r0 = d*0.18;
                for hk = -1:1
                    cx2 = x + hk*d;  cy2 = y - 0.85*d;
                    plot(ax,cx2+r0*cos(theta),cy2+r0*sin(theta), ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end
                for hk = -1:1
                    plot(ax,[x+hk*d, x+hk*d],[y-2*r0, y-0.85*d+r0], ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end
                for hk = -2:2
                    hx = x + hk*0.4*d;
                    plot(ax,[hx, hx-0.36*d],[y-1.7*d, y-2.3*d], ...
                        '-','Color',GRNG,'LineWidth',1.1);
                end
        end
    end

    function draw_arrow(x, y, fx, fy, sc)
        dx = fx*sc;  dy = fy*sc;
        quiver(ax, x-dx, y-dy, dx, dy, 0, ...
            'Color',[1 0.48 0.08],'LineWidth',2.8,'MaxHeadSize',0.52);
        lab = fmt_force_pair(fx,fy);
        text(ax, x-dx*1.14, y-dy*1.14, lab, ...
            'Color',[1 0.66 0.28],'FontSize',9, ...
            'HorizontalAlignment','center','Interpreter','none');
    end

%% Naming helpers

    function s = node_label(i)
        % A=1, B=2 … Z=26, AA=27, AB=28 … AZ=52, BA=53 …
        letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
        count = 0;
        n = i;
        while n > 0
            count = count + 1;
            n = floor((n-1)/26);
        end
        s = repmat(' ',1,count);
        n = i;
        for position = count:-1:1
            n = n - 1;
            s(position) = letters(mod(n,26)+1);
            n = floor(n/26);
        end
    end

    function s = member_label(i)
        % Combine the endpoint labels, for example "A-B".
        if i < 1 || i > size(model.members,1)
            s = sprintf('M%d',i);  return
        end
        n1 = model.members(i,1);
        n2 = model.members(i,2);
        s  = [node_label(n1) '-' node_label(n2)];
    end

%% Formatting helpers

    function s = fmt_force(f)
        if     abs(f) >= 1e6, s = sprintf('%.4g MN', f/1e6);
        elseif abs(f) >= 1e3, s = sprintf('%.4g kN', f/1e3);
        else,                  s = sprintf('%.4g N',  f);
        end
    end

    function s = fmt_force_pair(fx, fy)
        if     abs(fx) > abs(fy)*10, s = fmt_force(fx);
        elseif abs(fy) > abs(fx)*10, s = fmt_force(fy);
        else,  s = [fmt_force(fx) ', ' fmt_force(fy)];
        end
    end

%% UI widget helpers

    % Create a muted input-field label.
    function tb_label(parent, txt, x, y, w)
        uilabel(parent,'Text',txt,'Position',[x y w 18], ...
            'FontColor',STXT,'FontSize',11);
    end

    % Create an uppercase input-section label.
    function sec_label(parent, txt, x, y, w)
        uilabel(parent,'Text',txt,'Position',[x y w LBH], ...
            'FontColor',[0.72 0.74 0.80],'FontSize',9.5,'FontWeight','bold');
    end

    % Create a horizontal divider.
    function divider(parent, x, y, w)
        uipanel(parent,'Position',[x y w 1], ...
            'BackgroundColor',DIVC,'BorderType','none');
    end

%% Model initialization

    function m = make_model()
        m.nodes         = [];
        m.members       = [];
        m.forces        = [];
        m.supports      = zeros(0,2);
        m.E             = 200e9;   % Pa  (steel – affects displacements only)
        m.A             = 0.01;    % m²  (100 cm²)
    end

    function r = empty_result()
        r = struct('success',false,'error',"",'memberForces',[], ...
            'U',[],'reactions',[]);
    end

%% Preset models

    function m = load_preset(name)
        m = make_model();
        switch name

            % Three-member triangle with one load at the apex.
            case 'Simple Triangle'
                m.nodes    = [0 0; 4 0; 2 3.464];
                m.members  = [1 2; 2 3; 1 3];
                m.forces   = [3 0 -20000];
                m.supports = [1 1; 2 3];

            case 'Pratt Truss (6-panel)'
                m = build_pratt(6, 1.0, 1.5, -12000);

            case 'Warren Truss (6-panel)'
                m = build_warren(6, 1.0, -12000);

            case 'Howe Truss (6-panel)'
                m = build_howe(6, 1.0, 1.5, -12000);

            % Cantilever fixed by a pin and horizontal-restraint roller.
            case 'Cantilever Truss'
                m.nodes    = [0 0; 0 2; 2 0; 2 2; 4 0; 4 2; 6 0];
                m.members  = [1 2; 1 3; 2 3; 2 4; 3 4; ...
                               3 5; 4 5; 4 6; 5 6; 5 7; 6 7];
                m.forces   = [7 0 -20000; 5 0 -10000];
                m.supports = [1 1; 2 2];

            % Six-node Fink roof truss with split rafters and bottom chord.
            %
            %         3
            %        /|\
            %       4 | 5
            %      / \|/ \
            %     1---6---2
            %
            case 'Roof Truss (Fink)'
                L = 8;  H = 3;

                % Nodes 4 and 5 split the rafters; node 6 splits the bottom chord.
                m.nodes = [0   0; ...   % 1  left support
                            L   0; ...   % 2  right support
                            L/2 H; ...   % 3  apex
                            L/4 H/2; ... % 4  left rafter mid-point
                            3*L/4 H/2; ... % 5  right rafter mid-point
                            L/2 0];      % 6  king-post base (bottom centre)

                m.members = [ ...
                    1 6; ...   % left bottom chord
                    6 2; ...   % right bottom chord
                    1 4; ...   % left rafter lower half
                    4 3; ...   % left rafter upper half
                    2 5; ...   % right rafter lower half
                    5 3; ...   % right rafter upper half
                    4 6; ...   % left inner diagonal (web)
                    5 6; ...   % right inner diagonal (web)
                    3 6];      % king post (vertical centre)

                % Nine members and three reactions satisfy m + r = 2j.
                m.forces   = [3 0 -20000; 4 0 -10000; 5 0 -10000];
                m.supports = [1 1; 2 3];
        end
    end

    function m = build_pratt(np, dx, h, P)
        % Build two node rows with horizontal chords and vertical posts.
        m = make_model();
        for j = 0:np, m.nodes(end+1,:) = [j*dx, 0]; end
        for j = 0:np, m.nodes(end+1,:) = [j*dx, h]; end
        off = np+1;

        for j = 1:np,   m.members(end+1,:) = [j,     j+1];      end
        for j = 1:np,   m.members(end+1,:) = [off+j, off+j+1];  end
        for j = 1:np+1, m.members(end+1,:) = [j,     off+j];    end

        % Pratt diagonals descend toward midspan.
        half = np/2;
        for j = 1:half,    m.members(end+1,:) = [j+1, off+j];   end
        for j = half+1:np, m.members(end+1,:) = [j,   off+j+1]; end

        % Apply equal loads to the interior top nodes.
        for j = 2:np, m.forces(end+1,:) = [off+j, 0, P]; end
        m.supports = [1 1; np+1 3];
    end

    function m = build_warren(np, dx, P)
        % Alternate top nodes between bottom-chord panel points.
        m = make_model();
        h  = dx * sqrt(3)/2;
        for j = 0:np,   m.nodes(end+1,:) = [j*dx,       0]; end
        for j = 0:np-1, m.nodes(end+1,:) = [(j+0.5)*dx, h]; end
        BN = np+1;

        % Connect the bottom chord, diagonals, and top chord.
        for j = 1:np,   m.members(end+1,:) = [j,    j+1]; end
        for j = 1:np
            m.members(end+1,:) = [j,   BN+j];
            m.members(end+1,:) = [j+1, BN+j];
        end
        for j = 1:np-1, m.members(end+1,:) = [BN+j, BN+j+1]; end

        % Apply equal loads to the interior bottom nodes.
        for j = 2:np, m.forces(end+1,:) = [j, 0, P]; end
        m.supports = [1 1; np+1 3];
    end

    function m = build_howe(np, dx, h, P)
        % Build two node rows with horizontal chords and vertical posts.
        m = make_model();
        for j = 0:np, m.nodes(end+1,:) = [j*dx, 0]; end
        for j = 0:np, m.nodes(end+1,:) = [j*dx, h]; end
        off = np+1;

        for j = 1:np,   m.members(end+1,:) = [j,     j+1];      end
        for j = 1:np,   m.members(end+1,:) = [off+j, off+j+1];  end
        for j = 1:np+1, m.members(end+1,:) = [j,     off+j];    end

        % Howe diagonals ascend toward midspan.
        half = np/2;
        for j = 1:half,    m.members(end+1,:) = [j,   off+j+1]; end
        for j = half+1:np, m.members(end+1,:) = [j+1, off+j];   end

        % Apply equal loads to the interior top nodes.
        for j = 2:np, m.forces(end+1,:) = [off+j, 0, P]; end
        m.supports = [1 1; np+1 3];
    end

end  % truss_ui
