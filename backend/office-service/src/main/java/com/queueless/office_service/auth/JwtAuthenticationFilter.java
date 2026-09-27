package com.queueless.office_service.auth;

import java.io.IOException;
import java.util.List;

import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import com.queueless.office_service.provider.Provider;
import com.queueless.office_service.provider.ProviderRepository;
import com.queueless.office_service.user.User;
import com.queueless.office_service.user.UserRepository;

import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

@Component
public class JwtAuthenticationFilter extends OncePerRequestFilter {

    private final JwtService jwtService;
    private final UserRepository userRepository;
    private final ProviderRepository providerRepository;

    public JwtAuthenticationFilter(
            JwtService jwtService,
            UserRepository userRepository,
            ProviderRepository providerRepository) {
        this.jwtService = jwtService;
        this.userRepository = userRepository;
        this.providerRepository = providerRepository;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        return path.equals("/") || path.equals("/error");
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain)
            throws ServletException, IOException {

        String authHeader = request.getHeader("Authorization");

        if (authHeader == null || !authHeader.startsWith("Bearer ")) {
            filterChain.doFilter(request, response);
            return;
        }

        String token = authHeader.substring(7);

        try {
            if (jwtService.isTokenValid(token)) {
                Claims claims = jwtService.extractAllClaims(token);
                String roleStr = claims.get("role", String.class);

                if ("PROVIDER".equalsIgnoreCase(roleStr)) {
                    Object pIdObj = claims.get("providerId");
                    Long providerId = null;
                    if (pIdObj instanceof Number num) {
                        providerId = num.longValue();
                    } else if (pIdObj instanceof String str) {
                        providerId = Long.parseLong(str);
                    }

                    if (providerId != null) {
                        Provider provider = providerRepository.findById(providerId).orElse(null);
                        if (provider != null && Boolean.TRUE.equals(provider.getActive())) {
                            SimpleGrantedAuthority authority =
                                    new SimpleGrantedAuthority("ROLE_PROVIDER");

                            UsernamePasswordAuthenticationToken authentication =
                                    new UsernamePasswordAuthenticationToken(
                                            provider,
                                            null,
                                            List.of(authority)
                                    );

                            SecurityContextHolder.getContext().setAuthentication(authentication);
                        }
                    }
                } else {
                    String email = jwtService.extractEmail(token);
                    User user = userRepository.findByEmail(email).orElse(null);

                    if (user != null && user.getEnabled()) {
                        SimpleGrantedAuthority authority =
                                new SimpleGrantedAuthority("ROLE_" + user.getRole().name());

                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        user,
                                        null,
                                        List.of(authority)
                                );

                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    } else if (email != null && roleStr != null) {
                        // Fallback using JWT claims directly
                        SimpleGrantedAuthority authority =
                                new SimpleGrantedAuthority("ROLE_" + roleStr);

                        UsernamePasswordAuthenticationToken authentication =
                                new UsernamePasswordAuthenticationToken(
                                        email,
                                        null,
                                        List.of(authority)
                                );

                        SecurityContextHolder.getContext().setAuthentication(authentication);
                    }
                }
            }
        } catch (Exception e) {
            // Invalid token - request remains unauthenticated
        }

        filterChain.doFilter(request, response);
    }
}
