function [cheetah, ue, ue_t, encoder] = behavior_extraction_function(raw_root, mother_root, ss_id)
%% Info
% 2024-05-14 modified by LHY

% raw_root = ROOT.Raw;
% mother_root = ROOT.Mother;
% ss_id = ss_id;


%%
% annotations from previous function
% 2022 Sep 08 PSW
% 2022 Oct 08 PSW, rate map data 대신 angular data
% 2023 Jan 25 (SJM)

% Input
% mother_root   / raw position data directory
% Events.csv    /   Neuralynx event log
% LE#_session#.csv  /   Unreal event log

% Output
    % ss_data -> 한 session에서 UE / Cheetah / Encoder의 데이터를 가공한 다양한 behavioral data를 하나의 struct 안에 저장 
    
    % processed/mat files
        % ###-#-#-#_ue.mat
            % 'ue_arriving_angle', 'ue_departing_angle_location', 'ue_departing_angle_velocity', 'ue_edge', 'ue_EdgeDistance', 'ue_flag',
            % 'ue_FrameofITI', 'ue_head_direction', 'ue_highvaluezone', 'ue_ITI', 'ue_latency', 'ue_outlier', 'ue_PercentofEdgeNav', 
            % 'ue_performance', 'ue_position','ue_RewardzoneArrival', 'ue_start_direction', 'ue_stop', 'ue_timestamp', 'ue_traveldistance', 'ue_trial', 
            % 'ue_trial_ITIstart', 'ue_trial_start', 'ue_Trialend', 'ue_Trialend_ITI', 'ue_Trialstart', 'ue_Trialstart_ITI', 'ue_velocity'
        % ###-#-#-#_spk.mat
            %  'tick_timestamp', 'cueonset_timestamp', 'trial_timestamp', 'HighValue_timestamp', 'LowValue_timestamp', 'NStart_timestamp', 'SStart_timestamp',
            % 'spk_timestamp_main', 'spk_position_main', 'spk_dir_main', 'spk_frame', 'spk_trial_main', 'spk_flag', 'spk_timestamp_edit', 'spk_velocity', 'spk_velocity_500ms', 
            % 'spk_encoder_velocity_500ms', 'spk_ang_velocity_500ms', 'spk_available_frame', 'FRRate_bin', 'mean_fr_behavior', 'n_spk_behavior', 'mean_fr_onmaze', 'mean_fr_includeITI', 
            % 'mean_fr_onmaze_vel5', 'numofspk', 'numofspk_includeITI', 'numofspk_vel5', 'spk_dir_encoder_vel_500ms', 'dir_r_score_spk', 'p_value_r_shuffle_spk'
        % ###-#-#-#_placeinfo.mat
            % 'MaxFR_location', 'CenterofMass', 'p_value_shuffle', 'spainfo_score_shuffle','skaggsrateMat_encoder', 
            % 'SpaInfoScore_encoder', 'MaxFR_skaggs_encoder', 'PlaceField', 'skaggsMap_field', 'PlaceField_ue', 'skaggsMap_field_ue', 'PlaceField_size'
        % ###-#-#-#_data_table.mat
            % 'ue_frame_data', 'ue_trial.data', 'spk_frame_data'
        % ###-#-#-#_direction.mat
            % 'p_value_angle', 'mu_angle', 'r_angle', 'x_location_angle', 'y_location_angle'
    % processed/figures
        % /Basic Properties/rat#-#-#-#_basic properties.png   /   cell basic firing property
        % /individual/rat#-#/rat#-#-#-#-from trial#.png    /   trial-by-trial spike position plot
        % /(No)Direction/rat#-#-#-#_spike direction.png   /   skaggs ratemap (place, HD)
    

% Module
    % disassemble_id_4zz.m 
    % get_ue_spk_position.m
    % get_SpatialInfo_2DVR.m
    % GetSparsity.m
    % GetSelectivity.m
    % calc_spainfo_p_function_4a4.m
    % cell_profiling_display_1Dgraph.m
    % cell_profiling_display_properties.m
    % cell_profiling_display_individual.m

%%

