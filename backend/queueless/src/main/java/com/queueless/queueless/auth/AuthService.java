package com.queueless.queueless.auth;


import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;

import com.queueless.queueless.auth.dto.OfficeRegisterRequest;
import com.queueless.queueless.user.Role;
import com.queueless.queueless.user.User;
import com.queueless.queueless.user.UserRepository;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder) {

        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

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
}