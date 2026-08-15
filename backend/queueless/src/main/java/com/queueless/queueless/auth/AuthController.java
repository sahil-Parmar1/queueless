package com.queueless.queueless.auth;


import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.queueless.auth.dto.CustomerGoogleLoginRequest;
import com.queueless.queueless.auth.dto.LoginRequest;
import com.queueless.queueless.auth.dto.OfficeRegisterRequest;
import com.queueless.queueless.user.User;

@RestController
@RequestMapping("/api/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/customer/google")
    public ResponseEntity<?> customerGoogleLogin(
            @RequestBody CustomerGoogleLoginRequest request) {

        String token = authService.loginCustomerWithGoogle(request);

        return ResponseEntity.ok(
                java.util.Map.of("token", token)
        );
    }

    @PostMapping("/office/register")
    public ResponseEntity<?> registerOffice(
            @RequestBody OfficeRegisterRequest request) {

        java.util.Map<String, Object> response = authService.registerOffice(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/office/login")
    public ResponseEntity<?> loginOffice(
            @RequestBody LoginRequest request) {

        String token = authService.loginOffice(request);

        return ResponseEntity.ok(
                java.util.Map.of("token", token)
        );
    }
}