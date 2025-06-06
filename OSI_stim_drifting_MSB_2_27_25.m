function DriftDemo2(angle, cyclespersecond, f, drawmask, gratingsize)
% function DriftDemo2([angle=30][, cyclespersecond=1][, f=0.05][, drawmask=1][, gratingsize=400])
% ___________________________________________________________________
%
% Display an animated grating using the new Screen('DrawTexture') command.
% In Psychtoolbox 3, the  Screen('DrawTexture') replaces
% Screen('CopyWindow'). The demo will stop after roughly 20 seconds have
% passed or after the user hits a key.
%
% This demo illustrates how to draw an animated 2-D grating online by use of
% only one 1-D grating texture. We create one texture with a static cosine
% grating. In each successive frame we only draw a rectangular subregion of
% the texture onto the screen, basically showing the texture through
% an aperture. The subregion - and therefore our "aperture" is shifted each
% frame, so we create the impression of a moving grating.
%
% The demo also shows how to use alpha-blending for masking the grating
% with a gaussian transparency mask (a texture with transparency layer).
%
% And finally, we demonstrate rotated drawing, as well as how to emulate
% the old OS-9 'WaitBlanking' command with the new 'Flip' command.
%
% Optional parameters:
%
% angle = Angle of the grating with respect to the vertical direction.
% cyclespersecond = Speed of grating in cycles per second.
% f = Frequency of grating in cycles per pixel.
% drawmask = If set to 1, a gaussian aperture is drawn over the grating.
% gratingsize = Visible size of grating in screen pixels.
%
% CopyWindow vs. DrawTexture:
%
% In the OS 9 Psychtoolbox, Screen ('CopyWindow") was used for all
% time-critical display of images, in particular for display of the movie
% frames in animated stimuli. In contrast, Screen('DrawTexture') should not
% be used for display of all graphic elements,  but only for  display of
% MATLAB matrices.  For all other graphical elements, such as lines,  rectangles,
% and ovals we recommend that these be drawn directly to the  display
% window during the animation rather than rendered to offscreen  windows
% prior to the animation.
%
% _________________________________________________________________________
% 
% see also: PsychDemos, MovieDemo

% HISTORY
%  6/7/05    mk     Adapted from Allen Ingling's DriftDemoOSX.m
%  2/28/09   mk     Updated with small fixes and enhancements + additional comments.

%% This is the initialization section of the code. Setup, paramters, et cetera

if nargin < 5
    gratingsize = [];
end

monitor = get(0,'ScreenSize'); %MSB: get the screen size in pixels, with the biggest dimension in column 3 (1x4 vector)
angle_list = [0, 45, 90, 135, 180, 225, 270, 315]; %MSB: Make a list of the 8 possible stimulus orientations that should be used.
%angle_list = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270, 300, 330]; %12 stimuli

%angle_log = angle_list(randperm(length(angle_list)));
angle_log = [180, 45, 225, 270, 135, 0, 90, 315];

num_theta = length(angle_list); %How many different stimuli are presented. Default is 8, could use 12.
num_loops = 1;  %The number of loops to run, of the whole thing, I default to 10
time_ON = 3;    %Time for stim ON in seconds
time_OFF =3;   %Time for stim OFF in seconds

if isempty(gratingsize)
    % By default the visible grating is 400 pixels by 400 pixels in size:
    %gratingsize = 400;
    gratingsize = monitor(1,3)+ monitor(1,4); %MSB: sets the grating size to equal the largest dimension of the screen (I think)
end

if nargin < 4
    drawmask = [];
end

if isempty(drawmask)
    % By default, we mask the grating by a gaussian transparency mask:
    drawmask=0; %MSB: I want there to be no mask by default
end;

if nargin < 3
    f = [];
end

if isempty(f)
    % Grating cycles/pixel: By default 0.05 cycles per pixel.
    f=0.006; %try 0.004, 0.006, or 0.008
end;

if nargin < 2
    cyclespersecond = [];
end

if isempty(cyclespersecond)
    % Speed of grating in cycles per second: 1 cycle per second by default.
    cyclespersecond= 1.5; %Trying 2 i guess to see how it looks...
end;

if nargin < 1
    angle = [];
end

if isempty(angle)
    % Angle of the grating: We default to 30 degrees. 
    angle=0; %MSB: I changed default to 0 degrees. BUT, I want this value to change every time the cycle completes.
end;

movieDurationSecs=20;   % Abort demo after 20 seconds. BUT I NO LONGER USE THIS VARIABLE

% Define Half-Size of the grating image.
texsize=gratingsize / 2;

