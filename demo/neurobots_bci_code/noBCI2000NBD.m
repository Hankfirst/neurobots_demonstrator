%% Add paths
addpath('C:\matlab_offline_toolboxes\matlab_scripts_agball')
addpath('C:\matlab_offline_toolboxes\Parallel_Port\Parallel_Port_64MATLAB_64Windows');

%% Configure parallel port
config_io_64
pp_adress = hex2dec('3FF8');

%% Variables that need to be adjusted before each experiment
% GpuServerIp = 'localhost'; % local
% GpuServerIp = '172.30.2.92'; % robin
% GpuServerIp = '172.30.0.119'; % Zugspitze
% GpuServerIp = '10.5.166.78'; % gpui
% GpuServerIp = '10.5.166.70';% metagpua
% GpuServerIp = '10.5.166.71';% metagpub
% GpuServerIp = '10.5.166.72';% metagpuc
% GpuServerIp = '10.5.166.73';% metagpud
GpuServerIp = '10.5.166.74';% metagpue
% GpuServerIp = '10.5.166.78';% metagpui
% GpuServerIp = '10.5.166.79';% metagpuj

GpuServerPort = 7989;

refElectrodeLable = 'Cz';
decodeMethod = 0;

onlineAdaptation = 1;

useROS = 0;
% IP of ROS core
% RosMasterUri = 'http://172.30.3.166:11311';% needs to have the IP of the current ROS core. (ieeg ginter normally)
% RosMasterUri = 'http://10.240.21.46:11311';% needs to have the IP of the current ROS core. (ieeg ginter normally) --> also to host
% RosMasterUri = 'http://192.168.42.36:11311';% needs to have the IP of the current ROS core. ROBOTHALL ROS MASTER BART
% RosMasterUri = 'http://10.126.44.198:11311';% eduroam robot hall
% RosMasterUri = 'http://127.0.0.1:11311';% local host
RosMasterUri = 'http://10.190.51.49:11311';% iEEG-1 Engelberger

