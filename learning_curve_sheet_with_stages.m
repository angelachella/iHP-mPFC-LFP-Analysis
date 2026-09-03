clear; close all; clc;

%% =========================================================
%  Behavioral session summary sheets
%
%  Row 1: All trials       learning curve | trajectory
%  Row 2: Easy trials      learning curve | trajectory
%  Row 3: Difficult trials learning curve | trajectory
%
%  Easy:
%     West goal + South start
%     East goal + North start
%
%  Difficult:
%     West goal + North start
%     East goal + South start
%
%  Stage onsets in each All / Easy / Difficult learning curve:
%     Pre  = confidently-low period begins at trial 1
%     Rule = upper 90% bound reaches chance for a sustained period
%     Acq  = first lower 90% bound crossing above chance
%     Post = sustained lower-bound crossing + maintained high accuracy
%% =========================================================

%% 경로 설정
ROOT.Mother = 'D:';
ROOT.Raw    = fullfile(ROOT.Mother, '1. Behavioral data');
ROOT.Info   = fullfile(ROOT.Raw, 'info');
ROOT.Data   = fullfile(ROOT.Raw, 'results', 'behavior', '15-May-2024');
ROOT.Save   = fullfile(ROOT.Raw, 'results', 'figures', ...
    'learning curve', 'session_summary_learning_stages');

if ~exist(ROOT.Save, 'dir')
    mkdir(ROOT.Save);
end

addpath(genpath(fullfile(ROOT.Mother, 'toolbox')));

%% 분석 설정

% 빈칸이면 모든 쥐 분석
% 예: RAT_LIST = {'774','779','780','781','816','817'};
RAT_LIST = {};

% 특정 세션만 분석하고 싶으면 입력
% 예: TARGET_SESSION = {'817-08','817-12'};
% 빈칸이면 ROOT.Data의 모든 세션 분석
TARGET_SESSION = {};

CURVE.window = 15;      % moving-window 크기
CURVE.alpha  = 0.10;    % 90% credible interval
CURVE.displaySmoothSpan = 11;  % Gaussian smoothing (display only)
CURVE.chanceLevel = 0.50;
CURVE.minTransitionHold = 5;   % Rule criterion persistence
CURVE.minPostHold = 5;         % lower CI persistence for Post
CURVE.postAccuracy = 0.75;     % accuracy from Post onset to session end
CURVE.minPostTrials = 10;      % minimum remaining trials for Post
CURVE.showRawOutcome = true;

SAVE.jpg = true;
SAVE.pdf = true;
SAVE.closeFigure = true;

%% Maze 설정
Maze.center = [0, 0];
Maze.radius = 0.9500;

RewardZone.innerRadius = 0.6500;
RewardZone.outerRadius = 0.8000;
RewardZone.halfWidth   = 23;       % degree

RewardZone.West.center = [-0.7715,  0.1552];
RewardZone.East.center = [ 0.7715, -0.1552];

COLOR.All       = [0.85, 0.20, 0.20];
COLOR.Easy      = [0.55, 0.25, 0.75];
COLOR.Difficult = [0.15, 0.55, 0.25];

STAGE_COLOR.Pre         = [0.25, 0.25, 0.25];
STAGE_COLOR.Rule        = [0.95, 0.55, 0.05];
STAGE_COLOR.Acquisition = [0.10, 0.35, 0.85];
STAGE_COLOR.Post        = [0.00, 0.60, 0.55];

%% 분석할 파일 탐색
fileList = dir(fullfile(ROOT.Data, '*.mat'));
load([ROOT.Info '\session_info.mat']);
sessionInfo = struct( ...
    'filename', {}, ...
    'target', {}, ...
    'rat', {}, ...
    'session', {});

