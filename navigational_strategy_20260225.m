clc; clear; close all;

%% ROOT
ROOT.Mother = 'D:';
ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
ROOT.Info = [ROOT.Raw '\info'];
ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];

%% Load session list
load([ROOT.Info '\session_info.mat']);

%% Initialize
all_dist = [];

%% Loop over rats and sessions
rats = unique(session_list.rat);

for r = 1:numel(rats)

    rat = char(rats(r));
    SL  = session_list(string(session_list.rat)==rat & ...
                   string(session_list.goal)=="East", :);

    for s = 1:height(SL)

        % --- session number formatting ---
        ss_num = str2double(string(SL.ss(s)));
        ss_str = sprintf('%02d', ss_num);
        target = [rat '-' ss_str];

        % --- behavior file path ---
        beh = fullfile(ROOT.Data, [target '.mat']);

        % 파일 없으면 skip
        if ~exist(beh, 'file')
            continue;
        end

        S = load(beh);

        % ue_t 없으면 skip
        if ~isfield(S, 'ue_t')
            continue;
        end

        ue_t = S.ue_t;

        % -------------------------------
        % start_direction == 90 trials만
        % -------------------------------

        if istable(ue_t)

            if ismember('start_direction', ue_t.Properties.VariableNames) && ...
               ismember('travaled_distance', ue_t.Properties.VariableNames)

                 idx = (ue_t.start_direction == 270) & (ue_t.performance_available == 1);
                 d   = ue_t.travaled_distance(idx);

            else
                continue;
            end

        elseif isstruct(ue_t)

            if isfield(ue_t,'start_direction') && ...
               isfield(ue_t,'travaled_distance')

                idx = (ue_t.start_direction == 270) & (ue_t.performance_available == 1);
                d   = ue_t.travaled_distance(idx);

            else
                continue;
            end

        else
            continue;
        end

        % NaN 제거 후 누적
        d = d(:);
        d = d(~isnan(d));

        all_dist = [all_dist; d];

    end
end


%% Histogram
figure;
histogram(all_dist, 'BinWidth', 0.2);
xlabel('Travel distance');
xlim ([0 4]);
xticks(0:0.4:4);
ylabel('Count');
title('All rats | South start | East goal');
box off;