% Read spk/ue/encoder file
% spk: behavior session 제한하여 property 확인
% ue: main task 분석 시 사용할 ue data 확인 및 필요 data 추가
% encoder: 속도 제한 관련하여 velocity 확인

%% Root setting

ROOT.Mother = 'D:';
ROOT.Raw = '\1. Behavioral data';
ROOT.Info = [ROOT.Raw '\info'];

addpath(genpath(ROOT.Mother))

today = char(datetime('today'));

% session ID 
% rat data loop
rat_list = {'774', '779', '780', '781', '816', '817'};
for r = 1:length(rat_list)
    rat_ss = session_list(strcmp(session_list.rat,rat_list{r}),:);
end 
    % session loop 
    for s = 1:size(rat_ss,1)
        rat = rat_ss.rat{s};
        ss = rat_ss.ss{s};
        formattedSS = sprintf('%02d', str2double(ss));
    end 

%% Load session info

load([ROOT.Info '\session_info.mat']);

%% Path & Parameter setting
ss_id = [rat '-' ss];
ss_info = split(ss_id, '-');
rat = ss_info{1};
ss = ss_info{2};
ss = num2str(str2double(ss)); % delete zero '01'->'1'
% mother_root = ROOT.Mother
raw_root = [ROOT.Mother '\2. Neural data\raw data'];


session_root = [raw_root '\LE' rat '\rat' rat '-'  ss];
%info_root = [raw_root '\info'];
%UE_session_root= [ROOT.Raw '\results\Behavior\15-May-2024\LE' rat '-' ss];

%grade=get_grade_4zz(info_root, cluster_id);

% basic parameters
sampling_margin = 0.04; % difference between spike and its nearest position timestamp

sFr = 1 / 32000;
microSEC = 10^6;
threshold_sd = 2; % mean + x*std에 사용됨


%% read epoch timestamp
epoch_file = [raw_root '\recording_timestamp.xlsx']; 

temp = readcell(epoch_file);
temp(1, :) = [];

epoch_timestamp = [];
for iter = 1 : size(temp, 1)
    if strcmp(temp{iter, 1}, ss_id) %ss_id(session_list)에 있는 유효파일만

        %1st row = presleep 
        %2nd row = behaviour
        %3rd row = postsleep
        epoch_timestamp(1, 1) = temp{iter, 2}; %presleep_start
        epoch_timestamp(1, 2) = temp{iter, 3}; %presleep_end 
        epoch_timestamp(2, 1) = temp{iter, 4}; %behaviour_start
        epoch_timestamp(2, 2) = temp{iter, 5}; %behaviour_end
        epoch_timestamp(3, 1) = temp{iter, 6}; %postsleep_start
        epoch_timestamp(3, 2) = temp{iter, 7}; %postsleep_end
        break;
    end
end

epoch_timestamp = epoch_timestamp / 10^6; %sec로 환산?

%% Read Event file
event_filename = [session_root '\Events.csv'];
formatSpec = '%*s%*s%*s%f%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%s%[^\n\r]';
event_fid = fopen(event_filename, 'r');

event_data = textscan(event_fid, formatSpec, 'Delimiter', ',');
fclose(event_fid);

event_timestamp = event_data{1};
event_ttl = event_data{2};

str1 = 'TTL Input on AcqSystem1_0 board 0 port 1 value (0x0002).'; % frame tick signal
str2 = 'TTL Input on AcqSystem1_0 board 0 port 1 value (0x0001).'; % cue onset
str3 = 'TTL Input on AcqSystem1_0 board 0 port 0 value (0x0080).'; % trial onset
str4 = 'TTL Input on AcqSystem1_0 board 0 port 0 value (0x0040).'; % high value zone arrival
str5 = 'TTL Input on AcqSystem1_0 board 0 port 0 value (0x0020).'; % low value zone arrival
str6 = 'TTL Input on AcqSystem1_0 board 0 port 0 value (0x0010).'; % North start
str7 = 'TTL Input on AcqSystem1_0 board 0 port 0 value (0x0008).'; % South start