for iFile = 1:numel(fileList)

    [~, baseName] = fileparts(fileList(iFile).name);

    % 파일 이름 예: 817-12.mat
    token = regexp(baseName, '^(\d+)-(\d+)$', 'tokens', 'once');

    if isempty(token)
        continue;
    end

    rat = token{1};
    ss  = str2double(token{2});

    % 쥐 선택
    if ~isempty(RAT_LIST) && ~ismember(rat, RAT_LIST)
        continue;
    end

    % 특정 세션 선택
    if ~isempty(TARGET_SESSION)
        targetNoZero = sprintf('%s-%d', rat, ss);

        if ~ismember(baseName, TARGET_SESSION) && ...
                ~ismember(targetNoZero, TARGET_SESSION)
            continue;
        end
    end

    n = numel(sessionInfo) + 1;

    sessionInfo(n).filename = fileList(iFile).name;
    sessionInfo(n).target   = baseName;
    sessionInfo(n).rat      = rat;
    sessionInfo(n).session  = ss;
end

if isempty(sessionInfo)
    error('분석 가능한 rat-session MAT 파일을 찾지 못했습니다.');
end

% rat과 session 순서로 정렬
sortMatrix = zeros(numel(sessionInfo), 2);

for i = 1:numel(sessionInfo)
    sortMatrix(i,1) = str2double(sessionInfo(i).rat);
    sortMatrix(i,2) = sessionInfo(i).session;
end

[~, sortIndex] = sortrows(sortMatrix, [1, 2]);
sessionInfo = sessionInfo(sortIndex);

fprintf('총 %d개 세션을 분석합니다.\n\n', numel(sessionInfo));

%% =========================================================
%  Session loop
%% =========================================================
for iSession = 1:numel(sessionInfo)

    target = sessionInfo(iSession).target;
    rat    = sessionInfo(iSession).rat;
    ss     = sessionInfo(iSession).session;

    fprintf('[%d/%d] %s 분석 중...\n', ...
        iSession, numel(sessionInfo), target);

    sessionFile = fullfile(ROOT.Data, ...
        sessionInfo(iSession).filename);

    S = load(sessionFile);

    if ~isfield(S, 'ue_t') || ~isfield(S, 'ue')
        warning('%s: ue_t 또는 ue가 없습니다. 건너뜁니다.', target);
        continue;
    end

    ue_t = S.ue_t;
    ue   = S.ue;

    nTrialTotal = size(ue_t, 1);

    %% 필수 trial 정보
    performanceAvailable = get_numeric_column( ...
        ue_t, {'performance_available'});

    performance = get_numeric_column( ...
        ue_t, {'performance'});

    startDirection = get_numeric_column( ...
        ue_t, {'start_direction', 'startDirection', ...
        'start_angle', 'initial_direction'});

    if isempty(performanceAvailable) || isempty(performance)
        warning('%s: performance 정보가 없습니다.', target);
        continue;
    end

    if isempty(startDirection)
        warning('%s: start_direction 정보가 없습니다.', target);
        startDirection = nan(nTrialTotal,1);
    end

    performanceAvailable = performanceAvailable(:);
    performance          = performance(:);
    startDirection       = startDirection(:);

    % 길이 맞추기
    performanceAvailable = resize_vector( ...
        performanceAvailable, nTrialTotal, NaN);

    performance = resize_vector( ...
        performance, nTrialTotal, NaN);

    startDirection = resize_vector( ...
        startDirection, nTrialTotal, NaN);

    %% Valid trial 및 correctness
    validMask = performanceAvailable == 1 & ...
        ismember(performance, [1, 2]);

    % correct=1, incorrect=0
    outcome = nan(nTrialTotal,1);
    outcome(validMask) = performance(validMask) == 1;

    validTrialIndex = find(validMask);
    nValid = numel(validTrialIndex);

    if nValid == 0
        warning('%s: valid trial이 없습니다.', target);
        continue;
    end

    correctness = mean(outcome(validMask), 'omitnan') * 100;

    %% 현재 세션 goal
sessionRow = string(session_list.rat) == string(rat) & ...
             str2double(string(session_list.ss)) == ss;