% IP of ROS client, this laptop
% RosIp = '172.30.2.27';% needs to have the correct IP of the ROS client (this laptop`s own ip)
% RosIp = '10.240.27.57';% needs to have the correct IP of the ROS client (this laptop`s own ip)
% RosIp = '192.168.42.70';% needs to have the correct IP of the ROS client (this laptop`s own ip)
% RosIp = '10.126.42.84';% eduroam robot hall
RosIp = java.net.InetAddress.getLocalHost;
RosIp = char(RosIp.getHostAddress);

nDNNOutput = 5; % Number of classes the DNN makes predictions for.

decimationFactor = 2;%0;

SR = str2double('500');
if isnan(SR)
    SR = str2double(bci_Parameters.SamplingRate{1}(1:end-2));
end
SR_new = round(SR/decimationFactor);
nChannels = str2double('75');
channelNames = {'Fp1' 'Fpz' 'Fp2' 'F7' 'F3' 'Fz' 'F4' 'F8' 'FC5' 'FC1' 'FC2' 'FC6' 'M1' 'T7' 'C3' 'Cz' 'C4' 'T8' 'M2' 'CP5' 'CP1' 'CP2' 'CP6' 'P7' 'P3' 'Pz' 'P4' 'P8' 'POz' 'O1' 'Oz' 'O2' 'EMG_RH' 'EMG_LH' 'EMG_RF' 'EMG_LF' 'EOG_R' 'EOG_L' 'EOG_U' 'EOG_D' 'AF7' 'AF3' 'AF4' 'AF8' 'F5' 'F1' 'F2' 'F6' 'FC3' 'FCz' 'FC4' 'C5' 'C1' 'C2' 'C6' 'CP3' 'CPz' 'CP4' 'P5' 'P1' 'P2' 'P6' 'PO5' 'PO3' 'PO4' 'PO6' 'FT7' 'FT8' 'TP7' 'TP8' 'PO7' 'PO8' 'ECG' 'Breath' 'GSR'};
blockSize = 100;
nSamples = round(blockSize./decimationFactor);
nSeconds = 2; % how many seconds must have the same predictions
decodingBuffer = nan(round(SR./nSamples/decimationFactor*nSeconds),nDNNOutput);
decodingThreshold = 0.05;
decodingLabels = [1 2 3 4 5];
rawDecoding = nan(1, nDNNOutput);


classNames = {'Right Hand', 'Feet      ', 'Rotation  ', 'Words     ', 'Rest      '};

% timeout after decoding (1s)
timeoutCounter = SR_new/nSamples;
initialWaitCounter = SR_new/nSamples*10;% 10s
cueDisplayCounter = -1;
cueDisplayBlocks = round(SR_new/nSamples/2);% ideally 500ms, depends on block size and loop timing... We need to round here else we never hit 0...
maxTrainingImagination = SR_new/nSamples*7;% max 7s
minTrainingImagination = SR_new/nSamples*1;% min 1s
maxTrainingPause = SR_new/nSamples*7;% max 7s, every 4 trials
minTrainingPause = SR_new/nSamples*1;% min 1s
longTrainingPauseFreqeuncy = 4;% Every 4th trial do a long pause
longTrainingPauseCounter = 4;
trainingBlockCounter = -1; % randi([minTrainingImaginationCounter maxTrainingImaginationCounter])
pauseBlockCounter = initialWaitCounter; % Either minTrainingPause or maxTrainingPause. Initial value needs to be same as initial wait, else logic fails.


% Collect information set to send to the decoder

%% Define variables for the common average reference (car) filter
% carFilter = [];
% carFilter = eye(nChannels) - ones(nChannels)/nChannels;

% change channel sequence
% targetSequence = {'Fp1'; 'Fpz'; 'Fp2'; 'F7'; 'F3'; 'Fz'; 'F4'; 'F8'; 'FC5';...
%     'FC1'; 'FC2'; 'FC6'; 'M1'; 'T7'; 'C3'; 'Cz'; 'C4'; 'T8'; 'M2'; 'CP5';...
%     'CP1'; 'CP2'; 'CP6'; 'P7'; 'P3'; 'Pz'; 'P4'; 'P8'; 'POz'; 'O1'; 'Oz';...
%     'O2'; 'AF7'; 'AF3'; 'AF4'; 'AF8'; 'F5'; 'F1'; 'F2'; 'F6'; 'FC3'; 'FCz';...
%     'FC4'; 'C5'; 'C1'; 'C2'; 'C6'; 'CP3'; 'CPz'; 'CP4'; 'P5'; 'P1'; 'P2'; 'P6';...
%     'PO5'; 'PO3'; 'PO4'; 'PO6'; 'FT7'; 'FT8'; 'TP7'; 'TP8'; 'PO7'; 'PO8'}; %waveguard first 64 channels

targetSequence = {'Fp1', 'Fpz', 'Fp2', 'AF7', 'AF3', 'AF4', 'AF8', 'F7', ...
    'F5', 'F3', 'F1', 'Fz', 'F2', 'F4', 'F6', 'F8', 'FT7', 'FC5', 'FC3', ...
    'FC1', 'FCz', 'FC2', 'FC4', 'FC6', 'FT8', 'M1', 'T7', 'C5', 'C3', ...
    'C1', 'Cz', 'C2', 'C4', 'C6', 'T8', 'M2', 'TP7', 'CP5', 'CP3', ...
    'CP1', 'CPz', 'CP2', 'CP4', 'CP6', 'TP8', 'P7', 'P5', 'P3', 'P1', ...
    'Pz', 'P2', 'P4', 'P6', 'P8', 'PO7', 'PO5', 'PO3', 'POz', 'PO4', ...
    'PO6', 'PO8', 'O1', 'Oz', 'O2'}; %waveguard first 64 channels, robin's topopraphical sequency

spatialFilter = nan(numel(targetSequence), 1);

for ch = 1:numel(targetSequence)
    spatialFilter(ch) =  find(strcmp(channelNames, targetSequence{ch}));
end

channelNames = channelNames(spatialFilter);

%% design filter
%filter before resample
[bpf.d,bpf.c] = butter(20, 40/(SR/2), 'low');
bpf.filtConds2 = [];
bpf.dim2 = 2;

%filter after resample
[bpf.b,bpf.a] = butter(10, 40/(SR_new/2), 'low');
bpf.filtConds = [];
bpf.dim = 2;

iCz = find(strcmp(channelNames, refElectrodeLable));


% %% create TCP-IP object
% 
% tcpip_obj = tcpip(GpuServerIp, GpuServerPort, 'NetworkRole', 'client');
% tcpip_obj.ByteOrder = 'littleEndian';
% tcpip_obj.OutputBufferSize = 40000;
% 
% fopen(tcpip_obj);
% 
% %% UI server
% 
% tcpip_server =tcpip('0.0.0.0', 30000, 'NetworkRole', 'server');
% tcpip_server.ByteOrder = 'littleEndian';
% 
% if strcmp(tcpip_server.Status,'closed') == 1
%     fopen(tcpip_server);
%     disp('Server connection opened!');
% end
% disp('... waiting for input');
% 
% %% send infos
% 
% % channel names
% chanString = channelNames{1};
% for i = 2:numel(channelNames)
%     chanString = [chanString ' ' channelNames{i}];
% end
% 
% chanString = [chanString ' marker']; %add marker channel
% fprintf(tcpip_obj, chanString, 'sync');
% 
% dataSize = [numel(spatialFilter)+1, nSamples]; % with marker channel
% fwrite(tcpip_obj,  int32(dataSize(1)), 'int32');
% fwrite(tcpip_obj, int32(dataSize(2)), 'int32');
% % fwrite(tcpip_obj, int32(125), 'int32');% Replace by line above after robins fix.



%% ROS node
if useROS
    try
        rosshutdown
    end
    % robot ip adress and rosmaster has to be used rosinit('master_host')
    setenv('ROS_MASTER_URI',RosMasterUri)
    setenv('ROS_IP',RosIp)
    rosinit% Can also be called with rosinit(RosMasterUri)
    % rosinit('10.126.3.30',11311)
    % rosinit('http://ieeg-ginter:11311')
    % USPER IMPORTANT!! EDIT THE IP ADDRESS AND HOSTNAME OF THE ROS MASTER IN C:\Windows\System32\drivers\etc\HOSTS
    
    % Create a client to send and recieve data from the ROS service
    
    menuControlSignalClient = rossvcclient('/menu_control_signal');
    guiControlRequest = rosmessage(menuControlSignalClient);
    
    % client so switch fixation picture
    focusSwapSignalClient = rossvcclient('/focus_swap_signal');
    focusSwapRequest = rosmessage(focusSwapSignalClient);
    
    % client to receive info about which actions are possible right now
    menuNavigationSignalCient=rossvcclient('/get_menu_navigation_signal');
    requestNavigationSignal=rosmessage(menuNavigationSignalCient);
    menuState = call(menuNavigationSignalCient,requestNavigationSignal);
    
    possibleDirections = find([menuState.Up, menuState.Down, menuState.Right, menuState.Left]);
    nDirections = numel(possibleDirections);
    
    
    if onlineAdaptation
        % switch fixation image
        rng('shuffle'); % init random number generator
        %     nextPicInd = randi(nDNNOutput,1);
        nextPicInd = possibleDirections(randi(nDirections, 1));
        switch nextPicInd
            case 1% 'rightarrow'
                focusSwapRequest.Filename = '_right_white.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 1;
            case 2% 'leftarrow'
                focusSwapRequest.Filename = '_left_white.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 2;
            case 3% 'uparrow'
                focusSwapRequest.Filename = '_up_white.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 3;
            case 4% 'downarrow'
                focusSwapRequest.Filename = '_down_white.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 4;
            case 5 % 'face'
                focusSwapRequest.Filename = 'face_smile.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 5;
            case 6% 'navigation'
                focusSwapRequest.Filename = 'navigation.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 6;
            case 7% 'music'
                focusSwapRequest.Filename = 'note.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 7;
            case 8% 'rotation'
                focusSwapRequest.Filename = 'rotation.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 8;
            case 9% 'subtraction'
                focusSwapRequest.Filename = 'subtraction.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 9;
            case 10 % 'words'
                focusSwapRequest.Filename = 'words.bmp';
                result = call(focusSwapSignalClient,focusSwapRequest);
                currentGoal = 10;
        end
    else
        currentGoal = 0;
    end
else
    currentGoal = 0;
end


%% Plot
figure('units', 'normalized', 'Position', [0.73 0.5 0.25 0.4], 'Name', 'Predictions', 'color', 'white');
ax = axes();
bar(ax, [0,0,0,0,0]);
set(ax, 'xticklabel', ['  Right '; '  Feet  '; 'Rotation'; ' Words  '; '  Rest  ']);
ylim([0 1]);

%% Plot
if decodeMethod == 2
    figure('units', 'normalized', 'Position', [0.1 0.1 0.15 0.4], 'Name', 'pVals', 'color', 'white');
    ax2 = axes();
    bar(ax2, [0]);
    set(ax2, 'xticklabel', ['pValues']);
    title(ax2,{['Initialize']; ['buffer Size = ' num2str(size(decodingBuffer,1))]});
    ylim([0 1]);
end

%% Main loop
while 1
    
    in_signal = rand(nChannels,blockSize);
    out_signal = [0 0];
    
    %apply spatial filter to data
    filtData = in_signal(spatialFilter, :);
    
    %filter before resample
    [filtData, bpf.filtConds2] = filter(bpf.d, bpf.c,filtData, bpf.filtConds2, bpf.dim2);
    
    %% Downsample
    filtData = resample(filtData', SR./decimationFactor, SR, 0)';
    
    
    % NONEED!!%filter after resample
    % [filtData, bpf.filtConds] = filter(bpf.b, bpf.a,filtData, bpf.filtConds, bpf.dim);
    
    %% re-reference to Cz
    % filtData = bsxfun(@minus, filtData, filtData(iCz,:));
    
    %% add marker channel
    filtData = [filtData; ones(1, size(filtData,(2)))*currentGoal];% wrong size of data was given here, downsample forgotten
    
    fprintf('Current goal is %i\n',double(currentGoal)); % states have to be doubles
    
%     %% send data via tcp / ip to decoder
%     
%     %reshape data
%     data_reshape = single(reshape(filtData, size(filtData,1).*size(filtData,2),1));
%     %send
%     fwrite(tcpip_obj, data_reshape, 'float32');
    
    
    %% get data from decoder
    out_signal = [0,0];
    rawDecoding = [];
%     while tcpip_server.BytesAvailable > 0
%         dataString=fscanf(tcpip_server);
%         tmp = str2num(dataString); %#ok<ST2NM>
    tmp = rand(1,size(decodingLabels,2));
        if size(tmp,2) == size(decodingLabels,2)% REMOVE -1 after fix Robin!
            rawDecoding(end+1,:) = tmp;% force output to be a horizontal vector
            %         rawDecoding(1,:) = [];
            
%             bar(ax, tmp);
%             set(ax, 'xticklabel', ['  Right '; '  Feet  '; 'Rotation'; ' Words  '; '  Rest  ']);
%             ylim(ax,[0 1]);
%             drawnow;
            
        end
%     end
    
    
    if decodeMethod == 0% No decoding, simple GUI training
        
        bar(ax,[pauseBlockCounter cueDisplayCounter trainingBlockCounter])
        set(ax, 'xticklabel', {num2str(pauseBlockCounter); num2str(cueDisplayCounter); num2str(trainingBlockCounter)});
        ylim([-1 30])
        drawnow
        if useROS
            %% If we had at least a 1s pause we can now display the cue using ROS.
            if pauseBlockCounter == 0 && initialWaitCounter <= 0 && trainingBlockCounter < 0 && cueDisplayCounter < 0
                %% ROS communication with planner, get menu state
                menuState = call(menuNavigationSignalCient,requestNavigationSignal);
                possibleDirections = [find([menuState.Up, menuState.Down, menuState.Right, menuState.Left])];
                tmp = [];
                for iDirection = 1:numel(possibleDirections)
                    switch possibleDirections(iDirection)
                        case 1
                            tmp = [tmp 10];% 6 10];
                        case 2
                            tmp = [tmp 4];% 7];
                        case 3
                            tmp = [tmp 1];% 5];
                        case 4
                            tmp = [tmp 8];% 2];
                        case 5
                            tmp = [tmp 0];% 3 9];
                    end
                end
                randomCue = tmp(randi(numel(tmp)));% We probably only need from [1 4 8 10]
                sprintf('Random cue is %i',randomCue)
                switch randomCue
                    case 0% No action possible
                        focusSwapRequest.Filename = '';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 1% 'rightarrow'
                        focusSwapRequest.Filename = '_right_white.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 2% 'leftarrow'
                        focusSwapRequest.Filename = '_left_white.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 3% 'uparrow'
                        focusSwapRequest.Filename = '_up_white.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 4% 'downarrow'
                        focusSwapRequest.Filename = '_down_white.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 5 % 'face'
                        focusSwapRequest.Filename = 'face_smile.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 6% 'navigation'
                        focusSwapRequest.Filename = 'navigation.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 7% 'music'
                        focusSwapRequest.Filename = 'note.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 8% 'rotation'
                        focusSwapRequest.Filename = 'rotation.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 9% 'subtraction'
                        focusSwapRequest.Filename = 'subtraction.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                    case 10 % 'words'
                        focusSwapRequest.Filename = 'words.bmp';
                        result = call(focusSwapSignalClient,focusSwapRequest);
                end
                outp_64(pp_adress,randomCue)
                pause(0.00001)% 10mus
                outp_64(pp_adress,0)
                bci_States.StimulusCode = double(randomCue);
                cueDisplayCounter = cueDisplayBlocks;% ideally 500ms, depends on block size and loop timing...
                trainingBlockCounter = randi([minTrainingImagination, maxTrainingImagination]);% pseudo not possible
                if longTrainingPauseCounter == 0
                    pauseBlockCounter = maxTrainingPause;
                    longTrainingPauseCounter = longTrainingPauseFreqeuncy;
                elseif longTrainingPauseCounter > 0
                    pauseBlockCounter = minTrainingPause;
                    longTrainingPauseCounter = longTrainingPauseCounter - 1;
                end
            elseif trainingBlockCounter < 0 && cueDisplayCounter < 0
                initialWaitCounter = initialWaitCounter - 1;% Will get negative!!
                cueDisplayCounter = -1;
                if pauseBlockCounter > 0
                    pauseBlockCounter = pauseBlockCounter - 1;
                    %         else
                    %             pauseBlockCounter = -1;
                end
            end
            
            %% Remove cue after 500ms
            if cueDisplayCounter == 0% Cue display time is over
                focusSwapRequest.Filename = '';
                result = call(focusSwapSignalClient,focusSwapRequest);
                outp_64(pp_adress,randomCue+10)
                pause(0.00001)% 10mus
                outp_64(pp_adress,0)
                bci_States.StimulusCode = randomCue+10;
                cueDisplayCounter = -1;% Make sure we do not trigger this if block when no cure is displayed
            elseif cueDisplayCounter > 0% Cue display time is not over yet
                cueDisplayCounter = cueDisplayCounter -1;% Decrease counter
                bci_States.StimulusCode = randomCue;% Make state only
            else
                bci_States.StimulusCode = 0;
            end
            
            % The next block will be triggered randomly every 1-7s. The duration of
            % the training imagination is defined upon cue display.
            %% Do cued action after random interval passed and mark block (TODO THIS CODE SHOULD BE VERY CLOSE TO BLOCK START TO HAVE GOOD MARKER!!)
            if trainingBlockCounter == 0
                switch randomCue
                    case {6, 10}% 'navigation' 'words'
                        guiControlRequest.Direction = int8(1);% up
                        call(menuControlSignalClient,guiControlRequest)
                        %                 bci_States.decodingResult = double(guiControlRequest.Direction);
                    case {4, 7}% 'downarrow' 'music'
                        guiControlRequest.Direction = int8(2);% down
                        call(menuControlSignalClient,guiControlRequest)
                        %                 bci_States.decodingResult = double(guiControlRequest.Direction);
                    case {1, 5}% 'rightarrow' 'face'
                        guiControlRequest.Direction = int8(3);% select
                        call(menuControlSignalClient,guiControlRequest)
                        %                 bci_States.decodingResult = double(guiControlRequest.Direction);
                    case {2, 8} % 'leftarrow' 'rotation'
                        guiControlRequest.Direction = int8(4);% abort
                        call(menuControlSignalClient,guiControlRequest)
                        %                 bci_States.decodingResult = double(guiControlRequest.Direction);
                        %     case 'rightarrow' | 'return'% abort/down-contextsensitive
                        %         guiControlRequest.Direction = int8(5);
                    case {0, 3, 9} % 'rest' 'subtraction'
                        %                 guiControlRequest.Direction = int8(5);
                        %                 bci_States.decodingResult = double(5); %rest
                end
                outp_64(pp_adress,randomCue+20)% WARNING INT8 ONLY GOES UP TO 127!!!
                pause(0.00001)% 10mus
                outp_64(pp_adress,0)
                bci_States.decodingResult = randomCue+20;
                trainingBlockCounter = -1;
            elseif trainingBlockCounter > 0
                trainingBlockCounter = trainingBlockCounter - 1;
                bci_States.decodingResult = 0;
            else
                bci_States.decodingResult = 0;
            end
        end
        
    elseif decodeMethod == 1 % Lukas' method: control max 1 time per second & only if the decodings in this second were the same and above decodingThreshold
        
        
        % convert to ball movements
        if ~isempty(rawDecoding)
            tmp = mean(rawDecoding,1);
            tmp = tmp*2;
            out_signal = [tmp(1)-tmp(3); tmp(4)-tmp(2)];
        end
        
        % Fill ring buffer
        if ~isempty(rawDecoding)
            nDecodings = size(rawDecoding,1);
            decodingBuffer = [decodingBuffer(nDecodings+1:end,:); rawDecoding] ;
            %     decodingBuffer(1:size(rawDecoding,1),:) = [];
        end
        
        % Threshold every decoding package into one predicted class
        [integerDecodingBuffer, iDecodingLabels] = max(decodingBuffer,[],2);% Take max of every package
        notDecodedYet = isnan(integerDecodingBuffer);
        predictionOverThreshold = integerDecodingBuffer>decodingThreshold;
        integerDecodingBuffer = decodingLabels(iDecodingLabels);
        integerDecodingBuffer(~predictionOverThreshold) = -1;
        integerDecodingBuffer(notDecodedYet) = nan;
        
        % Constraining output to once per second
        if ~any(notDecodedYet == 1) && numel(unique(integerDecodingBuffer)) == 1
            
            %% ROS communication with planner
            if useROS
                switch unique(integerDecodingBuffer)
                    case 4% 'words'
                        guiControlRequest.Direction = int8(1);% up
                        call(menuControlSignalClient,guiControlRequest)
                        bci_States.decodingResult = double(guiControlRequest.Direction);
                    case 2% 'downarrow'
                        guiControlRequest.Direction = int8(2);% down
                        call(menuControlSignalClient,guiControlRequest)
                        bci_States.decodingResult = double(guiControlRequest.Direction);
                    case 1% 'rightarrow'
                        guiControlRequest.Direction = int8(3);% select
                        call(menuControlSignalClient,guiControlRequest)
                        bci_States.decodingResult = double(guiControlRequest.Direction);
                    case 3% 'rotation'
                        guiControlRequest.Direction = int8(4);% abort
                        call(menuControlSignalClient,guiControlRequest)
                        bci_States.decodingResult = double(guiControlRequest.Direction);
                        %     case 'rightarrow' | 'return'% abort/down-contextsensitive
                        %         guiControlRequest.Direction = int8(5);
                    case 5 %rest
                        bci_States.decodingResult = double(5); %rest
                end
            end
            outp_64(pp_adress,unique(integerDecodingBuffer))
            pause(0.00001)% 10mus
            outp_64(pp_adress,0)
            
            %     out_signal = decodingBuffer;
            
            if onlineAdaptation
                pause(0.01); %wait for a moment for planner to get changes
                
                
                % switch fixation image
                % nextPicInd = randi(nDNNOutput,1);
                if useROS
                    menu_state = call(menuNavigationSignalCient,requestNavigationSignal);
                    possibleDirections = find([menu_state.Up, menu_state.Down, menu_state.Right, menu_state.Left]);
                    nDirections = numel(possibleDirections);
                    nextPicInd = possibleDirections(randi(nDirections, 1));
                    switch nextPicInd
                        case 2% 'downarrow'
                            focusSwapRequest.Filename = '_down_white.bmp';
                            result = call(focusSwapSignalClient,focusSwapRequest);
                            currentGoal = 2;
                        case 1% 'rightarrow'
                            focusSwapRequest.Filename = '_right_white.bmp';
                            result = call(focusSwapSignalClient,focusSwapRequest);
                            currentGoal = 1;
                        case 3% 'rotation'
                            focusSwapRequest.Filename = 'rotation.bmp';
                            result = call(focusSwapSignalClient,focusSwapRequest);
                            currentGoal = 3;
                        case 4% 'words'
                            focusSwapRequest.Filename = 'word.bmp';
                            result = call(focusSwapSignalClient,focusSwapRequest);
                            currentGoal = 4;
                        case 5 %rest
                            focusSwapRequest.Filename = '';
                            result = call(focusSwapSignalClient,focusSwapRequest);
                            currentGoal = 5;
                    end
                end
                outp_64(pp_adress,nextPicInd)
                pause(0.00001)% 10mus
                outp_64(pp_adress,0)
                
            end
            
            % Reset decodingBuffer
            decodingBuffer = nan(size(decodingBuffer));
            
        else
            bci_States.decodingResult = double(0);
            %     out_signal = decodingBuffer;
            %     out_signal = [0,0];
            
        end
        
    elseif decodeMethod == 2 % control max 1/s; send control signal if values in highest decoding class are significantly > decodingThreshold (ttest, p<0.01)
        bci_States.decodingResult = double(0);
        % Fill  buffer
        if ~isempty(rawDecoding)
            nDecodings = size(rawDecoding,1);
            if timeoutCounter == 0 %wait for a timeout (normally 1s) after decoding before collecting predictions again
                if any(any(isnan(decodingBuffer))) % as long as there are nans (last decoding / start < 1s before), discard those first
                    decodingBuffer = [decodingBuffer(nDecodings+1:end,:); rawDecoding] ;
                else % no nans, make buffer bigger...
                    decodingBuffer = [decodingBuffer; rawDecoding] ;
                end
            else
                timeoutCounter = timeoutCounter-1;
            end
            
            if ~any(any(isnan(decodingBuffer)))  % test for significance if there are no nans anymore in the buffer
                [maxVal, maxInd] = max(mean(decodingBuffer,1)); % find max
                
                if maxVal > decodingThreshold % only go further if mean of max class is above decodingThreshold
                    [h,p] = ttest2(decodingBuffer(:,maxInd), decodingThreshold);
                    %                  p = weightedTTest(decodingBuffer(:,maxInd), decodingThreshold, 0.9);
                    
                    %plot pvalues
                    bar(ax2, p);
                    set(ax2, 'xticklabel', ['pValues']);
                    title(ax2,{[num2str(classNames{maxInd})]; ['buffer Size = ' num2str(size(decodingBuffer,1))]});
                    ylim(ax2,[0 1]);
                    drawnow;
                    
                    if p < 0.2 % if significantly lower than treshold, send control signal
                        
                        %% ROS communication with planner
                        if useROS
                            switch maxInd
                                case 2% 'downarrow'
                                    guiControlRequest.Direction = int8(2);% down
                                    call(menuControlSignalClient,guiControlRequest)
                                    bci_States.decodingResult = double(guiControlRequest.Direction);
                                case 1% 'rightarrow'
                                    guiControlRequest.Direction = int8(3);% select
                                    call(menuControlSignalClient,guiControlRequest)
                                    bci_States.decodingResult = double(guiControlRequest.Direction);
                                case 3% 'rotation'
                                    guiControlRequest.Direction = int8(4);% abort
                                    call(menuControlSignalClient,guiControlRequest)
                                    bci_States.decodingResult = double(guiControlRequest.Direction);
                                    %     case 'rightarrow' | 'return'% abort/down-contextsensitive
                                    %         guiControlRequest.Direction = int8(5);
                                case 4% 'words'
                                    guiControlRequest.Direction = int8(1);% up
                                    call(menuControlSignalClient,guiControlRequest)
                                    bci_States.decodingResult = double(guiControlRequest.Direction);
                                case 5 %rest
                                    bci_States.decodingResult = double(5); %rest
                            end
                        end
                        outp_64(pp_adress,maxInd)
                        pause(0.00001)% 10mus
                        outp_64(pp_adress,0)
                        
                        %     out_signal = decodingBuffer;
                        
                        if onlineAdaptation
                            
                            pause(0.01); %wait for a moment for planner to get changes
                            
                            % switch fixation image
                            % nextPicInd = randi(nDNNOutput,1);
                            if useROS
                                menu_state = call(menuNavigationSignalCient,requestNavigationSignal);
                                possibleDirections = find([menu_state.Up, menu_state.Down, menu_state.Right, menu_state.Left]);
                                nDirections = numel(possibleDirections);
                                nextPicInd = possibleDirections(randi(nDirections, 1));
                                
                                switch nextPicInd
                                    case 4% 'words'
                                        focusSwapRequest.Filename = 'words.bmp';
                                        result = call(focusSwapSignalClient,focusSwapRequest);
                                        currentGoal = 4;
                                    case 2% 'downarrow'
                                        focusSwapRequest.Filename = '_down_white.bmp';
                                        result = call(focusSwapSignalClient,focusSwapRequest);
                                        currentGoal = 2;
                                    case 1% 'rightarrow'
                                        focusSwapRequest.Filename = '_right_white.bmp';
                                        result = call(focusSwapSignalClient,focusSwapRequest);
                                        currentGoal = 1;
                                    case 3% 'rotation'
                                        focusSwapRequest.Filename = 'rotation.bmp';
                                        result = call(focusSwapSignalClient,focusSwapRequest);
                                        currentGoal = 3;
                                    case 5 %rest
                                        focusSwapRequest.Filename = '';
                                        result = call(focusSwapSignalClient,focusSwapRequest);
                                        currentGoal = 5;
                                end
                            end
                            outp_64(pp_adress,nextPicInd)
                            pause(0.00001)% 10mus
                            outp_64(pp_adress,0)
                            
                        end
                        
                        % Reset decodingBuffer to 1 seconds
                        decodingBuffer = nan(round(SR./nSamples/decimationFactor*nSeconds),nDNNOutput);
                        
                        % set timeout Counter
                        timeoutCounter = SR_new/nSamples;
                        
                        
                    end
                end
            else
                %plot pvalues
                bar(ax2, 1);
                set(ax2, 'xticklabel', ['pValues']);
                title(ax2,{['Waiting']; ['buffer Size = ' num2str(size(decodingBuffer,1))]});
                ylim(ax2,[0 1]);
                drawnow;
            end
        end
        
        nSampleThreshold = (round(SR./nSamples/decimationFactor)*4);
        if size(decodingBuffer,1) >= nSampleThreshold
            %         decodingBuffer = nan(round(SR./nSamples/decimationFactor),nDNNOutput);
            decodingBuffer(1:(end-nSampleThreshold+1),:) = [];
        end
        
        
        
    end
    
    
    pause(nSamples/SR_new)
end