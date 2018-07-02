% Get the image.
P = phantom(200);

% Reduce the size of the image for speed.
P = imresize(P, 0.5);

% Pad the image with a fixed boundary of 3 pixels.
P = padarray(P, [3, 3], 0.0);

% Constants.
sigmaNoiseFraction = 0.05;
max_shift_amplitude = 0;
filename = ...
    '../results/bayesian_estimation/error_angles_and_shifts/5_percent_noise/';
num_theta = 90;
max_angle_err = 5;
max_shift_err = 0;
resolution_angle = 1;
resolution_space = 1;
no_of_iterations = 1;
mask=ones(size(P));
n = size(P, 1);
L_pad = 260; 

% Things to write in the observation file.
theta_to_write = zeros(10, num_theta);

% Define ground truth angles and take the tomographic projection.
% theta = datasample(0:0.5:359.5, num_theta);  
theta = 0:2:178;
[projections, svector] = radon(P, theta);
original_projections = projections;
original_shifts = zeros(size(theta));

% Shift each projection by an unknown amount.
for i=1:size(projections, 2)
    original_shifts(i) = ...
        randi([-max_shift_amplitude, max_shift_amplitude]);
    projections(:, i) = circshift(projections(:, i), original_shifts(i)); 
end
theta_to_write(1, :) = theta;
theta_to_write(6, :) = original_shifts;

% Initialize parameters needed for searching in the space.
prior_parameters = PriorParameters(max_angle_err, max_shift_err,...
    resolution_angle, resolution_space);

% Add noise to projections.
[projections, sigmaNoise] = add_noise(projections, sigmaNoiseFraction);

% Transform all entities to the frequency space.
f_p = ifftshift(projections,1);
f_projections = fft(f_p,[ ],1);
f_projections = fftshift(f_projections,1); % put DC central after filtering 

% In the first case the angles and shifts will be unknown upto a 
% certain limit.
first_estimate_theta = mod(theta +...
    randi([-max_angle_err + 4, max_angle_err - 4], 1, num_theta), 180);
first_estimate_shifts = original_shifts +...
    randi([-max_shift_err, max_shift_err], 1, num_theta);

% Begin estimation of the first model.
prob_matrix_height = (2*max_angle_err)/resolution_angle + 1;
prob_matrix_width = 2*max_shift_err/resolution_space + 1;
prob_matrix = ...
    zeros(prob_matrix_height, prob_matrix_width,...
        size(f_projections, 2)) + 1/(prob_matrix_height*prob_matrix_width);

% Start estimating the image.
fourier_radial = zeros(1873, 1873);
for i=1:size(prob_matrix, 1)
    for j=1:size(prob_matrix, 2)
        probabilities = squeeze(prob_matrix(i, j, :))';
        prob_f_proj = bsxfun(@mtimes, f_projections, probabilities);

        current_theta = mod(first_estimate_theta  + i*resolution_angle...
            - resolution_angle - max_angle_err, 180);
        current_shift = first_estimate_shifts  + j*resolution_space...
            - resolution_space - max_shift_err;

        fourier_radial = fourier_radial +...
            backproject_fourier_alternate(prob_f_proj, current_theta,...
                current_shift);
    end
end

f_image_estimate = fourier_radial(:);
first_estimate_model = Ifft2_2_Img(fourier_radial, L_pad);
% figure; imshow(first_estimate_model_alternate);

modified_f_projections = zeros(size(f_projections));

error = 0;
for i=50:50
%     c_proj = project_fourier_alternate(fourier_radial,...
%         theta(i), 287);
    c_proj_1 = project_fourier_alternate(fourier_radial,...
        first_estimate_theta(i), first_estimate_shifts(i), 153);
    c_proj_2 = project_fourier_alternate(fourier_radial,...
        first_estimate_theta(i) + 1, first_estimate_shifts(i), 153);
    c_proj_3 = project_fourier_alternate(fourier_radial,...
        first_estimate_theta(i) - 1, first_estimate_shifts(i), 153);
%     disp(size(c_proj, 1));
%     c_proj(isnan(c_proj)) = complex(0, 0);
%     disp(c_proj(ceil(size(c_proj, 1)/2) + 1));
    f_proj = f_projections(:, i);
%     disp(norm(c_proj - f_proj));
    disp(norm(c_proj_3 - f_proj));
    disp(norm(c_proj_1 - f_proj));
    disp(norm(c_proj_2 - f_proj));
    % error = error + norm(c_proj_1 - f_proj);
    % modified_f_projections(:, i) = c_proj_1;
end

% fourier_radial_modified = ...
%     backproject_fourier_alternate(modified_f_projections, first_estimate_theta);
% first_estimate_model = Ifft2_2_Img(fourier_radial_modified, L_pad);
% figure; imshow(first_estimate_model);

% error/num_theta