if ~any(sessionRow)
    warning('%s: session_info에서 goal을 찾지 못했습니다.', target);
    currentGoal = "Unknown";
else
    currentGoal = string(session_list.goal(find(sessionRow, 1)));
end

%% Easy / Difficult 분류
startDirection360 = mod(startDirection, 360);

northMask = startDirection360 == 90;
southMask = startDirection360 == 270;

switch lower(currentGoal)
    case "west"
        easyMask      = validMask & southMask;
        difficultMask = validMask & northMask;

    case "east"
        easyMask      = validMask & northMask;
        difficultMask = validMask & southMask;

    otherwise
        easyMask      = false(nTrialTotal,1);
        difficultMask = false(nTrialTotal,1);

        warning('%s: goal 값이 올바르지 않습니다: %s', ...
            target, currentGoal);
end

allTrialIndex       = find(validMask);
easyTrialIndex      = find(easyMask);
difficultTrialIndex = find(difficultMask);


    %% Figure 생성
    f = figure( ...
        'Color', 'w', ...
        'Position', [50, 30, 1400, 1050], ...
        'Visible', 'on');

    tiledlayout(f, 3, 2, ...
        'TileSpacing', 'compact', ...
        'Padding', 'compact');

    % -----------------------------------------------------
    % Row 1: All trials
    % -----------------------------------------------------
    nexttile(1);

    [acquisitionAll, stagesAll] = plot_learning_curve( ...
        outcome(allTrialIndex), ...
        CURVE.window, ...
        CURVE.alpha, ...
        COLOR.All, ...
        CURVE.showRawOutcome, ...
        CURVE.displaySmoothSpan, ...
        CURVE.chanceLevel, ...
        CURVE.minTransitionHold, ...
        CURVE.minPostHold, ...
        CURVE.postAccuracy, ...
        CURVE.minPostTrials, ...
        STAGE_COLOR);

    title(make_learning_panel_title('All trials', ...
        outcome(allTrialIndex), acquisitionAll, allTrialIndex, ...
        stagesAll));

    nexttile(2);

    plot_trajectories( ...
        ue, allTrialIndex, Maze, RewardZone, currentGoal);

    title(make_panel_title('All trajectories', ...
        outcome(allTrialIndex)));

    % -----------------------------------------------------
    % Row 2: Easy trials
    % -----------------------------------------------------
    nexttile(3);

    [acquisitionEasy, stagesEasy] = plot_learning_curve( ...
        outcome(easyTrialIndex), ...
        CURVE.window, ...
        CURVE.alpha, ...
        COLOR.Easy, ...
        CURVE.showRawOutcome, ...
        CURVE.displaySmoothSpan, ...
        CURVE.chanceLevel, ...
        CURVE.minTransitionHold, ...
        CURVE.minPostHold, ...
        CURVE.postAccuracy, ...
        CURVE.minPostTrials, ...
        STAGE_COLOR);

    title(make_learning_panel_title('Easy trials', ...
        outcome(easyTrialIndex), acquisitionEasy, easyTrialIndex, ...
        stagesEasy));

    nexttile(4);

    plot_trajectories( ...
        ue, easyTrialIndex, Maze, RewardZone, currentGoal);

    title(make_panel_title('Easy trajectories', ...
        outcome(easyTrialIndex)));

    % -----------------------------------------------------
    % Row 3: Difficult trials
    % -----------------------------------------------------
    nexttile(5);

    [acquisitionDifficult, stagesDifficult] = plot_learning_curve( ...
        outcome(difficultTrialIndex), ...
        CURVE.window, ...
        CURVE.alpha, ...
        COLOR.Difficult, ...
        CURVE.showRawOutcome, ...
        CURVE.displaySmoothSpan, ...
        CURVE.chanceLevel, ...
        CURVE.minTransitionHold, ...
        CURVE.minPostHold, ...
        CURVE.postAccuracy, ...
        CURVE.minPostTrials, ...
        STAGE_COLOR);

    title(make_learning_panel_title('Difficult trials', ...
        outcome(difficultTrialIndex), acquisitionDifficult, ...
        difficultTrialIndex, stagesDifficult));

    nexttile(6);

    plot_trajectories( ...
        ue, difficultTrialIndex, Maze, RewardZone, currentGoal);

    title(make_panel_title('Difficult trajectories', ...
        outcome(difficultTrialIndex)));

    %% 전체 제목
    figureTitle = sprintf( ...
        'Rat %s | ss %d | trials %d | correctness %.1f%% | goal %s', ...
        rat, ss, nValid, correctness, currentGoal);

    sgtitle(figureTitle, ...
        'FontSize', 16, ...
        'FontWeight', 'bold', ...
        'Interpreter', 'none');

    %% 저장
    ratFolder = fullfile(ROOT.Save, ['LE' rat]);

    if ~exist(ratFolder, 'dir')
        mkdir(ratFolder);
    end

    outputBase = sprintf( ...
        '%s_ss%02d_n%d_correct%.1f_goal%s', ...
        rat, ss, nValid, correctness, currentGoal);

    % 파일 이름에서 소수점 제거
    outputBase = strrep(outputBase, '.', 'p');

    if SAVE.jpg
        exportgraphics(f, ...
            fullfile(ratFolder, [outputBase '.jpg']), ...
            'Resolution', 300);
    end

    if SAVE.pdf
        exportgraphics(f, ...
            fullfile(ratFolder, [outputBase '.pdf']), ...
            'ContentType', 'vector');
    end

    if SAVE.closeFigure
        close(f);
    end