% %
tick_index = strcmp(event_ttl, str1);
tick_timestamp = event_timestamp(tick_index);
tick_timestamp = tick_timestamp ./ 1000000;  % convert to second

cueonset_index = strcmp(event_ttl, str2);
cueonset_timestamp = event_timestamp(cueonset_index);
cueonset_timestamp = cueonset_timestamp ./ 1000000;  % convert to second

trial_index = strcmp(event_ttl, str3);
trial_timestamp = event_timestamp(trial_index);
trial_timestamp = trial_timestamp ./ 1000000;  % convert to second

HighValue_index = strcmp(event_ttl, str4);
HighValue_timestamp = event_timestamp(HighValue_index);
HighValue_timestamp = HighValue_timestamp ./ 1000000;  % convert to second

LowValue_index = strcmp(event_ttl, str5);
LowValue_timestamp = event_timestamp(LowValue_index);
LowValue_timestamp = LowValue_timestamp ./ 1000000;  % convert to second

NStart_index = strcmp(event_ttl, str6);
NStart_timestamp = event_timestamp(NStart_index);
NStart_timestamp = NStart_timestamp ./ 1000000;  % convert to second

SStart_index = strcmp(event_ttl, str7);
SStart_timestamp = event_timestamp(SStart_index);
SStart_timestamp = SStart_timestamp ./ 1000000;  % convert to second

% %
temp_index = tick_timestamp < epoch_timestamp(2, 1) | tick_timestamp > epoch_timestamp(2, 2);
tick_timestamp(temp_index) = [];


% %Reward zone location
RewardZone.arch.x=-7715;
RewardZone.arch.y=1552;
RewardZone.house.x=7715;
RewardZone.house.y=-1552;
%

% 5cm bin으로 환산했을 때 reward zone location
% 좌표 -1 to 1을 0 to 2로 바꾸고 120cm diameter/24=5cm bin으로 변경
RewardZone.arch.x_location=round((RewardZone.arch.x+10000)/(20000/24));
RewardZone.arch.y_location=round((RewardZone.arch.y+10000)/(20000/24));
RewardZone.house.x_location=round((RewardZone.house.x+10000)/(20000/24));
RewardZone.house.y_location=round((RewardZone.house.y+10000)/(20000/24));
%


%% Read Unreal Engine log & encoder log
File = [ROOT.Info '\LE' rat '\LE' rat '_Post-main_' ss '.csv'];
%Data=xlsread(File);
Data = readtable(File);

File = [ROOT.Info '\LE' rat '\LE' rat '_Post-main_' ss '_encoder.csv']; % velocity, distance 
%EncoderData=xlsread(File);
EncoderData=readtable(File);

ue_position.main = Data{:,1:2}; %x/y 
ue_timestamp.main = Data{:,3};% C
ue_trial.main = Data{:,4};% D, Trial
ue_reward_zone_arrival = Data{:,5}; %E, Goal/reward phase
ue_head_direction = Data{:,7}; % Head direction
ue_highvaluezone = Data{:,14};
ue_edge = double(strcmp(Data{:, 22}, 'true')); % V
ue_flag = double(strcmp(Data{:, 27}, 'true')); % AA, Stop


%% loading한 ue data로 부터 필요한 정보 추출
% Number of trial (data 받을 때 다음 trial 시작 후 종료하도록 설계)
Numberof = size(ue_timestamp.main,1);
NumberofTrial = ue_trial.main(NumberofFrame)-1;
%

% trial start
ue_Trialstart=[];
for i=2:NumberofFrame
    if ue_trial.main(i)~=ue_trial.main(i-1)
        ue_Trialstart(length(ue_Trialstart)+1,1)=i;
    end
end

while length(ue_Trialstart)>NumberofTrial
    ue_Trialstart(length(ue_Trialstart))=[];
end
%

% Trial end: navigation start 기준으로 trial start & end
for i=1:NumberofTrial
    ue_Trialend(i)=find(ue_trial.main==i & ue_flag==1, 1, 'last');
end
%

% trial (ITI-nav-reward 순으로 변경)
ue_trial.ITIstart=ue_trial.main;

