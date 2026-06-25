function raw_behaviour_20260612(ROOT, rat, ss)
% Trial-wise raw behaviour sheets for one session
% Called from raw_behaviour_sheet_batch.m
%
% This file has NO local helper functions.

%% Format session name
rat = char(string(rat));
ss_num = str2double(string(ss));
target = sprintf('%s-%02d', rat, ss_num);

%% Load behaviour data
behavFile = fullfile(ROOT.behav, [target '.mat']);

if ~exist(behavFile, 'file')
    error('Behaviour file not found: %s', behavFile);
end

D = load(behavFile, 'ue', 'ue_t', 'encoder');

ue      = D.ue;
ue_t    = D.ue_t;
encoder = D.encoder;

%% Load first bump data
B = load(ROOT.bump, 'T_bump');
T_bump = B.T_bump;

%% Save folder
saveFolder = fullfile(ROOT.save, ['LE' rat], target);

if ~exist(saveFolder, 'dir')
    mkdir(saveFolder);
end

%% Maze / reward zone parameters
mazeR       = 0.95;
rewardInner = 0.65; % radius
rewardOuter = 0.80; % radius 
halfWidth   = 23;

westX = -0.7715;
westY =  0.1552;

eastX =  0.7715;
eastY = -0.1552;

circleAngle = linspace(0, 2*pi, 500);

