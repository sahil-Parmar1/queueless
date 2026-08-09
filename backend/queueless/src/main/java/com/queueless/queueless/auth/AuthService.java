package com.queueless.queueless.auth;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.queueless.queueless.auth.dto.LoginRequest;
import com.queueless.queueless.auth.dto.OfficeRegisterRequest;
import com.queueless.queueless.user.Role;
import com.queueless.queueless.user.User;
import com.queueless.queueless.user.UserRepository;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService) {

        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
    }

    // =========================
    // OFFICE REGISTRATION
    // =========================

    public User registerOffice(OfficeRegisterRequest request) {

        if (userRepository.existsByEmail(request.getEmail())) {
            throw new RuntimeException("Email already registered");
        }

        User user = new User();

        user.setName(request.getName());
        user.setEmail(request.getEmail());

        // Never save the plain password
        user.setPassword(
                passwordEncoder.encode(request.getPassword())
        );

        user.setRole(Role.OFFICE);
        user.setEnabled(true);

        return userRepository.save(user);
    }


    // =========================
    // OFFICE LOGIN
    // =========================

    public String loginOffice(LoginRequest request) {

        User user = userRepository.findByEmail(request.getEmail())
                .orElseThrow(() ->
                        new RuntimeException("Invalid email or password"));

        // Make sure this is an OFFICE account
        if (user.getRole() != Role.OFFICE) {
            throw new RuntimeException("Not an office account");
        }

        // Check whether account is enabled
        if (!user.getEnabled()) {
            throw new RuntimeException("Account is disabled");
        }

        // Check password
        if (!passwordEncoder.matches(
                request.getPassword(),
                user.getPassword())) {

            throw new RuntimeException("Invalid email or password");
        }

        // Generate JWT
        return jwtService.generateToken(user);
    }
}