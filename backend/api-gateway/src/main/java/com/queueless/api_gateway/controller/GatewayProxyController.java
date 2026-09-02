package com.queueless.api_gateway.controller;

import java.io.InputStream;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;
import java.util.Enumeration;
import java.util.List;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.servlet.http.HttpServletRequest;

@RestController
public class GatewayProxyController {

    private final HttpClient httpClient;

    @Value("${services.auth.url:http://localhost:8081}")
    private String authServiceUrl;

    @Value("${services.office.url:http://localhost:8082}")
    private String officeServiceUrl;

    private static final Set<String> DISALLOWED_HEADERS = Set.of(
            "connection", "keep-alive", "proxy-authenticate", "proxy-authorization",
            "te", "trailer", "transfer-encoding", "upgrade", "host", "content-length",
            "expect", "date", "sec-fetch-mode", "sec-fetch-site", "sec-fetch-dest"
    );

    public GatewayProxyController() {
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(15))
                .followRedirects(HttpClient.Redirect.NORMAL)
                .build();
    }

    @RequestMapping(value = {"/api/auth/**", "/api/test/**", "/api/office/**", "/api/**"})
    public ResponseEntity<byte[]> proxyRequest(HttpServletRequest request) {
        try {
            String targetBaseUrl = resolveTargetServiceUrl(request.getRequestURI());
            if (targetBaseUrl == null) {
                return ResponseEntity.status(HttpStatus.NOT_FOUND)
                        .body("No microservice registered for path".getBytes());
            }

            String targetUriStr = targetBaseUrl + request.getRequestURI();
            if (request.getQueryString() != null) {
                targetUriStr += "?" + request.getQueryString();
            }

            URI targetUri = URI.create(targetUriStr);

            HttpRequest.Builder requestBuilder = HttpRequest.newBuilder()
                    .uri(targetUri)
                    .timeout(Duration.ofSeconds(60));

            // Copy request headers
            Enumeration<String> headerNames = request.getHeaderNames();
            if (headerNames != null) {
                while (headerNames.hasMoreElements()) {
                    String headerName = headerNames.nextElement();
                    if (!DISALLOWED_HEADERS.contains(headerName.toLowerCase())) {
                        Enumeration<String> values = request.getHeaders(headerName);
                        while (values.hasMoreElements()) {
                            String value = values.nextElement();
                            requestBuilder.header(headerName, value);
                        }
                    }
                }
            }

            // Copy body
            String method = request.getMethod().toUpperCase();
            HttpRequest.BodyPublisher bodyPublisher;

            if ("GET".equals(method) || "HEAD".equals(method) || "DELETE".equals(method)) {
                bodyPublisher = HttpRequest.BodyPublishers.noBody();
            } else {
                byte[] bodyBytes = request.getInputStream().readAllBytes();
                bodyPublisher = HttpRequest.BodyPublishers.ofByteArray(bodyBytes);
            }

            requestBuilder.method(method, bodyPublisher);

            // Execute downstream request
            HttpResponse<byte[]> downstreamResponse = httpClient.send(
                    requestBuilder.build(),
                    HttpResponse.BodyHandlers.ofByteArray()
            );

            // Build Spring ResponseEntity
            HttpHeaders responseHeaders = new HttpHeaders();
            downstreamResponse.headers().map().forEach((key, values) -> {
                if (!DISALLOWED_HEADERS.contains(key.toLowerCase()) && !"content-length".equalsIgnoreCase(key)) {
                    responseHeaders.put(key, values);
                }
            });

            return new ResponseEntity<>(
                    downstreamResponse.body(),
                    responseHeaders,
                    HttpStatus.valueOf(downstreamResponse.statusCode())
            );

        } catch (Exception e) {
            e.printStackTrace();
            return ResponseEntity.status(HttpStatus.BAD_GATEWAY)
                    .body(("Gateway Error forwarding request: " + e.getMessage()).getBytes());
        }
    }

    private String resolveTargetServiceUrl(String uri) {
        if (uri.startsWith("/api/auth/") || uri.startsWith("/api/test/")) {
            return authServiceUrl;
        } else if (uri.startsWith("/api/office/") || uri.startsWith("/api/offices/") || uri.startsWith("/api/queue/")) {
            return officeServiceUrl;
        }
        return null;
    }
}