% %% kernel density plot (rat-by-rat)
% clc; clear; close all;
% 
% %% ROOT
% ROOT.Mother = 'D:';
% ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
% ROOT.Info = [ROOT.Raw '\info'];
% ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];
% 
% %% Load session list
% load(fullfile(ROOT.Info,'session_info.mat'));  % session_list
% 
% %% Collect travel distance by rat (start_direction==90 only)
% rats = unique(session_list.rat);
% D_byRat = cell(numel(rats),1);
% 
% for r = 1:numel(rats)
% 
%     rat = char(rats(r));
%     SL  = session_list(string(session_list.rat)==rat, :);
% 
%     d_all = [];
% 
%     for s = 1:height(SL)
% 
%         ss_num = str2double(string(SL.ss(s)));
%         ss_str = sprintf('%02d', ss_num);
%         target = [rat '-' ss_str];
% 
%         beh = fullfile(ROOT.Data, [target '.mat']);
%         if ~exist(beh,'file'), continue; end
% 
%         S = load(beh);
%         if ~isfield(S,'ue_t'), continue; end
%         ue_t = S.ue_t;
% 
%         % --- grab start_direction==90 trials ---
%         if istable(ue_t)
% 
%             if ~ismember('start_direction', ue_t.Properties.VariableNames)
%                 continue;
%             end
% 
%             % travel distance variable name (robust)
%             cand = {'travaled_distance','traveled_distance','travel_distance'};
%             vname = "";
%             for k = 1:numel(cand)
%                 if ismember(cand{k}, ue_t.Properties.VariableNames)
%                     vname = cand{k}; break;
%                 end
%             end
%             if vname == "", continue; end
% 
%             idx = (ue_t.start_direction == 270);
%             d   = ue_t.(vname);
%             d   = d(idx);
% 
%         elseif isstruct(ue_t)
% 
%             if ~isfield(ue_t,'start_direction'), continue; end
%             cand = {'travaled_distance','traveled_distance','travel_distance'};
%             vname = '';
%             for k = 1:numel(cand)
%                 if isfield(ue_t, cand{k})
%                     vname = cand{k}; break;
%                 end
%             end
%             if isempty(vname), continue; end
% 
%             idx = (ue_t.start_direction == 270) & (ue_t.performance_avaliable == 1);
%             d   = ue_t.(vname);
%             d   = d(idx);
% 
%         else
%             continue;
%         end
% 
%         d = d(:);
%         d = d(~isnan(d));
%         d_all = [d_all; d];
% 
%     end
% 
%     D_byRat{r} = d_all;
% end
% 
% %% Plot KDE per rat
% figure('Color','w'); hold on;
% okRat = false(numel(rats),1);
% 
% for r = 1:numel(rats)
%     d = D_byRat{r};
%     if numel(d) < 5
%         continue;  % 데이터 너무 적으면 스킵
%     end
%     okRat(r) = true;
% 
%     [f, xi] = ksdensity(d);
%     plot(xi, f, 'LineWidth', 1.5, 'DisplayName', ['LE' char(rats(r))]);
% end
% 
% xlabel('Travel distance');
% ylabel('Density');
% title('Travel distance distribution per rat (start\_direction = 270)');
% box off;
% 
% % legend 너무 복잡하면 끄고, 필요하면 켜기
% legend('Location','bestoutside');
% 
% %% Quick print
% fprintf('Rats plotted: %d / %d\n', sum(okRat), numel(rats));
% for r = 1:numel(rats)
%     if okRat(r)
%         fprintf('LE%s: n=%d\n', char(rats(r)), numel(D_byRat{r}));
%     end
% end

% clc; clear; close all;
% 
% %% ROOT
% ROOT.Mother = 'D:';
% ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
% ROOT.Info = [ROOT.Raw '\info'];
% ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];
% 
% load(fullfile(ROOT.Info,'session_info.mat'));
% 
% %% 결과 저장용
% Tout = table();
% 
% rats = unique(session_list.rat);
% 
% for r = 1:numel(rats)
% 
%     rat = char(rats(r));
%     SL  = session_list(string(session_list.rat)==rat, :);
% 
%     for s = 1:height(SL)
% 
%         ss_num = str2double(string(SL.ss(s)));
%         ss_str = sprintf('%02d', ss_num);
%         target = [rat '-' ss_str];
% 
%         file_path = fullfile(ROOT.Data, [target '.mat']);
%         if ~exist(file_path,'file'), continue; end
% 
%         S = load(file_path);
% 
%         if ~isfield(S,'ue') || ~isfield(S,'ue_t') || ~isfield(S,'cheetah')
%             continue;
%         end
% 
%         ue = S.ue;
%         ue_t = S.ue_t;
%         cheetah = S.cheetah;
% 
%         tick_all = cheetah.tick;   % 전체 tick 벡터
%         ang_all  = ue.angular_velocity_smoothed;
% 
%         Ntrial = numel(ue_t.trial_start);
% 
%         for iTrial = 1:Ntrial
%             if ue_t.performance_available ~= 1
%                 continue;
%             end
% 
%             % start_direction == 90만
%             if ue_t.start_direction(iTrial) ~= 270
%                 continue;
%             end
% 
%             % trial start/end tick
%             stTick = tick_all(ue_t.trial_start(iTrial));
%             enTick = tick_all(ue_t.rewardzone_arrival(iTrial));
% 
%             if isnan(stTick) || isnan(enTick) || enTick <= stTick
%                 continue;
%             end
% 
%             % tick 범위 선택
%             idx = (tick_all >= stTick) & (tick_all <= enTick);
%             if ~any(idx), continue; end
% 
%             ang_seg = ang_all(idx);
%             ang_seg = ang_seg(~isnan(ang_seg));
%             if isempty(ang_seg), continue; end
% 
%             mean_abs_ang = mean(abs(ang_seg));
% 
%             % travel distance (ue_t에 있다고 가정)
%             travel_dist = ue_t.travaled_distance(iTrial);
% 
%             if isnan(travel_dist), continue; end
% 
%             % 저장
%             Tout = [Tout; table( ...
%                 string(rat), ss_num, iTrial, ...
%                 travel_dist, mean_abs_ang, ...
%                 'VariableNames', ...
%                 {'rat','ss','trial','travel_distance','mean_abs_angvel'})];
% 
%         end
%     end
% end
% 
% %% ===== Scatter plot =====
% figure('Color','w');
% scatter(Tout.travel_distance, Tout.mean_abs_angvel, 15, 'filled');
% xlabel('Travel distance');
% ylabel('Mean |angular velocity|');
% title('Travel distance vs Mean |angular velocity| (start\_direction = 270)');
% box off;