%% Trial loop
for tr = 1:height(ue_t)

    %% Skip unavailable trials
    if ue_t.performance_available(tr) ~= 1
        continue
    end

    %% Find first bump row for this trial
    bumpRow = find( ...
        string(T_bump.rat) == string(rat) & ...
        T_bump.ss == ss_num & ...
        T_bump.trial == tr, 1);

    if isempty(bumpRow)
        fprintf('%s trial %d: first bump not found.\n', target, tr);
        continue
    end

    %% Define trial range: trial start to before first bump
    trialStartRow = round(ue_t.trial_start(tr));
    firstBumpRow  = round(T_bump.hit_frame_global(bumpRow));

    idx = (trialStartRow:firstBumpRow-1)';

    if numel(idx) < 5
        continue
    end

    %% Extract variables
    t = ue.time(idx);
    t = t - t(1);

    X = ue.position_x(idx);
    Y = ue.position_y(idx);


    %% other indices
    speed     = encoder.velocity_smoothed(idx);
    direction = mod(ue.direction(idx), 360);
    travelDist = sum(sqrt(diff(X).^2 + diff(Y).^2), 'omitnan');

    % Compute wrap-corrected angular velocity from ue.direction
    dt = 0.03;
    dtheta = [0; rad2deg(angle(exp(1i * deg2rad(diff(direction)))))];
    angVelRaw = dtheta ./ dt;   % deg/s
    
    % 200 ms smoothing
    smoothWin = round(0.200 / dt);
    
    % make smoothing window odd number
    if mod(smoothWin, 2) == 0
        smoothWin = smoothWin + 1;
    end
    
    angVelSmooth200 = movmean(angVelRaw, smoothWin, 'omitnan');
    angVelAbs = abs(angVelSmooth200);

    %% Trial information
    goalLabel = char(string(T_bump.goal(bumpRow)));

    if T_bump.start_direction(bumpRow) == 90
        startLabel = 'North';
    elseif T_bump.start_direction(bumpRow) == 270
        startLabel = 'South';
    else
        startLabel = num2str(T_bump.start_direction(bumpRow));
    end

    if ue_t.performance(tr) == 1
        correctness = 'correct';
    else
        correctness = 'incorrect';
    end

    figTitle = sprintf( ...
        'Rat %s | Session %02d | Trial %d | Goal %s | SD %s | %s | Dist %.3f', ...
        rat, ss_num, tr, goalLabel, startLabel, correctness, travelDist);

    %% Distance to reward-zone centre
    if strcmpi(goalLabel, 'West') || strcmpi(goalLabel, 'arch')
        goalX = westX;
        goalY = westY;
    elseif strcmpi(goalLabel, 'East') || strcmpi(goalLabel, 'house')
        goalX = eastX;
        goalY = eastY;
    else
        goalX = NaN;
        goalY = NaN;
    end
    
    distToGoalCentre = sqrt((X - goalX).^2 + (Y - goalY).^2);
    %% Make figure
    f = figure( ...
        'Position', [100 100 1200 850], ...
        'Color', 'w', ...
        'Visible', 'off');

    % tiledlayout(4, 2, ...
    %     'TileSpacing', 'compact', ...
    %     'Padding', 'compact');

    tl = tiledlayout(4, 2, ...
    'TileSpacing', 'compact', ...
    'Padding', 'compact');

    sgtitle(figTitle, ...
        'Interpreter', 'none', ...
        'FontWeight', 'normal');

    %% Panel 1: Trajectory
    nexttile(tl, 1, [2 1]);
    hold on;

    % Maze outline
    plot(mazeR*cos(circleAngle), mazeR*sin(circleAngle), ...
        'k-', 'LineWidth', 1.5);

    % Inner circle
    plot(rewardInner*cos(circleAngle), rewardInner*sin(circleAngle), ...
        '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);

    % West reward zone
    westCenter = atan2d(westY, westX);
    westAngle = deg2rad(linspace( ...
        westCenter-halfWidth, westCenter+halfWidth, 100));

    westInnerX = rewardInner*cos(westAngle);
    westInnerY = rewardInner*sin(westAngle);
    westOuterX = rewardOuter*cos(westAngle);
    westOuterY = rewardOuter*sin(westAngle);

    plot(westInnerX, westInnerY, 'r-', 'LineWidth', 1.2);
    plot(westOuterX, westOuterY, 'r-', 'LineWidth', 1.2);
    plot([westInnerX(1), westOuterX(1)], ...
         [westInnerY(1), westOuterY(1)], 'r-', 'LineWidth', 1.2);
    plot([westInnerX(end), westOuterX(end)], ...
         [westInnerY(end), westOuterY(end)], 'r-', 'LineWidth', 1.2);

    % East reward zone
    eastCenter = atan2d(eastY, eastX);
    eastAngle = deg2rad(linspace( ...
        eastCenter-halfWidth, eastCenter+halfWidth, 100));

    eastInnerX = rewardInner*cos(eastAngle);
    eastInnerY = rewardInner*sin(eastAngle);
    eastOuterX = rewardOuter*cos(eastAngle);
    eastOuterY = rewardOuter*sin(eastAngle);

    plot(eastInnerX, eastInnerY, 'b-', 'LineWidth', 1.2);
    plot(eastOuterX, eastOuterY, 'b-', 'LineWidth', 1.2);
    plot([eastInnerX(1), eastOuterX(1)], ...
         [eastInnerY(1), eastOuterY(1)], 'b-', 'LineWidth', 1.2);
    plot([eastInnerX(end), eastOuterX(end)], ...
         [eastInnerY(end), eastOuterY(end)], 'b-', 'LineWidth', 1.2);

    % Trajectory coloured by speed
    surface( ...
        [X'; X'], ...
        [Y'; Y'], ...
        zeros(2, numel(X)), ...
        [speed'; speed'], ...
        'FaceColor', 'none', ...
        'EdgeColor', 'interp', ...
        'LineWidth', 2.5);

    colormap(gca, parula);

    cb = colorbar;
    cb.Label.String = 'encoder speed';
    cb.Label.Interpreter = 'none';

    % Start and end markers
    plot(X(1), Y(1), 'ko', ...
        'MarkerFaceColor', [0 0.9 0], ...
        'MarkerSize', 7);

    plot(X(end), Y(end), 'ko', ...
        'MarkerFaceColor', [1 0 0], ...
        'MarkerSize', 7);

    xlabel('X');
    ylabel('Y');
    title('Trajectory before first bump');

    axis equal;
    xlim([-1 1]);
    ylim([-1 1]);
    grid on;
    box on;


    %% Panel 1-1: trajectory with angular velocity 
    nexttile(tl, 2, [2 1]); 
    hold on;

    % Maze outline
    plot(mazeR*cos(circleAngle), mazeR*sin(circleAngle), ...
        'k-', 'LineWidth', 1.5);

    % Inner circle
    plot(rewardInner*cos(circleAngle), rewardInner*sin(circleAngle), ...
        '--', 'Color', [0.45 0.45 0.45], 'LineWidth', 1.2);

    % West reward zone
    westCenter = atan2d(westY, westX);
    westAngle = deg2rad(linspace( ...
        westCenter-halfWidth, westCenter+halfWidth, 100));

    westInnerX = rewardInner*cos(westAngle);
    westInnerY = rewardInner*sin(westAngle);
    westOuterX = rewardOuter*cos(westAngle);
    westOuterY = rewardOuter*sin(westAngle);

    plot(westInnerX, westInnerY, 'r-', 'LineWidth', 1.2);
    plot(westOuterX, westOuterY, 'r-', 'LineWidth', 1.2);
    plot([westInnerX(1), westOuterX(1)], ...
         [westInnerY(1), westOuterY(1)], 'r-', 'LineWidth', 1.2);
    plot([westInnerX(end), westOuterX(end)], ...
         [westInnerY(end), westOuterY(end)], 'r-', 'LineWidth', 1.2);

    % East reward zone
    eastCenter = atan2d(eastY, eastX);
    eastAngle = deg2rad(linspace( ...
        eastCenter-halfWidth, eastCenter+halfWidth, 100));

    eastInnerX = rewardInner*cos(eastAngle);
    eastInnerY = rewardInner*sin(eastAngle);
    eastOuterX = rewardOuter*cos(eastAngle);
    eastOuterY = rewardOuter*sin(eastAngle);

    plot(eastInnerX, eastInnerY, 'b-', 'LineWidth', 1.2);
    plot(eastOuterX, eastOuterY, 'b-', 'LineWidth', 1.2);
    plot([eastInnerX(1), eastOuterX(1)], ...
         [eastInnerY(1), eastOuterY(1)], 'b-', 'LineWidth', 1.2);
    plot([eastInnerX(end), eastOuterX(end)], ...
         [eastInnerY(end), eastOuterY(end)], 'b-', 'LineWidth', 1.2);

    % Trajectory coloured by speed
    surface( ...
    [X'; X'], ...
    [Y'; Y'], ...
    zeros(2, numel(X)), ...
    [angVelAbs'; angVelAbs'], ...
    'FaceColor', 'none', ...
    'EdgeColor', 'interp', ...
    'LineWidth', 2.5);

    cb = colorbar;
    cb.Label.String = '|angular velocity|';
    cb.Label.Interpreter = 'none';

    % Start and end markers
    plot(X(1), Y(1), 'ko', ...
        'MarkerFaceColor', [0 0.9 0], ...
        'MarkerSize', 7);

    plot(X(end), Y(end), 'ko', ...
        'MarkerFaceColor', [1 0 0], ...
        'MarkerSize', 7);

    xlabel('X');
    ylabel('Y');
    title('Trajectory before first bump');

    axis equal;
    xlim([-1 1]);
    ylim([-1 1]);
    grid on;
    box on;

    %% Panel 2: Encoder speed
    nexttile(tl, 5);   
    plot(t, speed, 'k-', 'LineWidth', 1.3);
    xlabel('Time from trial start (s)');
    ylabel('Speed');
    title('Encoder speed 500ms smoothed');
    ylim([0 65]);
    grid on;
    box off;

    %% Panel 3: Angular velocity
    nexttile(tl, 6);
    plot(t, angVelAbs, 'k-', 'LineWidth', 1.3);
    xlabel('Time from trial start (s)');
    ylabel('|Angular velocity|');
    title('UE angular velocity 200ms smoothed');
    ylim([0 max(angVelAbs)*1.05]);
    grid on;
    box off;

    %% Panel 4: remaining distance to rewardzone 
   
    nexttile(tl, 7); 
    plot(t, distToGoalCentre, 'k-', 'LineWidth', 1.3);
    xlabel('Time from trial start (s)');
    ylabel('Distance');
    title('Distance to reward-zone centre');
    ylim([0 max(distToGoalCentre)*1.05]);
    grid on;
    box off;

    %% Panel 5: Direction
    nexttile(tl, 8); 
    % plot(t, direction, 'k-', 'LineWidth', 1.3);
    % xlabel('Time from trial start (s)');
    % ylabel('Direction (deg)');
    % title('UE direction');
    % ylim([0 360]);
    % yticks(0:90:360);
    % yline(170, 'r--', 'LineWidth', 1.2);
    % yline(350, 'b--', 'LineWidth', 1.2);
    % grid on;
    % box off;

     
% if T_bump.start_direction(bumpRow) == 90
%     dir_plot = mod(direction - 90, 360);
%     tickLabels = {'90','0/360','270','180','90'};
%     redLine  = mod(170 - 90, 360);
%     blueLine = mod(350 - 90, 360);
% 
% elseif T_bump.start_direction(bumpRow) == 270
%     dir_plot = mod(direction - 270, 360);
%     tickLabels = {'270','180','90','0/360','270'};
%     redLine  = mod(170 - 270, 360);
%     blueLine = mod(350 - 270, 360);
%  end
% 
%     % wrap-around jump 구간 끊기
%     dir_plot_cut = dir_plot;
%     jumpIdx = abs(diff(dir_plot_cut)) > 180;
%     dir_plot_cut([false; jumpIdx(:)]) = NaN;
% 
%     plot(t, dir_plot_cut, 'k-', 'LineWidth', 1.3);
% 
%     set(gca, 'YDir', 'reverse');
%     ylim([0 360]);
%     yticks([0 90 180 270 360]);
%     yticklabels(tickLabels);
% 
%     yline(redLine, 'r--', 'LineWidth', 1.2);
%     yline(blueLine, 'b--', 'LineWidth', 1.2);
% 
%     xlabel('Time from trial start (s)');
%     ylabel('Direction (deg)');
%     title('UE direction');
%     grid on;
%     box off;
 
%% Panel: UE direction

nexttile;
hold on;

startDir = T_bump.start_direction(bumpRow);

% 열 벡터로 통일
direction = direction(:);
t         = t(:);

% 0/360 경계를 지나더라도 연속적인 각도로 변환
direction_unwrapped = rad2deg(unwrap(deg2rad(direction)));

% 시작 방향으로부터의 누적 clockwise 회전량
% 예: North start
% 90 -> 0
% 89 -> 1
% 0  -> 90
% 359 -> 91
% 한 바퀴 후 90 -> 360
dir_plot = startDir - direction_unwrapped;

plot(t, dir_plot, 'k-', 'LineWidth', 1.3);

%% y축 범위 설정
% 반시계 방향 움직임이 포함되면 음수 범위도 보존
yMin = min(0, floor(min(dir_plot) / 90) * 90);

% 최소 한 바퀴는 표시하고, 한 바퀴를 넘으면 자동 확장
yMax = max(360, ceil(max(dir_plot) / 90) * 90);

% 정확히 같은 값이면 범위 확보
if yMax <= yMin
    yMax = yMin + 360;
end

ylim([yMin yMax]);
set(gca, 'YDir', 'reverse');

%% 누적 회전량에 맞춰 실제 방향값을 y축 label로 표시
tickValues = yMin:90:yMax;
tickAngles = mod(startDir - tickValues, 360);

tickLabels = cell(size(tickAngles));

for i = 1:numel(tickAngles)
    if abs(tickAngles(i)) < 1e-10
        tickLabels{i} = '0/360';
    else
        tickLabels{i} = sprintf('%g', tickAngles(i));
    end
end

yticks(tickValues);
yticklabels(tickLabels);

%% 170도와 350도 기준선을 모든 회전에 반복해서 표시
targetDirections = [170, 350];
lineStyles       = {'r--', 'b--'};

for i = 1:numel(targetDirections)

    targetDir = targetDirections(i);

    % 시작 방향으로부터 해당 방향까지의 clockwise 거리
    baseY = mod(startDir - targetDir, 360);

    % 현재 y축 범위 안에서 반복되는 모든 위치 계산
    kMin = ceil((yMin - baseY) / 360);
    kMax = floor((yMax - baseY) / 360);

    repeatedY = baseY + (kMin:kMax) * 360;

    for j = 1:numel(repeatedY)
        yline(repeatedY(j), lineStyles{i}, ...
            'LineWidth', 1.2);
    end
end

xlabel('Time from trial start (s)');
ylabel('Direction (deg)');
title('UE direction');

grid on;
box off;

    %% Save
    saveName = sprintf('%s_trial%03d.jpg', target, tr);
    exportgraphics(f, fullfile(saveFolder, saveName), 'Resolution', 300);
    close(f);

end

fprintf('Finished %s.\n', target);

end
