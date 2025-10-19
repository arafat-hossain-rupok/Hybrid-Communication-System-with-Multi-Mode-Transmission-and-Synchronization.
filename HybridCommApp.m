classdef HybridCommApp < matlab.apps.AppBase

    % UI Components
    properties (Access = public)
        UIFigure          matlab.ui.Figure
        RecordSpeechBtn   matlab.ui.control.Button
        RecordMusicBtn    matlab.ui.control.Button
        ModulationTypeBtnGroup matlab.ui.container.ButtonGroup
        AMButton          matlab.ui.control.RadioButton
        FMButton          matlab.ui.control.RadioButton
        SSBButton         matlab.ui.control.RadioButton
        CarrierFreqEdit   matlab.ui.control.NumericEditField
        ModulateBtn       matlab.ui.control.Button
        NoiseSlider       matlab.ui.control.Slider
        DelaySlider       matlab.ui.control.Slider
        DemodulateBtn     matlab.ui.control.Button
        PlayAudioBtn      matlab.ui.control.Button
        AddNoiseDelayBtn  matlab.ui.control.Button  % New Button
        MSELabel          matlab.ui.control.Label
        SignalPlot        matlab.ui.control.UIAxes
    end
    
    % Private properties (Data & Parameters)
    properties (Access = private)
        speech_signal
        music_signal
        modulated_signal
        received_signal
        recovered_signal
        fs = 22050; % Sampling frequency
        fc_am = 1000; % AM Carrier Frequency
        fc_fm = 2000; % FM Carrier Frequency
        fc_ssb = 3000; % SSB Carrier Frequency
    end
    
    methods (Access = private)
        
        % Record Speech Signal
        function recordSpeech(app)
            duration = 5; % 5 seconds
            recObj = audiorecorder(app.fs, 16, 1);
            recordblocking(recObj, duration);
            app.speech_signal = getaudiodata(recObj);
            app.speech_signal = app.speech_signal / max(abs(app.speech_signal)); % Normalize
        end
        
        % Record Music Signal
        function recordMusic(app)
            duration = 5;
            recObj = audiorecorder(app.fs, 16, 1);
            recordblocking(recObj, duration);
            app.music_signal = getaudiodata(recObj);
            app.music_signal = app.music_signal / max(abs(app.music_signal)); % Normalize
        end
        
        % Modulate Signal
        function modulateSignal(app)
            if isempty(app.speech_signal) || isempty(app.music_signal)
                uialert(app.UIFigure, 'Please record both speech and music first!', 'Error');
                return;
            end

            t = (0:length(app.speech_signal)-1) / app.fs;

            if app.AMButton.Value
                app.modulated_signal = (1 + app.speech_signal) .* cos(2 * pi * app.fc_am * t)';
            elseif app.FMButton.Value
                app.modulated_signal = fmmod(app.music_signal, app.fc_fm, app.fs, 50);
            elseif app.SSBButton.Value
                app.modulated_signal = real(hilbert(app.music_signal) .* exp(1j*2*pi*app.fc_ssb*t)'); % SSB Modulation
            end

            plot(app.SignalPlot, t, app.modulated_signal);
            title(app.SignalPlot, 'Modulated Signal');
        end
        
        % Add Noise and Delay
        function addNoiseAndDelay(app)
            if isempty(app.modulated_signal)
                uialert(app.UIFigure, 'Please modulate the signal first!', 'Error');
                return;
            end

            noise_level = app.NoiseSlider.Value;
            delay_samples = round(app.DelaySlider.Value);

            noise = noise_level * randn(size(app.modulated_signal)); % Gaussian Noise
            app.received_signal = app.modulated_signal + noise;

            % Apply delay (shifting the signal forward)
            app.received_signal = [zeros(delay_samples,1); app.received_signal(1:end-delay_samples)];

            plot(app.SignalPlot, (0:length(app.received_signal)-1) / app.fs, app.received_signal);
            title(app.SignalPlot, 'Received Signal with Noise & Delay');
        end
        
        % Demodulate Signal
        function demodulateSignal(app)
            if isempty(app.received_signal)
                uialert(app.UIFigure, 'Please add noise/delay first!', 'Error');
                return;
            end

            t = (0:length(app.received_signal)-1) / app.fs;
            
            if app.AMButton.Value
                recovered = abs(hilbert(app.received_signal));
            elseif app.FMButton.Value
                recovered = fmdemod(app.received_signal, app.fc_fm, app.fs, 50);
            elseif app.SSBButton.Value
                recovered = real(hilbert(app.received_signal) .* exp(-1j*2*pi*app.fc_ssb*t)'); % SSB Demodulation
            end

            % Ensure signal lengths match for MSE calculation
            minLength = min(length(app.speech_signal), length(recovered));
            recovered = recovered(1:minLength);

            % Store recovered signal
            app.recovered_signal = recovered;

            % Compute MSE
            mse = mean((app.speech_signal(1:minLength) - recovered).^2);
            app.MSELabel.Text = ['MSE: ', num2str(mse)];

            % Plot Demodulated Signal
            plot(app.SignalPlot, t(1:minLength), recovered);
            title(app.SignalPlot, 'Demodulated Signal');
        end
        
        % Play Audio (Modulated or Demodulated)
        function playAudio(app)
            if isempty(app.recovered_signal)
                uialert(app.UIFigure, 'No demodulated signal available!', 'Error');
                return;
            end
            soundsc(app.recovered_signal, app.fs);
        end
    end
    
    % UI Component Initialization
    methods (Access = private)
        function startupFcn(app)
            app.RecordSpeechBtn.ButtonPushedFcn = @(btn,event) recordSpeech(app);
            app.RecordMusicBtn.ButtonPushedFcn = @(btn,event) recordMusic(app);
            app.ModulateBtn.ButtonPushedFcn = @(btn,event) modulateSignal(app);
            app.AddNoiseDelayBtn.ButtonPushedFcn = @(btn,event) addNoiseAndDelay(app); % New Button Action
            app.DemodulateBtn.ButtonPushedFcn = @(btn,event) demodulateSignal(app);
            app.PlayAudioBtn.ButtonPushedFcn = @(btn,event) playAudio(app);
        end
    end
    
    % App Constructor
    methods (Access = public)
        function app = HybridCommApp()
            app.UIFigure = uifigure('Name', 'Hybrid Communication System');
            
            app.RecordSpeechBtn = uibutton(app.UIFigure, 'Text', 'Record Speech', 'Position', [20, 350, 100, 30]);
            app.RecordMusicBtn = uibutton(app.UIFigure, 'Text', 'Record Music', 'Position', [140, 350, 100, 30]);
            
            app.ModulationTypeBtnGroup = uibuttongroup(app.UIFigure, 'Position', [20, 250, 220, 80], 'Title', 'Modulation Type');
            app.AMButton = uiradiobutton(app.ModulationTypeBtnGroup, 'Text', 'AM', 'Position', [10, 50, 100, 20]);
            app.FMButton = uiradiobutton(app.ModulationTypeBtnGroup, 'Text', 'FM', 'Position', [10, 30, 100, 20]);
            app.SSBButton = uiradiobutton(app.ModulationTypeBtnGroup, 'Text', 'SSB', 'Position', [10, 10, 100, 20]);

            app.ModulateBtn = uibutton(app.UIFigure, 'Text', 'Modulate', 'Position', [20, 200, 100, 30]);
            app.NoiseSlider = uislider(app.UIFigure, 'Position', [20, 150, 200, 20], 'Limits', [0, 0.1], 'Value', 0.05);
            app.DelaySlider = uislider(app.UIFigure, 'Position', [20, 120, 200, 20], 'Limits', [0, 100], 'Value', 50);
            app.AddNoiseDelayBtn = uibutton(app.UIFigure, 'Text', 'Add Noise & Delay', 'Position', [20, 90, 150, 30]); % New Button
            app.DemodulateBtn = uibutton(app.UIFigure, 'Text', 'Demodulate', 'Position', [20, 60, 100, 30]);
            app.PlayAudioBtn = uibutton(app.UIFigure, 'Text', 'Play Audio', 'Position', [20, 30, 100, 30]);
            app.SignalPlot = uiaxes(app.UIFigure, 'Position', [260, 50, 400, 300]);
            app.MSELabel = uilabel(app.UIFigure, 'Position', [260, 20, 400, 30]);

            startupFcn(app);
        end
    end
end