% %% trajectory with TD threshold
% %% Trajectory examples (single_session) - filtered by travel distance range
% clc; clear; close all;
% 
% %% ROOT (네 설정대로)
% ROOT.Mother = 'D:';
% ROOT.Raw  = [ROOT.Mother '\1. Behavioral data'];
% ROOT.Info = [ROOT.Raw '\info'];
% ROOT.Data = [ROOT.Raw '\results\behavior\15-May-2024\'];
% ROOT.Save = [ROOT.Data '\navigational strategy'];
% if ~exist(ROOT.Save,'dir'), mkdir(ROOT.Save); end
% 
% addpath(genpath(fullfile(ROOT.Mother, 'toolbox'))); % toolbox
% 
% load(fullfile(ROOT.Info,'session_info.mat'));  % session_list (goal/stage 쓰려면)
% 
% % Reward zone and start zone parameter setting
% Maze.Outline.x = 0;
% Maze.Outline.y = 0;
% Maze.Outline.r = 0.9500;
% 
% %실제 언리얼 상에서 reward zone diameter
% RewardZone.inner.r = 0.6500;
% RewardZone.outer.r = 0.8000;
% 
% %center of reward zone
% RewardZone.arch.x = -0.7715; % RewardZone.arch.x=-5186; % west 
% RewardZone.arch.y = 0.1552; % RewardZone.arch.y=873; % west 
% RewardZone.sea.x = -0.780; % 사용안함
% RewardZone.sea.y = -0.5130; % 사용안함
% RewardZone.house.x = 0.7715; % RewardZone.house.x=5247; % east  
% RewardZone.house.y = -0.1552; % RewardZone.house.y=-698; % east 
% 
% 
% %% ===== User setting =====
% target     = '817-03';     % 'rat-ss'
% dist_range = [1 10];  % 여기에 원하는 범위 지정
% use_start_direction_filter = true;
% start_direction_target      = 90;  % 필요하면 90/270
% 
% %% ===== Parse target =====
% temp = split(target, '-');
% rat  = temp{1};
% ss   = sprintf('%02d', str2double(temp{2}));  % 2자리
% target = rat + "-" + ss;                      % 혹시 '817-12' -> '817-12' 유지/정규화
% 
% %% ===== Load session data =====
% load(fullfile(ROOT.Data, target + ".mat"));   % ue, ue_t, Maze, RewardZone 등이 들어있다고 가정
% 
% % ---- travel distance 변수명 통일 (오타 대응) ----
% distVar = "";
% cand = {'travaled_distance','traveled_distance','travel_distance'};
% for k = 1:numel(cand)
%     if istable(ue_t) && ismember(cand{k}, ue_t.Properties.VariableNames)
%         distVar = cand{k}; break;
%     end
% end
% if distVar == ""
%     error('ue_t에서 travel distance 변수명을 찾지 못했어. (travaled/traveled/travel_distance 확인)');
% end
% 
% %% ===== Trial selection by travel distance range =====
% dist_all = ue_t.(distVar);
% 
% idx = (ue_t.performance_available == 1) & ...
%       (dist_all >= dist_range(1)) & (dist_all <= dist_range(2));
% 
% % (옵션) start_direction 필터
% if use_start_direction_filter
%     idx = idx & (ue_t.start_direction == 90);
% end
% 
% trial_list = find(idx);
% 
% fprintf('Selected trials: %d (range %.3f-%.3f)\n', numel(trial_list), dist_range(1), dist_range(2));
% if isempty(trial_list)
%     warning('해당 범위에 들어가는 trial이 없어. dist_range를 바꿔봐.');
% end
% 
% %% ===== Plot =====
% f = figure('Color','w','Position',[100,100,450,400]);
% 
% p_Outline = Draw_Circle(Maze.Outline.x, Maze.Outline.y, Maze.Outline.r, 4);
% hold on; p_Outline.LineWidth = 0.75;
% 
% % 선택된 trial만 그리기
% for ii = 1:numel(trial_list)
%     i = trial_list(ii);
% 
%     % 기존 조건 그대로 유지
%     X = ue.position_x(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
%     Y = ue.position_y(ue.trial == i & ue.frame_ITI == 0 & ue.rewardzone_arrival == 0);
% 
%     if numel(X) < 2, continue; end
% 
%     p1 = plot(X, Y); 
%     p1.LineWidth = 1;
%     p1.LineStyle = '-';
%     p1.Color     = [0.2 0.2 0.2];      % 선택된 것들은 진하게
% 
%     plot(X(end), Y(end), 'r.', 'MarkerSize', 14); % end point
% end
% 
% % 참고: 세션 correctness (전체 trial 기준)
% correctness = sum(ue_t.performance == 1) / size(ue_t,1) * 100;
% 
% axis off;
% title(sprintf('%s | dist[%.2f %.2f] | n=%d | %.1f%%', ...
%     target, dist_range(1), dist_range(2), numel(trial_list), correctness));
% 
% %% ===== Reward zone arcs (네 코드 그대로) =====
% p_in = Draw_AngledCircle(0,0, RewardZone.inner.r,2);
% p_in.LineWidth=1; p_in.LineStyle='-';
% 
% p_out = Draw_AngledCircle(0,0, RewardZone.outer.r,2);
% p_out.LineWidth=1; p_out.LineStyle='-';
% 
% plot([p_in.XData(1)  p_out.XData(1)], [p_in.YData(1)  p_out.YData(1)], 'r-', 'LineWidth',1);
% plot([p_in.XData(end)  p_out.XData(end)], [p_in.YData(end)  p_out.YData(end)], 'r-', 'LineWidth',1);
% 
% p_in2 = Draw_AngledCircle2(0,0,RewardZone.inner.r,1);
% p_in2.LineWidth=1;
% 
% p_out2 = Draw_AngledCircle2(0,0,RewardZone.outer.r,1);
% p_out2.LineWidth=1;
% 
% plot([p_in2.XData(1)  p_out2.XData(1)], [p_in2.YData(1)  p_out2.YData(1)], 'b-', 'LineWidth',1);
% plot([p_in2.XData(end)  p_out2.XData(end)], [p_in2.YData(end)  p_out2.YData(end)], 'b-', 'LineWidth',1);
% 
% %% ===== Save =====
% rat_folder = fullfile(ROOT.Save, ['LE' char(rat)]);
% if ~exist(rat_folder, 'dir')
%     mkdir(rat_folder);
% end
% 
% outname = sprintf('%s_dist_%0.2f-%0.2f.jpg', target, dist_range(1), dist_range(2));
% exportgraphics(f, fullfile(rat_folder, outname), 'Resolution', 300);