end

fprintf('\n분석 완료\n저장 위치:\n%s\n', ROOT.Save);

%% =========================================================
%  Local functions
%% =========================================================

function value = get_numeric_column(data, candidateNames)
% Table 또는 structure에서 후보 변수명을 순서대로 검색

value = [];

if istable(data)
    availableNames = data.Properties.VariableNames;

    for i = 1:numel(candidateNames)
        idx = find(strcmpi(availableNames, ...
            candidateNames{i}), 1);

        if ~isempty(idx)
            value = data.(availableNames{idx});

            if iscell(value)
                value = str2double(string(value));
            elseif iscategorical(value) || isstring(value)
                value = str2double(string(value));
            end

            value = double(value);
            return;
        end
    end

elseif isstruct(data)
    availableNames = fieldnames(data);

    for i = 1:numel(candidateNames)
        idx = find(strcmpi(availableNames, ...
            candidateNames{i}), 1);

        if ~isempty(idx)
            value = data.(availableNames{idx});

            if iscell(value)
                value = str2double(string(value));
            elseif iscategorical(value) || isstring(value)
                value = str2double(string(value));
            end

            value = double(value);
            return;
        end
    end
end
end

function value = resize_vector(value, targetLength, fillValue)

value = value(:);

if numel(value) < targetLength
    value(end+1:targetLength,1) = fillValue;

elseif numel(value) > targetLength
    value = value(1:targetLength);
end
end


function distance = angular_difference(angle1, angle2)

distance = abs(mod(angle1 - angle2 + 180, 360) - 180);
end

function [acquisitionTrial, stages] = plot_learning_curve( ...
    outcome, windowSize, alpha, lineColor, showRawOutcome, ...
    displaySmoothSpan, chanceLevel, minTransitionHold, ...
    minPostHold, postAccuracy, minPostTrials, STAGE_COLOR)
% MATLAB-only moving beta-binomial learning curve
%
% outcome:
%   1 = correct
%   0 = incorrect
%
% acquisitionTrial:
%   First group-trial position at which the UNSMOOTHED lower bound of the
%   90% credible interval exceeds chanceLevel.

outcome = outcome(:);
outcome = outcome(isfinite(outcome));