Screen('Preference', 'SkipSyncTests', 1); %MSB: This forces PsychToolBox to ignore the VBL sync warning that keeps popping up...

% %% initial nidaq
% 
% daq.reset;
% device = daq.getDevices;
% if isempty(device)
%     disp('No data acquisition devices available.');
%     return;
% end;
% devicename=device(1).ID;
% s = daq.createSession('ni');    %Trigger to start recording and stop recording
% addAnalogOutputChannel(s,'Dev3', 'ao0', 'Voltage'); %device is ID'd as Dev2
% z = daq.createSession('ni');    %Trigger to make stimulus transitions
% addAnalogOutputChannel(z,'Dev3', 'ao1', 'Voltage'); %device is ID'd as Dev2
% TTL = daq.createSession('ni');  %Trigger to start and stop the Arduino serial output (hopefully)
% addDigitalChannel(TTL,'Dev5', 'port0/line0', 'OutputOnly'); %This is the USER1 output...

%% open Arduino session

clear s;
s = arduinoIOPort('COM3',13,2); %parameters: port, end pin, start pin
s.pinMode(13,'input');
s.pinMode(12,'output');
starting_input = s.digitalRead(13)
starting_output = s.digitalRead(12)
% s.timedTTL(2,5); %send a 5ms TTL on pin 2
% s.digitalWrite(6,1); %write pin 6 HIGH
% s.digitalWrite(6,0); %write pin 6 LOW
% clear s; % close the serial port

%% Initialize PsychToolBox and start drawing stuff or something.