for i=1:NumberofTrial
    % trial start = navigation 시작시점, 5초 전 ITI 구간 포함하도록 변경
    ue_trial.ITIstart(ue_Trialstart(i)-150:ue_Trialstart(i)-1,1)=i;
end
%

% ue_ITI 찾기

ue_FrameofITI=zeros(NumberofFrame,1);
ue_FrameofITI(ue_flag == 1 & ue_reward_zone_arrival==0)=1; %stop + rewardzone 안들어옴
%

% Trial start/end-ITI 기준-Frame 확인

for i=1:NumberofTrial

    %이전 trial 에서 stop; reward zone 안들어간 것 중 첫 frame 
    ue_Trialstart_ITI(i)=find(ue_trial.main==i-1 & ue_FrameofITI==1 & ue_reward_zone_arrival==0, 1, 'first');
    %현재 trial 에서 stop 아님; reward zone 들어간 것 중 마지막 frame 
    ue_Trialend_ITI(i)=find(ue_trial.main==i & ue_FrameofITI==0 & ue_reward_zone_arrival~=0, 1, 'last');

end
%

% Reward zone arrival frame

%reward zone 안에서 움직이는 첫 frame 
for i=1:NumberofTrial
    ue_RewardzoneArrival(i)=find(ue_trial.main == i & ue_FrameofITI == 0 & ue_reward_zone_arrival ~=0, 1, 'first');
end
%

% Start direction

direction=[0 45 90 135 180 225 270 315 360];

for i=1:NumberofTrial

    start_direction_temp=ue_head_direction(ue_Trialstart(i));
    [temp_value, temp_index] = min(abs(direction-start_direction_temp));
     % head direction 하고 차의 절댓값이 가장 작은 것 extract 

    if direction(temp_index)~=360
        ue_start_direction(i)=direction(temp_index);
    elseif direction(temp_index)==360
        ue_start_direction(i)=0;
    end
    % values close to (or equal to) 360 are treated as 0
end

NStart_trial=find(ue_start_direction==90);
SStart_trial=find(ue_start_direction==270);
%

% performance

ue_performance=[];

for i=2:NumberofFrame
    % 이전trial = rewardzone 바깥; 현재trial = rewardzone 안  
    if ue_reward_zone_arrival(i)~=ue_reward_zone_arrival(i-1) & ue_reward_zone_arrival(i-1)==0
        ue_performance(length(ue_performance)+1,1)=ue_reward_zone_arrival(i);
    end

end

while length(ue_performance)>NumberofTrial
    ue_performance(length(ue_performance))=[];
end
%

%available trial (failed trial 제외)
% 2022.12.09 guide trial 제외 추가

dummy_cluster_id = [ss_id '-1'];
guide = get_guide_trial(ROOT.Info, dummy_cluster_id); %get_guide_trial function 없음. 
ue_guide_trial=zeros(NumberofTrial,1);
ue_guide_trial(guide,1)=1;

ue_performance_available=zeros(NumberofTrial,1);

for i=1:NumberofTrial
    % no guide & (performance == 1 or 2)
    if ue_performance(i) == 1 & ue_guide_trial(i) == 0 | ue_performance(i) == 2 & ue_guide_trial(i) == 0
        ue_performance_available(i) = 1;
    end

end
%

%frame별로 사용 가능한 trial인지 구분
ue_performance_available_frame=zeros(NumberofFrame,1);

for i=1:NumberofTrial
    temp=find(ue_trial.main==i);
    if ue_performance(i) == 1
        ue_performance_available_frame(temp,1)=1;
    elseif ue_performance(i) == 2
        ue_performance_available_frame(temp,1)=2;
    else
        ue_performance_available_frame(temp,1)=0;
    end
end
%

% Travel distance

delta_x=diff(ue_position.main(:,1)); delta_y=diff(ue_position.main(:,2));
delta_x=[0; delta_x]; delta_y=[0; delta_y];

delta_position=sqrt(delta_x.^2+delta_y.^2)*.6/9500;
delta_position(ue_Trialstart)=0; %start location으로 이동하면서 튀는 값 제거하기 위해
%

% cumulative distance

ue_cumdistance=zeros(NumberofFrame,1);