nTrial = numel(outcome);
acquisitionTrial = NaN;
stages = struct('preStart', NaN, 'ruleStart', NaN, ...
    'postStart', NaN);

hold on;

if nTrial == 0
    axis([0, 1, 0, 1]);
    text(0.5, 0.5, 'No trials', ...
        'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'middle', ...
        'Color', [0.4, 0.4, 0.4], ...
        'FontSize', 12);

    xlabel('Trial within group');
    ylabel('P(correct)');
    box off;
    return;
end

x = (1:nTrial)';

windowSize = max(1, round(windowSize));
halfWindow = floor(windowSize / 2);

probability = nan(nTrial,1);
lowerCI     = nan(nTrial,1);
upperCI     = nan(nTrial,1);

for iTrial = 1:nTrial

    firstTrial = max(1, iTrial - halfWindow);
    lastTrial  = min(nTrial, iTrial + halfWindow);

    localOutcome = outcome(firstTrial:lastTrial);

    nCorrect = sum(localOutcome == 1);
    nLocal   = numel(localOutcome);

    % Jeffreys beta prior: Beta(0.5, 0.5)
    posteriorA = nCorrect + 0.5;
    posteriorB = nLocal - nCorrect + 0.5;

    probability(iTrial) = posteriorA / ...
        (posteriorA + posteriorB);

    lowerCI(iTrial) = betaincinv( ...
        alpha/2, posteriorA, posteriorB);

    upperCI(iTrial) = betaincinv( ...
        1-alpha/2, posteriorA, posteriorB);
end

% Acquisition is determined from the original interval, before the
% additional display-only Gaussian smoothing below.
acquisitionTrial = find(lowerCI > chanceLevel, 1, 'first');

if isempty(acquisitionTrial)
    acquisitionTrial = NaN;
end

%% Detect ordered learning-stage onsets
stages = detect_learning_stages( ...
    outcome, lowerCI, upperCI, chanceLevel, ...
    minTransitionHold, minPostHold, ...
    postAccuracy, minPostTrials);

%% Gaussian smoothing for display only
smoothSpan = min(max(1, round(displaySmoothSpan)), nTrial);

if mod(smoothSpan, 2) == 0
    smoothSpan = smoothSpan - 1;
end

if smoothSpan >= 3
    probabilityPlot = smoothdata(probability, 'gaussian', smoothSpan);
    lowerCIPlot     = smoothdata(lowerCI,     'gaussian', smoothSpan);
    upperCIPlot     = smoothdata(upperCI,     'gaussian', smoothSpan);
else
    probabilityPlot = probability;
    lowerCIPlot     = lowerCI;
    upperCIPlot     = upperCI;
end

probabilityPlot = min(max(probabilityPlot, 0), 1);
lowerCIPlot     = min(max(lowerCIPlot, 0), 1);
upperCIPlot     = min(max(upperCIPlot, 0), 1);

% Credible interval
fill([x; flipud(x)], ...
    [lowerCIPlot; flipud(upperCIPlot)], ...
    lineColor, ...
    'FaceAlpha', 0.18, ...
    'EdgeColor', 'none');

% 50% 기준선
yline(chanceLevel, 'k--', ...
    'LineWidth', 0.8, ...
    'HandleVisibility', 'off');

% Learning-stage onset lines and acquisition candidate
draw_onset_line(stages.preStart, ':', 'Pre', ...
    STAGE_COLOR.Pre, 1.2);
draw_onset_line(stages.ruleStart, '--', 'Rule', ...
    STAGE_COLOR.Rule, 1.5);
draw_onset_line(acquisitionTrial, ':', 'Acq', ...
    STAGE_COLOR.Acquisition, 1.6);
draw_onset_line(stages.postStart, '-.', 'Post', ...
    STAGE_COLOR.Post, 1.8);

