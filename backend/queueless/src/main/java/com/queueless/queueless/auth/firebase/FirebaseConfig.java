package com.queueless.queueless.auth.firebase;

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
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
public class FirebaseConfig {

    @Value("${firebase.project.id:queueless-2cbfd}")
    private String firebaseProjectId;

    @Bean
    public JwtDecoder firebaseJwtDecoder() {
        String firebaseIssuer = "https://securetoken.google.com/" + firebaseProjectId;
        String firebaseJwkSetUri = "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";
        String googleOAuthJwkSetUri = "https://www.googleapis.com/oauth2/v3/certs";

        // 1. Decoder for Firebase Auth ID Tokens
        NimbusJwtDecoder firebaseDecoder = NimbusJwtDecoder.withJwkSetUri(firebaseJwkSetUri).build();
        OAuth2TokenValidator<Jwt> withFirebaseIssuer = JwtValidators.createDefaultWithIssuer(firebaseIssuer);
        OAuth2TokenValidator<Jwt> withAudience = new OAuth2TokenValidator<Jwt>() {
            @Override
            public OAuth2TokenValidatorResult validate(Jwt jwt) {
                List<String> audience = jwt.getAudience();
                if (audience != null && audience.contains(firebaseProjectId)) {
                    return OAuth2TokenValidatorResult.success();
                }
                return OAuth2TokenValidatorResult.failure(
                        new OAuth2Error("invalid_token", "The aud claim does not match Firebase Project ID", null)
                );
            }
        };
        firebaseDecoder.setJwtValidator(new DelegatingOAuth2TokenValidator<>(withFirebaseIssuer, withAudience));

        // 2. Decoder for Direct Google Sign-In OAuth ID Tokens
        NimbusJwtDecoder googleOAuthDecoder = NimbusJwtDecoder.withJwkSetUri(googleOAuthJwkSetUri).build();

        return new JwtDecoder() {
            @Override
            public Jwt decode(String token) throws JwtException {
                try {
                    // Try verifying as Firebase ID Token first
                    return firebaseDecoder.decode(token);
                } catch (Exception e1) {
                    try {
                        // Fallback: Try verifying as Direct Google Sign-In ID Token
                        return googleOAuthDecoder.decode(token);
                    } catch (Exception e2) {
                        throw new BadJwtException(
                                "Invalid token signature: The token signature could not be verified with Google's public keys. " +
                                "Ensure you are passing a valid Firebase ID Token or Google Sign-In ID Token.", e1);
                    }
                }
            }
        };
    }
}