for i=1:NumberofTrial
    temp_frame=find(ue_trial.main == i & ue_flag == 0); %움직이는 구간만
    temp_move=delta_position(temp_frame);

    ue_cumdistance(temp_frame,1)=cumsum(temp_move);
end
%

% distance from reward zone
% 각 프레임부터 세션별 목표 reward zone까지의 거리 
for i=1:NumberofFrame
    if ue_highvaluezone(end)==0 %세션 마지막값 = goal
        ue_DistancefromRewardzone(i,1)=sqrt((RewardZone.arch.x-ue_position.main(i,1)).^2+(RewardZone.arch.y-ue_position.main(i,2)).^2)*0.6/9500;
    elseif ue_highvaluezone(end)==1
        ue_DistancefromRewardzone(i,1)=sqrt((RewardZone.house.x-ue_position.main(i,1)).^2+(RewardZone.house.y-ue_position.main(i,2)).^2)*0.6/9500;
    end
end
%

% Edge nav
for i=1:NumberofTrial

    % Trajectory에 기반한 edge proportion
    % Total distance (navigation only - rewardzone, ITI 구간 제외)
    x_temp=ue_position.main(find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0),1);
    y_temp=ue_position.main(find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0),2);

    ue_traveldistance(i)=nansum(sqrt(diff(x_temp).^2+diff(y_temp).^2))*0.6/9500;

    %Edge distance
    FrameofEdge=find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0 & ue_edge==1);
    disconnect=find(diff(FrameofEdge)>1);
    Edgedistance_temp=[];

    if length(disconnect)==0 %edge 구간이 계속 나타날때 
        x_edge_temp=ue_position.main(FrameofEdge,1);
        y_edge_temp=ue_position.main(FrameofEdge,2);
        Edgedistance_temp=nansum(sqrt(diff(x_edge_temp).^2+diff(y_edge_temp).^2))*0.6/9500;
    elseif length(disconnect)~=0 %edge 가 끊겨서 나타날때 
        for j=1:length(disconnect)+1
            if j==1
                x_edge_temp=ue_position.main(FrameofEdge(1:disconnect(j)),1);
                y_edge_temp=ue_position.main(FrameofEdge(1:disconnect(j)),2);
                Edgedistance_temp=(nansum(sqrt(diff(x_edge_temp).^2+diff(y_edge_temp).^2))*0.6/9500);
            elseif j==length(disconnect)+1
                x_edge_temp=ue_position.main(FrameofEdge(disconnect(j-1)+1:length(FrameofEdge)),1);
                y_edge_temp=ue_position.main(FrameofEdge(disconnect(j-1)+1:length(FrameofEdge)),2);
                Edgedistance_temp=(nansum(sqrt(diff(x_edge_temp).^2+diff(y_edge_temp).^2))*0.6/9500)+Edgedistance_temp;
            else
                x_edge_temp=ue_position.main(FrameofEdge(disconnect(j-1)+1:disconnect(j)),1);
                y_edge_temp=ue_position.main(FrameofEdge(disconnect(j-1)+1:disconnect(j)),2);
                Edgedistance_temp=(nansum(sqrt(diff(x_edge_temp).^2+diff(y_edge_temp).^2))*0.6/9500)+Edgedistance_temp;
            end
        end
    end

    ue_EdgeDistance(i)=Edgedistance_temp; % trial 내에 edge 이동거리 총합

    ue_PercentofEdgeNav(i,1)=round(ue_EdgeDistance(i)/ue_traveldistance(i)*100); % percentage 

end
%

% distance mean and std

mean_traveldistance=mean(ue_traveldistance,2);
mean_traveldistance_north=mean(ue_traveldistance(NStart_trial),2);
mean_traveldistance_south=mean(ue_traveldistance(SStart_trial),2);

sd=std(ue_traveldistance);
sd_north=std(ue_traveldistance(NStart_trial));
sd_south=std(ue_traveldistance(SStart_trial));