% 개별 trial outcome
if showRawOutcome
    correctIndex   = outcome == 1;
    incorrectIndex = outcome == 0;

    % Incorrect trials: gray dots at the bottom
    scatter(x(incorrectIndex), ...
        0.025 * ones(sum(incorrectIndex), 1), 15, ...
        'MarkerFaceColor', [0.65, 0.65, 0.65], ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.65);

    % Correct trials: red dots at the top
    scatter(x(correctIndex), ...
        0.975 * ones(sum(correctIndex), 1), 15, ...
        'MarkerFaceColor', [0.90, 0.15, 0.15], ...
        'MarkerEdgeColor', 'none', ...
        'MarkerFaceAlpha', 0.75);
end

% Learning curve
plot(x, probabilityPlot, ...
    '-', ...
    'Color', lineColor, ...
    'LineWidth', 2);

% Marker on the displayed curve at acquisition
if isfinite(acquisitionTrial)
    plot(acquisitionTrial, probabilityPlot(acquisitionTrial), ...
        'o', ...
        'MarkerSize', 7, ...
        'MarkerFaceColor', STAGE_COLOR.Acquisition, ...
        'MarkerEdgeColor', 'w', ...
        'LineWidth', 1.0);
end

% Mark Rule and Post onsets on the displayed curve
if isfinite(stages.ruleStart)
    plot(stages.ruleStart, probabilityPlot(stages.ruleStart), ...
        's', 'MarkerSize', 7, ...
        'MarkerFaceColor', STAGE_COLOR.Rule, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1.0);
end

if isfinite(stages.postStart)
    plot(stages.postStart, probabilityPlot(stages.postStart), ...
        'd', 'MarkerSize', 7, ...
        'MarkerFaceColor', STAGE_COLOR.Post, ...
        'MarkerEdgeColor', 'w', 'LineWidth', 1.0);
end

xlim([0.5, nTrial + 0.5]);
ylim([0, 1]);

if nTrial == 1
    xticks(1);
else
    xticks(unique([1, round(nTrial/2), nTrial]));
end

yticks([0, 0.5, 1]);

xlabel('Trial within group');
ylabel('P(correct)');

set(gca, ...
    'FontSize', 10, ...
    'TickDir', 'out', ...
    'Box', 'off');
end

function plot_trajectories(ue, selectedTrialIndex, ...
    Maze, RewardZone, sessionGoal)

trialNumber = get_numeric_column( ...
    ue, {'trial', 'trial_number', 'trialNumber'});

positionX = get_numeric_column( ...
    ue, {'position_x', 'positionX', 'x'});

positionY = get_numeric_column( ...
    ue, {'position_y', 'positionY', 'y'});

frameITI = get_numeric_column( ...
    ue, {'frame_ITI', 'frame_iti'});

rewardArrival = get_numeric_column( ...
    ue, {'rewardzone_arrival', 'rewardZoneArrival'});

hold on;
axis equal;

if isempty(trialNumber) || ...
        isempty(positionX) || isempty(positionY)

    axis([-1, 1, -1, 1]);

    text(0, 0, 'Trajectory data unavailable', ...
        'HorizontalAlignment', 'center');

    axis off;
    return;
end

trialNumber = trialNumber(:);
positionX   = positionX(:);
positionY   = positionY(:);

if isempty(frameITI)
    frameITI = zeros(size(trialNumber));
else
    frameITI = frameITI(:);
end

if isempty(rewardArrival)
    rewardArrival = zeros(size(trialNumber));
else
    rewardArrival = rewardArrival(:);
end

%% Maze outline
theta = linspace(0, 2*pi, 500);

plot( ...
    Maze.center(1) + Maze.radius*cos(theta), ...
    Maze.center(2) + Maze.radius*sin(theta), ...
    'k-', ...
    'LineWidth', 0.9);

%% Reward zones
if strcmp(sessionGoal, 'West')
    westColor = [0.85, 0.10, 0.10];
    eastColor = [0.55, 0.70, 0.95];

elseif strcmp(sessionGoal, 'East')
    westColor = [0.95, 0.60, 0.60];
    eastColor = [0.10, 0.30, 0.90];

