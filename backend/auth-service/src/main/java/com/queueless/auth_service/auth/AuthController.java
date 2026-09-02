package com.queueless.auth_service.auth;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.queueless.auth_service.auth.dto.CustomerGoogleLoginRequest;
import com.queueless.auth_service.auth.dto.CustomerRegisterRequest;
import com.queueless.auth_service.auth.dto.LoginRequest;
import com.queueless.auth_service.auth.dto.OfficeRegisterRequest;

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

        java.util.Map<String, Object> response = authService.loginCustomerWithGoogleDetailed(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/customer/register")
    public ResponseEntity<?> customerRegister(
            @RequestBody CustomerRegisterRequest request) {

        java.util.Map<String, Object> response = authService.registerCustomer(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/customer/login")
    public ResponseEntity<?> customerLogin(
            @RequestBody LoginRequest request) {

        java.util.Map<String, Object> response = authService.loginCustomer(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/customer/auth-or-register")
    public ResponseEntity<?> customerAuthOrRegister(
            @RequestBody CustomerRegisterRequest request) {

        java.util.Map<String, Object> response = authService.authOrRegisterCustomer(request);

        return ResponseEntity.ok(response);
    }

    @PostMapping("/office/google")
    public ResponseEntity<?> officeGoogleLogin(
            @RequestBody CustomerGoogleLoginRequest request) {

        java.util.Map<String, Object> response = authService.loginOfficeWithGoogle(request);

        return ResponseEntity.ok(response);
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