ue_outlier=zeros(NumberofTrial,1); % north/south 구분
for i=1:NumberofTrial
    if length(find(i==NStart_trial))~=0 & ue_traveldistance(i) > mean_traveldistance_north + threshold_sd*sd_north; % north start, outlier
        ue_outlier(i,1)=1;
    elseif length(find(i==SStart_trial))~=0 & ue_traveldistance(i) > mean_traveldistance_south + threshold_sd*sd_south; % south start, outlier
        ue_outlier(i,1)=1;
    end
end

ue_outlier_distance=zeros(NumberofTrial,1);
ue_outlier_distance(find(ue_traveldistance > mean_traveldistance + threshold_sd*sd))=1;
%

% travel latency 확인

for i=1:NumberofTrial % ITI 제외; rewardzone가기전 
    ue_latency(i)=length(find(ue_trial.main==i & ue_FrameofITI==0 & ue_reward_zone_arrival==0))*0.033; % latency 기준으로 확인
end

mean_travellatency=mean(ue_latency,2);
mean_travellatency_north=mean(ue_latency(NStart_trial),2);
mean_travellatency_south=mean(ue_latency(SStart_trial),2);

sd_latency=std(ue_latency);
sd_latency_north=std(ue_latency(NStart_trial));
sd_latency_south=std(ue_latency(SStart_trial));

%전체 trial 기준
ue_outlier_latency=zeros(NumberofTrial,1);
ue_outlier_latency(find(ue_latency > mean_travellatency + threshold_sd*sd_latency))=1;

%north/south 구분
ue_outlier_latency_scene=zeros(NumberofTrial,1); % north/south 구분

for i=1:NumberofTrial
    if length(find(i==NStart_trial))~=0 & ue_latency(i) > mean_travellatency_north + threshold_sd*sd_latency_north; % north start, outlier
        ue_outlier_latency_scene(i,1)=1;
    elseif length(find(i==SStart_trial))~=0 & ue_latency(i) > mean_travellatency_south + threshold_sd*sd_latency_south; % south start, outlier
        ue_outlier_latency_scene(i,1)=1;
    end
end
%

% velocity_ue ver.

x_temp=delta_x*0.6*100/9500;  y_temp=delta_y*0.6*100/9500; % 거리 cm로 전환

ue_velocity=sqrt(x_temp.^2 + y_temp.^2)/(1/30); %cm/s
ue_velocity(ue_Trialstart)=0; % trial 시작할 때 position reward zone에서 start location으로 변화하면서 생기는 속도 0으로 변환
%


% departing angle_velocity/location & arriving angle
% LHY: not working, velocity 계산이 뭔가 잘못된듯..?
% LHY: 그냥 ue_velocity 변수를 쓰도록 하는게 맞을듯 (수정 필요)
departing_r=1000;
arriving_r=6500;
maze_r=9500; % 0.6m=9500 UE
for i=1:NumberofTrial

    %navigation 동안의 frame (reward전&ITI아님)
    temp_trial=find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0);
    x_temp=ue_position.main(find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0),1);
    y_temp=ue_position.main(find(ue_trial.main==i & ue_reward_zone_arrival==0 & ue_FrameofITI==0),2);

    %navigation velocity
    distance_temp=sqrt(diff(x_temp).^2+diff(y_temp).^2)*0.6/9500; %m
    distance_temp=distance_temp*100; %cm
    velocity_temp=distance_temp/(1/30); %velocity=cm/s
    
    % 5frame 연속으로 5 cm/s 이상이면 running
    for j=1:length(velocity_temp)-4
        if velocity_temp(j)>=5 & velocity_temp(j+1)>=5 & velocity_temp(j+2)>=5 & velocity_temp(j+3)>=5 & velocity_temp(j+4)>=5
            running_temp(j)=1;
        else 
            running_temp(j)=0;
        end
    end
    
    running_frame=temp_trial(find(running_temp==1,1,'first')+1); %velocity 구할때 diff로 구해서 frame 하나씩 당겨짐 
    
    %departing angle_velocity
    
    if length(running_frame)~=0
        ue_departing_angle_velocity(i)=ue_head_direction(running_frame);
    else
        ue_departing_angle_velocity(i)=nan;
    end
    
    %거리에 따른 departing angle and arriving angle
    %start:1000UE, arrival:6500UE 처음 넘는 frame에서의 head direction 

    CenterDistance=sqrt(x_temp.^2+y_temp.^2);

    departing_frame=temp_trial(find(CenterDistance>1000, 1, 'first'));
    arriving_frame=temp_trial(find(CenterDistance>6500, 1, 'first'));

    % departing angle_location & arriving angle

    if length(departing_frame)~=0
        ue_departing_angle_location(i)=ue_head_direction(departing_frame);
    else
        ue_departing_angle_location(i)=nan;
    end

    if length(arriving_frame)~=0
        ue_arriving_angle(i)=ue_head_direction(arriving_frame);
    else
        ue_arriving_angle(i)=nan;
    end