else
    westColor = [0.85, 0.10, 0.10];
    eastColor = [0.10, 0.30, 0.90];
end

draw_reward_zone( ...
    RewardZone.West.center, ...
    RewardZone.innerRadius, ...
    RewardZone.outerRadius, ...
    RewardZone.halfWidth, ...
    westColor);

draw_reward_zone( ...
    RewardZone.East.center, ...
    RewardZone.innerRadius, ...
    RewardZone.outerRadius, ...
    RewardZone.halfWidth, ...
    eastColor);

%% Trial trajectories
for i = 1:numel(selectedTrialIndex)

    trialID = selectedTrialIndex(i);

    idx = trialNumber == trialID & ...
        frameITI == 0 & ...
        rewardArrival == 0 & ...
        isfinite(positionX) & ...
        isfinite(positionY);

    X = positionX(idx);
    Y = positionY(idx);

    if isempty(X)
        continue;
    end

    plot(X, Y, ...
        '-', ...
        'Color', [0.72, 0.72, 0.72], ...
        'LineWidth', 0.8);

    % 시작점
    plot(X(1), Y(1), ...
        '.', ...
        'Color', [0.15, 0.60, 0.20], ...
        'MarkerSize', 8);

    % 종료점
    plot(X(end), Y(end), ...
        '.', ...
        'Color', [0.90, 0.10, 0.10], ...
        'MarkerSize', 10);
end

xlim([-1, 1]);
ylim([-1, 1]);

axis off;
end

function draw_reward_zone(centerPosition, innerRadius, ...
    outerRadius, halfWidthDegree, colorValue)

centerAngle = atan2d(centerPosition(2), centerPosition(1));

zoneAngle = linspace( ...
    centerAngle-halfWidthDegree, ...
    centerAngle+halfWidthDegree, 100);

innerX = innerRadius * cosd(zoneAngle);
innerY = innerRadius * sind(zoneAngle);

outerX = outerRadius * cosd(zoneAngle);
outerY = outerRadius * sind(zoneAngle);

% 투명한 reward-zone 영역
patch( ...
    [innerX, fliplr(outerX)], ...
    [innerY, fliplr(outerY)], ...
    colorValue, ...
    'FaceAlpha', 0.10, ...
    'EdgeColor', 'none');

plot(innerX, innerY, ...
    '-', 'Color', colorValue, 'LineWidth', 1.2);

plot(outerX, outerY, ...
    '-', 'Color', colorValue, 'LineWidth', 1.2);

plot([innerX(1), outerX(1)], ...
    [innerY(1), outerY(1)], ...
    '-', 'Color', colorValue, 'LineWidth', 1.2);

plot([innerX(end), outerX(end)], ...
    [innerY(end), outerY(end)], ...
    '-', 'Color', colorValue, 'LineWidth', 1.2);
end

function panelTitle = make_panel_title(label, outcome)

outcome = outcome(isfinite(outcome));
nTrial = numel(outcome);

if nTrial == 0
    panelTitle = sprintf('%s | n = 0', label);
else
    accuracy = mean(outcome) * 100;

    panelTitle = sprintf( ...
        '%s | n = %d | %.1f%% correct', ...
        label, nTrial, accuracy);
end
end

function panelTitle = make_learning_panel_title(label, outcome, ...
    acquisitionTrial, originalTrialIndex, stages)

outcome = outcome(isfinite(outcome));
nTrial = numel(outcome);

if nTrial == 0
    panelTitle = sprintf('%s | n = 0 | no stages', label);
    return;
end

accuracy = mean(outcome) * 100;

preText  = format_onset(stages.preStart, originalTrialIndex);
ruleText = format_onset(stages.ruleStart, originalTrialIndex);
acqText  = format_onset(acquisitionTrial, originalTrialIndex);
postText = format_onset(stages.postStart, originalTrialIndex);

