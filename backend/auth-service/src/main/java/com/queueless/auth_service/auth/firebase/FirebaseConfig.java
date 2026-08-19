package com.queueless.auth_service.auth.firebase;

import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.DelegatingOAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.BadJwtException;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
public class FirebaseConfig {

    // Reads both project IDs: "queueless-2cbfd,queueless-office"
    @Value("${firebase.project.ids:queueless-2cbfd,queueless-office}")
    private String allowedProjectIds;

    @Bean
    public JwtDecoder firebaseJwtDecoder() {
        List<String> projectList = Arrays.stream(allowedProjectIds.split(","))
                .map(String::trim)
                .toList();

        String firebaseJwkSetUri = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
        String googleOAuthJwkSetUri = "https://www.googleapis.com/oauth2/v3/certs";

        // 1. Decoder for Firebase Auth ID Tokens
        NimbusJwtDecoder firebaseDecoder = NimbusJwtDecoder.withJwkSetUri(firebaseJwkSetUri).build();

        // Custom Multi-Project Validator (checks if issuer & audience match ANY allowed project)
        OAuth2TokenValidator<Jwt> multiProjectValidator = new OAuth2TokenValidator<Jwt>() {
            @Override
            public OAuth2TokenValidatorResult validate(Jwt jwt) {
                String issuer = jwt.getIssuer() != null ? jwt.getIssuer().toString() : "";
                List<String> audience = jwt.getAudience();

                boolean validProject = projectList.stream().anyMatch(projectId -> {
                    String expectedIssuer = "https://securetoken.google.com/" + projectId;
                    boolean matchesIssuer = issuer.equals(expectedIssuer);
                    boolean matchesAudience = audience != null && audience.contains(projectId);
                    return matchesIssuer && matchesAudience;
                });

                if (validProject) {
                    return OAuth2TokenValidatorResult.success();
                }

                return OAuth2TokenValidatorResult.failure(
                        new OAuth2Error("invalid_token", "Token audience/issuer does not match any allowed Firebase Project ID", null)
                );
            }
        };

        firebaseDecoder.setJwtValidator(multiProjectValidator);

        // 2. Decoder for Direct Google Sign-In OAuth ID Tokens (fallback)
        NimbusJwtDecoder googleOAuthDecoder = NimbusJwtDecoder.withJwkSetUri(googleOAuthJwkSetUri).build();

        return new JwtDecoder() {
            @Override
            public Jwt decode(String token) throws JwtException {
                try {
                    return firebaseDecoder.decode(token);
                } catch (Exception e1) {
                    try {
                        return googleOAuthDecoder.decode(token);
                    } catch (Exception e2) {
                        throw new BadJwtException(
                                "Invalid token signature: The token could not be verified with Google/Firebase keys.", e1);
                    }
                }
            }
        };
    }
}