end

%ue_postion scale down
ue_position.main = ue_position.main ./ 10000; % scale down

%ue_angual velocity
ue_ang_velocity=[0; diff(ue_head_direction)]/0.033;
ue_ang_velocity(ue_Trialstart)=0;

%% load encoder data
encoder_position = EncoderData{:,1:2};

% encoder velocity
Encoder_X=encoder_position(:,1); Encoder_Y=encoder_position(:,2);

encoder_distance=(sqrt(Encoder_X.^2+Encoder_Y.^2))/1024*3.5*3.14/100; % (m), encoder spec:360 degree=1024 pulse & sponge = diameter 3.5cm
encoder_velocity=(encoder_distance*100)/0.033; %cm/s
encoder_degree = atand(Encoder_X./Encoder_Y); %각도 변화(degree)
encoder_angspeed = encoder_degree/0.033;
%

% 속도 smoothing
Bin_300ms=10/2; Bin_500ms=floor(15/2); Bin_1000ms=30/2;

ue_velocity_smoothing_500ms=zeros(NumberofFrame,1);
ue_ang_velocity_smoothing_500ms=zeros(NumberofFrame,1);
encoder_velocity_smoothing_500ms=zeros(NumberofFrame,1);


for i=1:NumberofFrame
    if ue_flag(i) == 0
        %500ms bin
        if i+Bin_500ms > NumberofFrame
            temp_500ms = (i-Bin_500ms) : NumberofFrame;
        else
            temp_500ms = (i-Bin_500ms) : (i+Bin_500ms);
        end
        temp_500ms(find(ue_flag(temp_500ms)==1))=[]; % Navigation 아닌 구간은 제외
        ue_velocity_smoothing_500ms(i)=mean(ue_velocity(temp_500ms),1);
        ue_ang_velocity_smoothing_500ms(i)=mean(ue_ang_velocity(temp_500ms),1);
        encoder_velocity_smoothing_500ms(i)=mean(encoder_velocity(temp_500ms),1);
    end
end

% ue trial time(tick 기준)
for i=1:NumberofFrame
    ue_time(i,1)=i*(1/30);
end

% average speed for each trial
for i=1:NumberofTrial
    ue_avg_speed(i) = mean(ue_velocity_smoothing_500ms(ue_Trialstart(i):ue_RewardzoneArrival(i)));
end

%% Check data validity
if length(tick_timestamp) ~= length(ue_timestamp.main) || length(ue_timestamp.main) ~= length(ue_position.main)
    error('data mismatch');
end

%% cheetha input에서 마지막 trial 제거

SessionEnd_timestamp=tick_timestamp(ue_Trialend(end));

temp_index = cueonset_timestamp < epoch_timestamp(2, 1) | cueonset_timestamp > SessionEnd_timestamp;
cueonset_timestamp(temp_index) = [];

temp_index = trial_timestamp < epoch_timestamp(2, 1) | trial_timestamp > SessionEnd_timestamp;
trial_timestamp(temp_index) = [];

temp_index = HighValue_timestamp < epoch_timestamp(2, 1) | HighValue_timestamp > SessionEnd_timestamp;
HighValue_timestamp(temp_index) = [];

temp_index = LowValue_timestamp < epoch_timestamp(2, 1) | LowValue_timestamp > SessionEnd_timestamp;
LowValue_timestamp(temp_index) = [];