try
	% This script calls Psychtoolbox commands available only in OpenGL-based 
	% versions of the Psychtoolbox. (So far, the OS X Psychtoolbox is the
	% only OpenGL-base Psychtoolbox.)  The Psychtoolbox command AssertPsychOpenGL will issue
	% an error message if someone tries to execute this script on a computer without
	% an OpenGL Psychtoolbox
	AssertOpenGL;
	
	% Get the list of screens and choose the one with the highest screen number.
	% Screen 0 is, by definition, the display with the menu bar. Often when 
	% two monitors are connected the one without the menu bar is used as 
	% the stimulus display.  Chosing the display with the highest dislay number is 
	% a best guess about where you want the stimulus displayed.  
	screens=Screen('Screens');
	screenNumber=max(screens);
	
    % Find the color values which correspond to white and black: Usually
	% black is always 0 and white 255, but this rule is not true if one of
	% the high precision framebuffer modes is enabled via the
	% PsychImaging() commmand, so we query the true values via the
	% functions WhiteIndex and BlackIndex:
	white=WhiteIndex(screenNumber);
	black=BlackIndex(screenNumber);
    
    % Round gray to integral number, to avoid roundoff artifacts with some
    % graphics cards:
	gray=round((white+black)/2);

    % This makes sure that on floating point framebuffers we still get a
    % well defined gray. It isn't strictly neccessary in this demo:
    if gray == white
		gray=white / 2;
    end
    
    % Contrast 'inc'rement range for given white and gray values:
	inc=white-gray;

    %% DRAW THE BLANK GREY SCREEN THAT DEFINES THE BASELINE PERIOD
    
    % Open a double buffered fullscreen window and set default background
	% color to gray:
	[w screenRect]=Screen('OpenWindow',screenNumber, gray);
    
    if drawmask
        % Enable alpha blending for proper combination of the gaussian aperture
        % with the drifting sine grating:
        Screen('BlendFunction', w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    end
    
    % Calculate parameters of the grating:
    
    % First we compute pixels per cycle, rounded up to full pixels, as we
    % need this to create a grating of proper size below:
    p=ceil(1/f);
    
    % Also need frequency in radians:
    fr=f*2*pi;
    
    % This is the visible size of the grating. It is twice the half-width
    % of the texture plus one pixel to make sure it has an odd number of
    % pixels and is therefore symmetric around the center of the texture:
    visiblesize=2*texsize+1;

    % Create one single static grating image:
    %
    % We only need a texture with a single row of pixels(i.e. 1 pixel in height) to
    % define the whole grating! If the 'srcRect' in the 'Drawtexture' call
    % below is "higher" than that (i.e. visibleSize >> 1), the GPU will
    % automatically replicate pixel rows. This 1 pixel height saves memory
    % and memory bandwith, ie. it is potentially faster on some GPUs.
    %
    % However it does need 2 * texsize + p columns, i.e. the visible size
    % of the grating extended by the length of 1 period (repetition) of the
    % sine-wave in pixels 'p':
    x = meshgrid(-texsize:texsize + p, 1);
    
    % Compute actual cosine grating:
    grating=gray + inc*cos(fr*x);

    % Store 1-D single row grating in texture:
    gratingtex=Screen('MakeTexture', w, grating);

    % Create a single gaussian transparency mask and store it to a texture:
    % The mask must have the same size as the visible size of the grating
    % to fully cover it. Here we must define it in 2 dimensions and can't
    % get easily away with one single row of pixels.
    %
    % We create a  two-layer texture: One unused luminance channel which we
    % just fill with the same color as the background color of the screen
    % 'gray'. The transparency (aka alpha) channel is filled with a
    % gaussian (exp()) aperture mask:
    mask=ones(2*texsize+1, 2*texsize+1, 2) * gray;
    [x,y]=meshgrid(-1*texsize:1*texsize,-1*texsize:1*texsize);
    mask(:, :, 2)=white * (1 - exp(-((x/90).^2)-((y/90).^2)));
    masktex=Screen('MakeTexture', w, mask);

    % Query maximum useable priorityLevel on this system:
	priorityLevel=MaxPriority(w); %#ok<NASGU>

    % We don't use Priority() in order to not accidentally overload older
    % machines that can't handle a redraw every 40 ms. If your machine is
    % fast enough, uncomment this to get more accurate timing.
    %Priority(priorityLevel);
    
    % Definition of the drawn rectangle on the screen:
    % Compute it to  be the visible size of the grating, centered on the
    % screen:
    dstRect=[0 0 visiblesize visiblesize];
    dstRect=CenterRect(dstRect, screenRect);

    % Query duration of one monitor refresh interval:
    ifi=Screen('GetFlipInterval', w);
    
    % Translate that into the amount of seconds to wait between screen
    % redraws/updates:
    
    % waitframes = 1 means: Redraw every monitor refresh. If your GPU is
    % not fast enough to do this, you can increment this to only redraw
    % every n'th refresh. All animation paramters will adapt to still
    % provide the proper grating. However, if you have a fine grating
    % drifting at a high speed, the refresh rate must exceed that
    % "effective" grating speed to avoid aliasing artifacts in time, i.e.,
    % to make sure to satisfy the constraints of the sampling theorem
    % (See Wikipedia: "Nyquist?Shannon sampling theorem" for a starter, if
    % you don't know what this means):
    waitframes = 1;
    
    % Translate frames into seconds for screen update interval:
    waitduration = waitframes * ifi;
    
    % Recompute p, this time without the ceil() operation from above.
    % Otherwise we will get wrong drift speed due to rounding errors!
    p = 1/f;  % pixels/cycle    

    % Translate requested speed of the grating (in cycles per second) into
    % a shift value in "pixels per frame", for given waitduration: This is
    % the amount of pixels to shift our srcRect "aperture" in horizontal
    % directionat each redraw:
    shiftperframe = cyclespersecond * p * waitduration;

    % Perform initial Flip to sync us to the VBL and for getting an initial
    % VBL-Timestamp as timing baseline for our redraw loop:
    vbl=Screen('Flip', w);

    % We run at most 'movieDurationSecs' seconds if user doesn't abort via keypress.
    vblendtime = vbl + movieDurationSecs;
    i=0;
    
    %Wait at first for 5 seconds after starting the program, so the mouse
    %can adjust to the shock of seeing the blank grey screen. DON'T DO ANY
    %IMAGING DURING THIS TIME.
    WaitSecs(3);

    while s.digitalRead(13) == 0
    disp 'Waiting.';
    end
    disp 'It worked!'
    
    % %**********************************************************************
    % %startBackground(ao); %send out the trigger signal for two-photon
    % %imaging
    % %send out the trigger signal to BEGIN two-photon imaging
    % % 2023.7.10: I want to modify this so the script waits for a TTL input
    % % on Arduino Uno digital pin 13
    % outputSingleScan(s,5);
    % % 2023.7.10: This TTL scan is no longer needed -- no treadmill for
    % % Charlie's 2p setup.
    % outputSingleScan(TTL,1);    %This trigger starts the PLX-DAQ treadmill recording
    % %WaitSecs(0.005);
    % WaitSecs(0.01);
    % outputSingleScan(s,0);
    % %**********************************************************************
    
    % wait for sometime to start stimulation
    WaitSecs(10);   %MSB: I am choosing to wait for 10 seconds to record the response to blank screen at the very start of stimulation
    
    
    %% HERE'S THE ANIMATION LOOP, DON'T RETURN TO THE GREY BLANK SCREEN EXCEPT FOR THE BRIEF TIME BETWEEN PRESENTATIONS
    
    
    % Animationloop:
    for K = 1:num_loops;    %Run n=K loops of all theta
        
        for J = 1:num_theta; %Run n=J stimuli in a row, for each loop/repetition
            angle = angle_log(J); %Choose the appropriate angle
            
            %send out the trigger signal to MARK the start of each new orientation
            % 2023.7.10: Modified to use Arduino Uno and some code from a
            % PTB user to send a TTL.

            s.timedTTL(12, 10); %This SHOULD send a 10ms TTL out on digital pin 12

            % 2023.7.10: Commented out.
            % outputSingleScan(z,5); 
            % WaitSecs(0.01);
            % outputSingleScan(z,0);
            
            time = vbl;
            tic;
            while (toc < time_ON)
            %while (vbl < (time+4))
            
    
    %while(vbl < vblendtime)

        % Shift the grating by "shiftperframe" pixels per frame:
        % the mod'ulo operation makes sure that our "aperture" will snap
        % back to the beginning of the grating, once the border is reached.
        % Fractional values of 'xoffset' are fine here. The GPU will
        % perform proper interpolation of color values in the grating
        % texture image to draw a grating that corresponds as closely as
        % technical possible to that fractional 'xoffset'. GPU's use
        % bilinear interpolation whose accuracy depends on the GPU at hand.
        % Consumer ATI hardware usually resolves 1/64 of a pixel, whereas
        % consumer NVidia hardware usually resolves 1/256 of a pixel. You
        % can run the script "DriftTexturePrecisionTest" to test your
        % hardware...
        xoffset = mod(i*shiftperframe,p);
        i=i+1;
        
        % Define shifted srcRect that cuts out the properly shifted rectangular
        % area from the texture: We cut out the range 0 to visiblesize in
        % the vertical direction although the texture is only 1 pixel in
        % height! This works because the hardware will automatically
        % replicate pixels in one dimension if we exceed the real borders
        % of the stored texture. This allows us to save storage space here,
        % as our 2-D grating is essentially only defined in 1-D:
        srcRect=[xoffset 0 xoffset + visiblesize visiblesize];
        
        % Draw grating texture, rotated by "angle":
        Screen('DrawTexture', w, gratingtex, srcRect, dstRect, angle);

        if drawmask==1
            % Draw gaussian mask over grating:
            Screen('DrawTexture', w, masktex, [0 0 visiblesize visiblesize], dstRect, angle);
        end;

        % Flip 'waitframes' monitor refresh intervals after last redraw.
        % Providing this 'when' timestamp allows for optimal timing
        % precision in stimulus onset, a stable animation framerate and at
        % the same time allows the built-in "skipped frames" detector to
        % work optimally and report skipped frames due to hardware
        % overload:
        vbl = Screen('Flip', w, vbl + (waitframes - 0.5) * ifi);
        
        
            end
            
        %WaitSecs(4);
         %send out the trigger signal to MARK the start of each new orientation
         % 2023.7.10: Modified to use Arduino Uno and some code from a
         % PTB user to send a TTL.

         s.timedTTL(12, 10); %This SHOULD send a 10ms TTL out on digital pin 12

         % 2023.7.10: commented out
         % outputSingleScan(z,5); 
         % WaitSecs(0.01);
         % outputSingleScan(z,0);
               
        Screen('Flip', w);  %Flip back to the blank grey screen.
               
        WaitSecs(time_OFF);

        % Abort demo if any key is pressed:
        if KbCheck
            break;
        end;
    %end;    %Linked to 'while' up above
    
    
    
        end  %Linked to 'num_theta' loop
        
    end      %Linked to 'num_loops' loop

    % %***************************************************
    % %Send triggers to stop data collection!
    % outputSingleScan(s,5);  %TTL pulse for Zen Black to END imaging
    % outputSingleScan(TTL,0);    %Turn OFF the TTL signal to stop writing to PLX-DAQ
    % WaitSecs(0.01);
    % outputSingleScan(s,0);
    % %***************************************************
    % 
    % Restore normal priority scheduling in case something else was set
    % before:
    Priority(0);
	
	%The same commands wich close onscreen and offscreen windows also close
	%textures.
	Screen('CloseAll');

catch
    %this "catch" section executes in case of an error in the "try" section
    %above.  Importantly, it closes the onscreen window if its open.
    Screen('CloseAll');
    Priority(0);
    psychrethrow(psychlasterror);
end %try..catch..

angle_log
vbl

% We're done!
return;
