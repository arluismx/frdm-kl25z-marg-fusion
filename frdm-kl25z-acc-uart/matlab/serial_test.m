function serial_test
    close all; clear all;

    % We turn it back on in the end
    cleanupHandler = onCleanup(@cleanUp);

    % Cleanup
    connectedPorts = instrfind();
    if ~isempty(connectedPorts)
        disp('Freeing connected ports.');
        for port=connectedPorts
            fclose(connectedPorts);
            delete(connectedPorts);
        end
    end
    
    % Configuring port object
    global s;
    s = serial('COM4', ...
        'FlowControl', 'none', ...
        'BaudRate', 230400, ...
        'DataBits', 8, ...
        'Parity', 'none', ...
        'StopBits', 1, ...
        'TimeOut', 1, ...
        'InputBufferSize', 1024, ...
        'ReadAsyncMode', 'continuous', ...
        'Terminator', 0, ...
        'BytesAvailableFcnCount', 12, ...
        'BytesAvailableFcnMode', 'byte' ...
        );
    
    % Connecting to the port
    fopen(s);

    % Prepare plot
    figureHandle = figure('NumberTitle', 'off', ...
        'Name', 'MMA8451Q Output', ...
        'Color', [0.027 0.211 0.259], ...
        'Visible', 'off' ...
        );
    
    % Prepare axes
    axesHandle = subplot(1,2,1, ... 
        'Parent', figureHandle, ...
        'XGrid', 'on', ...
        'XColor', [0.973 0.973 0.973], ...
        'YGrid', 'on', ...
        'YColor', [0.973 0.973 0.973], ...
        'ZGrid', 'on', ...
        'ZColor', [0.973 0.973 0.973], ...
        'Color', [0.1 0.1 0.1] ...
        );
    axis square;
    
    % Prepare virtual horizon
    horizonHandle = subplot(1,2,2, ... 
        'Parent', figureHandle, ...
        'XGrid', 'on', ...
        'XColor', [0.973 0.973 0.973], ...
        'YGrid', 'on', ...
        'YColor', [0.973 0.973 0.973], ...
        'ZGrid', 'on', ...
        'ZColor', [0.973 0.973 0.973], ...
        'Color', [0.1 0.1 0.1] ...
        );
    
    % Prepare title
    titleHandle = title(axesHandle, '', ...
        'Color', [1 1 1], ...
        'Interpreter', 'none' ...
        );

    % Prepare the data array
    xtrack = NaN(1, 10);
    ytrack = NaN(1, 10);
    ztrack = NaN(1, 10);
    
    % Prepare the plot
    hold on;
    plotHandle = line(NaN, NaN, NaN, ...
        'Parent', axesHandle, ...
        'Marker', 'v', ...
        'LineWidth', 2, ...
        'MarkerSize', 20, ...
        'Color', [0.972 0.149 0.427] ...
        );
    trackHandle = line(xtrack, ytrack, ztrack, ...
        'Parent', axesHandle, ...
        'LineStyle', ':', ...
        'Marker', '.', ...
        'LineWidth', 1, ...
        'MarkerSize', 1, ...
        'Color', [0.872 0.049 0.327] ...
        );
    
    %set(plotHandle(1), 'MarkerSize', 20);
    
    xlim(axesHandle, [-1 1]);
    ylim(axesHandle, [-1 1]);
    zlim(axesHandle, [-1 1]);
    
    view(axesHandle, -37.5, 30);
    axis square;
    set(figureHandle, 'Visible', 'on');
    
    % Grab jobject for fread
    sjobject = igetfield(s, 'jobject');
        
    % Definitions
    SOH     = uint8(1);
    EOT     = uint8(4);
    ESC     = uint8(27);
    ESC_XOR = uint8(66);
    DA      = uint8(218);
    TA      = uint8(122);

    % Detection state machine
    % 0 = searching for preamble --> 0
    % 1 = preamble found, expecting SOH --> 1
    % 2 = SOH found, expecting length --> 2
    % 3 = length found, expecting data --> 4
    % 4 = reading bytes --> 5
    % 5 = expecting EOT --> 0
    state = 0;
    
    % Decoding variables
    dataLength = 0;
    data = [];
    dataBytesRead = 0;
    escapeDetected = false;
    dataReady = false;
    
    % Data counters
    global sensorDataCount;
    ACCELEROMETER = 1;
    GYROSCOPE     = 2;
    COMPASS       = 3;
    TEMPERATURE   = 4;
    sensorDataCount = zeros(4,1);
    totalDataCount = 0;
    
    % data buffers
    BUFFER_STEP_SIZE = 1000;
    global accelBuffer gyroBuffer compassBuffer temperatureBuffer
    accelBuffer         = zeros(BUFFER_STEP_SIZE, 4); % time + xyz
    gyroBuffer          = zeros(BUFFER_STEP_SIZE, 4); % time + xyz
    compassBuffer       = zeros(BUFFER_STEP_SIZE, 4); % time + xyz
    temperatureBuffer   = zeros(BUFFER_STEP_SIZE, 2); % time + t
    
    % Debugging
    byteCircBuf = NaN(1, 64);
    
    % Start timing for the graphics and data loop
    graphicsTimer = tic;
    dataTimer = tic;
    
    % Reading the data
    bulkSize = 80;
    lastByte = 0;
    while true
        % Read bytes; A profiler run showed that fread(s, count) is
        % horribly slow mainly due to error string formattings even
        % if they are not required. Because of this, a more low-level
        % variant of the function is called.
        out = fread(sjobject, bulkSize, 0, 0); % 0, 0 meaning unsigned int 8
        bytes = typecast(out(1), 'uint8');     % unfortunately it is not unsigned
        
        byteIndices = 1:numel(bytes);
        for b=byteIndices
            byte = bytes(b);
            
            % Attach byte to circular buffer
            %byteCircBuf = [byteCircBuf(2:end), double(byte)];

            % Decode the protocol
            protocolDecode(byte);

            % Decode data buffer
            if dataReady
                % Thanks, got it.
                dataReady = false;
                totalDataCount = totalDataCount + 1;
                timestamp = toc(dataTimer);
                
                % Attach NaN byte to circular buffer to aid debugging
                %byteCircBuf = [byteCircBuf(2:end), NaN];
                
                % Skip everything that is not from the MMA8451Q
                type = data(1);
                if type == 1
                    disp('MMA8451Q sensing disabled');
                    continue;
                    
                    % Decode MMA8451Q data
                    sensorDataCount(ACCELEROMETER) = sensorDataCount(ACCELEROMETER) + 1;
                    scaling = 4096;
                    
                    accXYZ = [
                        double(typecast(data(2:3), 'int16'));
                        double(typecast(data(4:5), 'int16'));
                        double(typecast(data(6:7), 'int16'));
                        ] / scaling;
                    continue;
                elseif type == 2
                    % Decode MPU6050 data
                    sensorDataCount(ACCELEROMETER) = sensorDataCount(ACCELEROMETER) + 1;
                    sensorDataCount(GYROSCOPE)     = sensorDataCount(GYROSCOPE) + 1;
                    sensorDataCount(TEMPERATURE)   = sensorDataCount(TEMPERATURE) + 1;
                    scaling = 8192; %16384 for 2g mode
                    
                    % Swapping components due to orientation on my board
                    accXYZ = [
                        -double(typecast(data(4:5), 'int16'));
                         double(typecast(data(2:3), 'int16'));
                         double(typecast(data(6:7), 'int16'));
                        ] / scaling;
                    gyroXYZ = [
                        -double(typecast(data(10:11), 'int16'));
                         double(typecast(data(8:9), 'int16'));
                         double(typecast(data(12:13), 'int16'));
                        ] / scaling;
                    temperature = [
                        double(typecast(data(14:15), 'int16'));
                        ];
                    
                    % attach data to buffer
                    if mod(sensorDataCount(ACCELEROMETER), BUFFER_STEP_SIZE) == 0
                        accelBuffer = [accelBuffer; zeros(BUFFER_STEP_SIZE, 4)];
                    end
                    accelBuffer(sensorDataCount(ACCELEROMETER), 1:4) = [timestamp; accXYZ];
                    
                    % attach data to buffer
                    if mod(sensorDataCount(GYROSCOPE), BUFFER_STEP_SIZE) == 0
                        gyroBuffer = [gyroBuffer; zeros(BUFFER_STEP_SIZE, 4)];
                    end
                    gyroBuffer(sensorDataCount(GYROSCOPE), 1:4) = [timestamp; gyroXYZ];
                    
                    % attach data to buffer
                    if mod(sensorDataCount(TEMPERATURE), BUFFER_STEP_SIZE) == 0
                        temperatureBuffer = [temperatureBuffer; zeros(BUFFER_STEP_SIZE, 2)];
                    end
                    temperatureBuffer(sensorDataCount(TEMPERATURE), 1:2) = [timestamp; temperature];
                    
                elseif type == 3
                    % Decode HMC5883L data
                    sensorDataCount(COMPASS)        = sensorDataCount(COMPASS) + 1;
                    scaling = 1090;
                    
                    compassXYZ = [
                         double(typecast(data(2:3), 'int16'));
                         double(typecast(data(4:5), 'int16'));
                         double(typecast(data(6:7), 'int16'));
                        ] / scaling;
                    
                    % attach data to buffer
                    if mod(sensorDataCount(COMPASS), BUFFER_STEP_SIZE) == 0
                        compassBuffer = [compassBuffer; zeros(BUFFER_STEP_SIZE, 4)];
                    end
                    compassBuffer(sensorDataCount(COMPASS), 1:4) = [timestamp; compassXYZ];
                else
                    disp('unknown sensor type');
                    continue;
                end
                
                % Count the received data
                totalDataCount = totalDataCount + 1;
                if mod(totalDataCount, 1000) == 0
                    msg = sprintf('Data count: @t=%f: acc %5d, gyro %5d, compass %5d, temp %d', ...
                        toc(dataTimer), ...
                        sensorDataCount(ACCELEROMETER), ...
                        sensorDataCount(GYROSCOPE), ...
                        sensorDataCount(COMPASS), ...
                        sensorDataCount(TEMPERATURE) ...
                    );
                    disp(msg);    
                end
                                                
                %msg = sprintf('x: %+1.5f  y: %+1.5f  z: %+1.5f', accXYZ(1), accXYZ(2), accXYZ(3));
                %msg = sprintf('x: %+1.5f  y: %+1.5f  z: %+1.5f', accXYZ(1)*scaling, accXYZ(2)*scaling, accXYZ(3)*scaling);
                %disp(msg);
                    
                % Render with 30 Hz
                duration = toc(graphicsTimer);
                if duration > 1/30
                    % Prepare the track
                    xtrack = [xtrack(2:end) accXYZ(1)];
                    ytrack = [ytrack(2:end) accXYZ(2)];
                    ztrack = [ztrack(2:end) accXYZ(3)];
                    
                    % Set the plot data
                    set(plotHandle, 'XData', accXYZ(1), 'YData', accXYZ(2), 'ZData', accXYZ(3));
                    set(trackHandle, 'XData', xtrack, 'YData', ytrack, 'ZData', ztrack);

                    % Set the title
                    rp = rollpitch(accXYZ);
                    rpdegree = rp * 180/pi;
                    msg = sprintf('roll %+1.4f, yaw %+1.4f', rpdegree(1), rpdegree(2));
                    set(titleHandle, 'String', msg);
                    
                    % Set the axis labels
                    subplot(axesHandle);
                    xlabel(['x: ' num2str(accXYZ(1))]);
                    ylabel(['y: ' num2str(accXYZ(2))]);
                    zlabel(['z: ' num2str(accXYZ(3))]);
                    
                    % Update the virtual horizon
                    subplot(horizonHandle);
                    virtualHorizonPlot(rp);
                    
                    drawnow;
                    graphicsTimer = tic;
                end;
            end
            
        end
    end
    
    function protocolDecode(byte)       
        % Switch states
        switch state
            % Await preamble
            case 0
                if byte == DA
                    %state = 0;
                elseif (byte == TA) && (lastByte == DA)
                    % preamble detected
                    state = 1;
                else
                    %state = 0;
                    
                    %disp('protocol error in state 0');
                    %disp(s.BytesAvailable);
                end
                
                % Remember byte for protocol decoding
                lastByte = byte;
            
            % Await SOH
            case 1
                if byte == SOH
                    state = 2;
                else
                    state = 0;
                    disp('protocol error in state 1');
                end
                
            % Read length
            case 2
                oldDataLength = dataLength;
                dataLength = byte;
                dataBytesRead = 0;
                %if oldDataLength ~= dataLength
                    data = zeros(dataLength, 1, 'uint8');
                %end
                state = 3;
                                
            % Read data bytes
            case 3
                if byte == ESC
                    escapeDetected = true;
                    %state = 3;
                else
                    if escapeDetected
                        byte = bitxor(byte, ESC_XOR);
                        escapeDetected = false;
                    end

                    dataBytesRead = dataBytesRead + 1;
                    data(dataBytesRead) = byte;
                    
                    if dataBytesRead == dataLength
                        state = 4;
                    else
                        %state = 3;
                    end
                end
                                
            % Await EOT
            case 4
                if byte == EOT
                    state = 0;
                    dataReady = true;
                else
                    state = 0;
                    disp('protocol error in state 6');
                end
        end
    end
    
    function cleanUp()
        disp('Cleaning up ...');
        
        % Closing the port
        fclose(s);
        delete(s);
        clear s;
    end
    
end