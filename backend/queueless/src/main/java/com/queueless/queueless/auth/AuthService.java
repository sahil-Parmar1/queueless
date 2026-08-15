package com.queueless.queueless.auth;

import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.stereotype.Service;

import com.queueless.queueless.auth.dto.CustomerGoogleLoginRequest;
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
    private final JwtDecoder firebaseJwtDecoder;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            JwtDecoder firebaseJwtDecoder) {

        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.firebaseJwtDecoder = firebaseJwtDecoder;
    }

    // =========================
    // OFFICE REGISTRATION
    // =========================

    public java.util.Map<String, Object> registerOffice(OfficeRegisterRequest request) {

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

        User saved = userRepository.save(user);
        String token = jwtService.generateToken(saved);

        return java.util.Map.of(
                "token", token,
                "user", saved
        );
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

    // =========================
    // CUSTOMER GOOGLE LOGIN
    // =========================

    public String loginCustomerWithGoogle(
            CustomerGoogleLoginRequest request) {

        try {

            // Verify Firebase ID token without firebase-admin
            Jwt decodedToken = firebaseJwtDecoder.decode(request.getIdToken());

            String uid = decodedToken.getSubject();
            String email = decodedToken.getClaimAsString("email");
            String nameClaim = decodedToken.getClaimAsString("name");
            String name = (nameClaim != null && !nameClaim.isBlank()) ? nameClaim : email;

            if (email == null || email.isBlank()) {
                throw new RuntimeException("Firebase token does not contain a valid email address");
            }

            // Find customer
            User user = userRepository.findByEmail(email)
                    .orElseGet(() -> {

                        User newUser = new User();

                        newUser.setName(name);
                        newUser.setEmail(email);

                        // Customer uses Google/Firebase,
                        // so no normal password is required.
                        newUser.setPassword(null);
                        newUser.setGoogleId(uid);

                        newUser.setRole(Role.CUSTOMER);
                        newUser.setEnabled(true);

                        return userRepository.save(newUser);
                    });

            if (user.getGoogleId() == null) {
                user.setGoogleId(uid);
                userRepository.save(user);
            }

            // Make sure this is a customer
            if (user.getRole() != Role.CUSTOMER) {
                throw new RuntimeException(
                        "This email is not registered as a customer"
                );
            }

            if (!user.getEnabled()) {
                throw new RuntimeException(
                        "Customer account is disabled"
                );
            }

            // Generate your Queueless JWT
            return jwtService.generateToken(user);

        } catch (Exception e) {

            e.printStackTrace();

            throw new RuntimeException(
                    "Invalid Google authentication: " + e.getMessage(),
                    e
            );
        }
    }
}