temp_index = NStart_timestamp < epoch_timestamp(2, 1) | NStart_timestamp > SessionEnd_timestamp;
NStart_timestamp(temp_index) = [];

temp_index = SStart_timestamp < epoch_timestamp(2, 1) | SStart_timestamp > SessionEnd_timestamp;
SStart_timestamp(temp_index) = [];

%% save data

% Cheetah timestamp
cheetah.tick = tick_timestamp;
cheetah.trial = trial_timestamp;
cheetah.cueonset = cueonset_timestamp;
cheetah.highvalue = HighValue_timestamp;
cheetah.lowvalue = LowValue_timestamp;
cheetah.northstart = NStart_timestamp;
cheetah.southstart = SStart_timestamp;

% Unreal log
% tick
ue = zeros(NumberofFrame, 19);
columnNames = {'timestamp','time','trial','trial_ITI','performance_available_frame',...
    'position_x','position_y','direction','distance','distance_from_rewardzone',...
    'velocity','velocity_smoothed','angular_velocity','angular_velocity_smoothed',...
    'edge_timestamp','flag_timestamp','frame_ITI','rewardzone_arrival','highvaluezone'};
ue(:,1) = ue_timestamp.main;
ue(:,2) = ue_time;
ue(:,3) = ue_trial.main;
ue(:,4) = ue_trial.ITIstart;
ue(:,5) = ue_performance_available_frame;
ue(:,6:7) = ue_position.main;
ue(:,8) = ue_head_direction;
ue(:,9) = ue_cumdistance;
ue(:,10) = ue_DistancefromRewardzone;
ue(:,11) = ue_velocity;
ue(:,12) = ue_velocity_smoothing_500ms;
ue(:,13) = ue_ang_velocity;
ue(:,14) = ue_ang_velocity_smoothing_500ms;
ue(:,15) = ue_edge;
ue(:,16) = ue_flag;
ue(:,17) = ue_FrameofITI;
ue(:,18) = ue_reward_zone_arrival; % directly from UE log
ue(:,19) = ue_highvaluezone; % directly from UE log
ue = array2table(ue, 'VariableNames', columnNames);

% trial
ue_t = zeros(NumberofTrial, 18);
columnNames = {'trial_start','trial_start_ITI','rewardzone_arrival','trial_end','trial_end_ITI',...
    'start_direction','performance','performance_available','latency',...
    'travel_distance','edge_distance','percent_edge_nav','guide_trial',...
    'outlier_distance_context','outlier_distance_all','outlier_latency_all','outlier_latency_context',...
    'avg_speed'};
ue_t(:,1) = ue_Trialstart;
ue_t(:,2) = ue_Trialstart_ITI;
ue_t(:,3) = ue_RewardzoneArrival;
ue_t(:,4) = ue_Trialend;
ue_t(:,5) = ue_Trialend_ITI;
ue_t(:,6) = ue_start_direction;
ue_t(:,7) = ue_performance;
ue_t(:,8) = ue_performance_available;
ue_t(:,9) = ue_latency;
ue_t(:,10) = ue_traveldistance;
ue_t(:,11) = ue_EdgeDistance;
ue_t(:,12) = ue_PercentofEdgeNav;
ue_t(:,13) = ue_guide_trial;
ue_t(:,14) = ue_outlier;
ue_t(:,15) = ue_outlier_distance;
ue_t(:,16) = ue_outlier_latency;
ue_t(:,17) = ue_outlier_latency_scene;
ue_t(:,18) = ue_avg_speed;
ue_t = array2table(ue_t, 'VariableNames', columnNames);

% Encoder
encoder = zeros(NumberofFrame, 7);
columnNames = {'position_x','position_y','velocity','velocity_smoothed','distance','degree','angular_velocity'};
encoder(:,1:2) = encoder_position;
encoder(:,3) = encoder_velocity;
encoder(:,4) = encoder_velocity_smoothing_500ms;
encoder(:,5) = encoder_distance;
encoder(:,6) = encoder_degree;
encoder(:,7) = encoder_angspeed;
encoder = array2table(encoder, 'VariableNames', columnNames);

end