panelTitle = sprintf( ...
    ['%s | n = %d | %.1f%% correct\n', ...
     'Start [group/original]: Pre %s | Rule %s | Acq %s | Post %s'], ...
    label, nTrial, accuracy, preText, ruleText, acqText, postText);
end

function stages = detect_learning_stages(outcome, lowerCI, upperCI, ...
    chanceLevel, minTransitionHold, minPostHold, ...
    postAccuracy, minPostTrials)
% Ordered stage model:
%   Pre -> Rule-updating -> Post
% Any stage can be absent.

nTrial = numel(outcome);
stages = struct('preStart', NaN, 'ruleStart', NaN, ...
    'postStart', NaN);

if nTrial == 0
    return;
end

minTransitionHold = max(1, round(minTransitionHold));
minPostHold = max(1, round(minPostHold));
minPostTrials = max(1, round(minPostTrials));

% Candidate Rule onset: first sustained point at which the upper bound
% reaches or exceeds chance. Before this, performance is confidently low.
ruleCandidate = first_sustained_true( ...
    upperCI >= chanceLevel, minTransitionHold);

% Stable Post onset: lower bound stays above chance, enough trials remain,
% and raw accuracy from that point to session end is at least the threshold.
postCandidate = NaN;

for t = 1:nTrial
    nRemaining = nTrial - t + 1;
    holdEnd = t + minPostHold - 1;

    if nRemaining < minPostTrials || holdEnd > nTrial
        continue;
    end

    lowerBoundMaintained = all(lowerCI(t:holdEnd) > chanceLevel);
    subsequentAccuracy = mean(outcome(t:end), 'omitnan');

    if lowerBoundMaintained && subsequentAccuracy >= postAccuracy
        postCandidate = t;
        break;
    end
end

% Enforce the ordered progression and allow stages to be absent.
if isfinite(postCandidate) && postCandidate == 1
    stages.postStart = 1;
    return;
end

if isfinite(postCandidate)
    stages.postStart = postCandidate;

    if ~isfinite(ruleCandidate) || ruleCandidate >= postCandidate
        % Direct transition: Pre -> Post, with no identifiable Rule period.
        stages.preStart = 1;
        stages.ruleStart = NaN;
    elseif ruleCandidate == 1
        % Rule from the beginning, so Pre is absent.
        stages.preStart = NaN;
        stages.ruleStart = 1;
    else
        stages.preStart = 1;
        stages.ruleStart = ruleCandidate;
    end
else
    % No stable Post period in this session/group.
    if isfinite(ruleCandidate)
        if ruleCandidate == 1
            stages.preStart = NaN;
            stages.ruleStart = 1;
        else
            stages.preStart = 1;
            stages.ruleStart = ruleCandidate;
        end
    else
        % Performance remained confidently low throughout.
        stages.preStart = 1;
    end
end
end

function firstIndex = first_sustained_true(logicalVector, holdLength)
logicalVector = logicalVector(:);
nPoint = numel(logicalVector);
firstIndex = NaN;

if nPoint < holdLength
    return;
end

for i = 1:(nPoint - holdLength + 1)
    if all(logicalVector(i:i+holdLength-1))
        firstIndex = i;
        return;
    end
end
end

function draw_onset_line(trialPosition, lineStyle, lineLabel, ...
    lineColor, lineWidth)

if ~isfinite(trialPosition)
    return;
end

xline(trialPosition, lineStyle, lineLabel, ...
    'Color', lineColor, ...
    'LineWidth', lineWidth, ...
    'LabelOrientation', 'horizontal', ...
    'LabelVerticalAlignment', 'middle', ...
    'HandleVisibility', 'off');
end

function onsetText = format_onset(groupTrial, originalTrialIndex)
if isfinite(groupTrial)
    originalTrial = originalTrialIndex(groupTrial);
    onsetText = sprintf('%d/%d', groupTrial, originalTrial);
else
    onsetText = 'none';
end
end
